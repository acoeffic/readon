import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

// Récompense un parrainage : accorde 14 jours de premium au parrain ET au
// filleul via un *promotional entitlement* RevenueCat, puis marque le
// parrainage comme récompensé.
//
// Appelée par le trigger SQL `trg_referral_reward_on_session` (service_role
// en Bearer) quand le filleul termine sa première session de lecture.
// Idempotente : on grant par `end_time_ms` (expiration absolue), donc une
// ré-exécution ne fait que réappliquer la même date d'expiration.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const RC_SECRET = Deno.env.get("REVENUECAT_SECRET_API_KEY");
// Identifiant de ton entitlement RevenueCat (celui qui débloque le premium).
const RC_ENTITLEMENT = Deno.env.get("REVENUECAT_ENTITLEMENT_ID") ?? "premium";
const REWARD_DAYS = Number(Deno.env.get("REFERRAL_REWARD_DAYS") ?? "14");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return mismatch === 0;
}

/** Accorde un entitlement promo à `appUserId` jusqu'à `endTimeMs`. */
async function grantPromo(appUserId: string, endTimeMs: number): Promise<boolean> {
  if (!RC_SECRET) {
    console.error("REVENUECAT_SECRET_API_KEY manquante");
    return false;
  }
  const url =
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}` +
    `/entitlements/${encodeURIComponent(RC_ENTITLEMENT)}/promotional`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RC_SECRET}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ end_time_ms: endTimeMs }),
  });
  if (!res.ok) {
    console.error(`RevenueCat grant failed for ${appUserId}: ${res.status} ${await res.text()}`);
    return false;
  }
  return true;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Réservé au trigger interne (service_role en Bearer).
  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token || !timingSafeEqual(token, SUPABASE_SERVICE_ROLE_KEY!)) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const { referred_id } = await req.json();
    if (!referred_id) {
      return jsonResponse({ error: "referred_id requis" }, 400);
    }

    // Parrainage en attente pour ce filleul ?
    const { data: referral } = await supabase
      .from("referrals")
      .select("id, referrer_id, referred_id, status")
      .eq("referred_id", referred_id)
      .eq("status", "pending")
      .maybeSingle();

    if (!referral) {
      return jsonResponse({ skipped: true, reason: "no_pending_referral" });
    }

    const endTimeMs = Date.now() + REWARD_DAYS * 86400000;
    const endIso = new Date(endTimeMs).toISOString();

    // Grant aux deux (idempotent via end_time_ms).
    const okReferrer = await grantPromo(referral.referrer_id, endTimeMs);
    const okReferred = await grantPromo(referral.referred_id, endTimeMs);

    // Miroir immédiat du cache profiles pour que l'app reflète le premium
    // sans attendre la resync RevenueCat. On n'écrase pas un premium plus long.
    for (const [uid, ok] of [
      [referral.referrer_id, okReferrer],
      [referral.referred_id, okReferred],
    ] as [string, boolean][]) {
      if (!ok) continue;
      const { data: p } = await supabase
        .from("profiles")
        .select("premium_until")
        .eq("id", uid)
        .maybeSingle();
      const current = p?.premium_until ? new Date(p.premium_until).getTime() : 0;
      const until = Math.max(current, endTimeMs);
      await supabase
        .from("profiles")
        .update({ is_premium: true, premium_until: new Date(until).toISOString() })
        .eq("id", uid);
    }

    // Marque récompensé (même si un grant a échoué : l'op est idempotente,
    // et on évite de re-spammer RevenueCat à chaque session suivante).
    await supabase
      .from("referrals")
      .update({ status: "rewarded", rewarded_at: new Date().toISOString() })
      .eq("id", referral.id);

    return jsonResponse({
      success: true,
      granted_until: endIso,
      referrer_ok: okReferrer,
      referred_ok: okReferred,
    });
  } catch (error) {
    console.error("grant-referral-reward error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
