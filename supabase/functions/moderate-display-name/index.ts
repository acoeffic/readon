// Edge function: moderate-display-name
//
// Appelée par le trigger `trigger_moderate_display_name` après chaque
// INSERT/UPDATE de `profiles.display_name`. Classe le pseudo via
// OpenAI omni-moderation-latest et :
//   - approuve (status = 'approved') si rien n'est flagué
//   - rejette (status = 'rejected', display_name reverte à la valeur
//     précédente, ou NULL si pas de précédent) si une catégorie sensible
//     dépasse le seuil
//
// Catégories considérées "rejet immédiat" pour un pseudo :
//   sexual, sexual/minors, hate, hate/threatening,
//   harassment, harassment/threatening, self-harm*, violence/graphic
// (Plus strict que pour les avatars : un pseudo est un identifiant public
// permanent, donc on bloque même `hate` non-threatening.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const REJECT_CATEGORIES = new Set<string>([
  "sexual",
  "sexual/minors",
  "hate",
  "hate/threatening",
  "harassment",
  "harassment/threatening",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions",
  "violence/graphic",
]);

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function approveDisplayName(
  supabase: ReturnType<typeof createClient>,
  userId: string,
) {
  await supabase
    .from("profiles")
    .update({
      display_name_moderation_status: "approved",
      display_name_rejected_reason: null,
      display_name_moderated_at: new Date().toISOString(),
    })
    .eq("id", userId);
}

async function rejectDisplayName(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  oldValue: string | null,
  reasonCategories: string[],
) {
  const reason = reasonCategories.join(",");
  // Reverte au pseudo précédent (ou NULL si signup) + statut rejected.
  await supabase
    .from("profiles")
    .update({
      display_name: oldValue,
      display_name_moderation_status: "rejected",
      display_name_rejected_reason: reason,
      display_name_moderated_at: new Date().toISOString(),
    })
    .eq("id", userId);

  // Trace dans content_reports (audit admin)
  try {
    await supabase.from("content_reports").insert({
      reporter_id: userId,
      target_type: "user",
      target_id: userId,
      target_user_id: userId,
      reason: "hate_speech",
      details: `auto-moderation rejected display_name (${reason})`,
      status: "actioned",
    });
  } catch (e) {
    console.warn("content_reports insert failed:", e);
  }
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

  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const { user_id, new_value, old_value } = await req.json();
    if (!user_id || typeof new_value !== "string" || !new_value.trim()) {
      return jsonResponse(
        { error: "user_id and non-empty new_value required" },
        400,
      );
    }

    if (!OPENAI_API_KEY) {
      console.warn("OPENAI_API_KEY not set, auto-approving display_name");
      await approveDisplayName(supabase, user_id);
      return jsonResponse({ status: "approved", reason: "no-openai-key" });
    }

    const openaiResponse = await fetch(
      "https://api.openai.com/v1/moderations",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: "omni-moderation-latest",
          input: new_value,
        }),
      },
    );

    if (!openaiResponse.ok) {
      console.error(
        "OpenAI moderation error:",
        await openaiResponse.text(),
      );
      await approveDisplayName(supabase, user_id);
      return jsonResponse({ status: "approved", reason: "openai-error" });
    }

    const data = await openaiResponse.json();
    const result = data.results?.[0];
    if (!result) {
      await approveDisplayName(supabase, user_id);
      return jsonResponse({ status: "approved", reason: "empty-result" });
    }

    const rejected: string[] = [];
    for (const [category, flagged] of Object.entries(result.categories ?? {})) {
      if (flagged && REJECT_CATEGORIES.has(category)) {
        rejected.push(category);
      }
    }

    if (rejected.length === 0) {
      await approveDisplayName(supabase, user_id);
      return jsonResponse({ status: "approved" });
    }

    await rejectDisplayName(
      supabase,
      user_id,
      typeof old_value === "string" && old_value.trim() !== "" ? old_value : null,
      rejected,
    );
    return jsonResponse({
      status: "rejected",
      categories: rejected,
    });
  } catch (error) {
    console.error("display_name moderation error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
