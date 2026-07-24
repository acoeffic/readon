import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

// Attribution d'un parrainage. Appelée par l'app juste après l'inscription
// (ou quand l'utilisateur saisit/ouvre un lien de parrainage).
// Le filleul (referred) est dérivé du JWT — jamais du body. Anti-abus :
// seul un compte récent peut être parrainé, et une seule fois.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY",
  );
}

// Fenêtre d'éligibilité : un compte de plus de N jours ne peut plus être
// « parrainé » (évite que des comptes anciens farment du premium).
const MAX_ACCOUNT_AGE_DAYS = 30;

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  const supabaseUser = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabaseUser.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const body = await req.json().catch(() => ({}));
    const rawCode = (body.code ?? "").toString().trim().toUpperCase();
    if (!rawCode) {
      return jsonResponse({ error: "code requis" }, 400);
    }

    // Anti-abus : seul un compte récent est éligible.
    const createdAt = user.created_at ? new Date(user.created_at).getTime() : 0;
    const ageDays = (Date.now() - createdAt) / 86400000;
    if (createdAt && ageDays > MAX_ACCOUNT_AGE_DAYS) {
      return jsonResponse({ error: "not_eligible" }, 403);
    }

    // Retrouver le parrain via son code.
    const { data: referrer } = await supabase
      .from("profiles")
      .select("id")
      .eq("referral_code", rawCode)
      .maybeSingle();

    if (!referrer) {
      return jsonResponse({ error: "invalid_code" }, 400);
    }
    if (referrer.id === user.id) {
      return jsonResponse({ error: "self_referral" }, 400);
    }

    // Créer le parrainage (pending). La contrainte unique(referred_id)
    // garantit qu'un filleul ne peut être parrainé qu'une fois.
    const { error: insertError } = await supabase.from("referrals").insert({
      referrer_id: referrer.id,
      referred_id: user.id,
      code: rawCode,
      status: "pending",
    });

    if (insertError) {
      // 23505 = unique_violation → déjà parrainé
      if ((insertError as { code?: string }).code === "23505") {
        return jsonResponse({ error: "already_referred" }, 409);
      }
      console.error("Insert referral error:", insertError);
      return jsonResponse({ error: "Erreur interne" }, 500);
    }

    return jsonResponse({ success: true, status: "pending" });
  } catch (error) {
    console.error("apply-referral error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
