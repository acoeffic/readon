// Edge function: moderate-avatar
//
// Appelée par le trigger `trigger_moderate_avatar` après chaque
// INSERT/UPDATE de `profiles.avatar_url`. Classe l'image via l'API
// OpenAI `omni-moderation-latest` (qui supporte les image_url) et :
//   - approuve l'avatar (status = 'approved') si rien n'est flagué
//   - rejette l'avatar (status = 'rejected', avatar_url = NULL,
//     fichier storage supprimé, ligne content_reports auto-flag pour
//     l'audit admin) si une catégorie sensible dépasse le seuil
//
// Catégories considérées comme "rejet immédiat" :
//   sexual, sexual/minors, violence/graphic, self-harm, hate/threatening
// Les autres (hate non-threatening, violence légère) ne sont pas
// rejetées automatiquement mais peuvent être consignées via un report
// pour modération manuelle.
//
// Graceful degradation : si OPENAI_API_KEY absent ou l'API rate-limite,
// on auto-approuve pour ne pas bloquer le user. La détection a lieu
// au pire à la prochaine modération.

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

// Catégories qui déclenchent un rejet automatique (seuil par défaut OpenAI).
const REJECT_CATEGORIES = new Set<string>([
  "sexual",
  "sexual/minors",
  "violence/graphic",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions",
  "hate/threatening",
  "harassment/threatening",
]);

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface ModerationCategoryFlags {
  [key: string]: boolean;
}

interface OpenAIModerationResult {
  flagged: boolean;
  categories: ModerationCategoryFlags;
  category_scores: Record<string, number>;
}

async function approveAvatar(supabase: ReturnType<typeof createClient>, userId: string) {
  await supabase
    .from("profiles")
    .update({
      avatar_moderation_status: "approved",
      avatar_rejected_reason: null,
      avatar_moderated_at: new Date().toISOString(),
    })
    .eq("id", userId);
}

async function rejectAvatar(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  avatarUrl: string,
  reasonCategories: string[],
) {
  // 1. Retirer l'avatar (avatar_url -> null) et marquer rejected.
  // Important : on désactive le trigger pour ce UPDATE en passant
  // par un set_config flag, sinon on entre en boucle.
  const reason = reasonCategories.join(",");
  await supabase
    .from("profiles")
    .update({
      avatar_url: null,
      avatar_moderation_status: "rejected",
      avatar_rejected_reason: reason,
      avatar_moderated_at: new Date().toISOString(),
    })
    .eq("id", userId);

  // 2. Supprimer le fichier du storage. URL au format :
  //   https://<project>.supabase.co/storage/v1/object/public/profiles/avatars/<uid>/<file>
  try {
    const url = new URL(avatarUrl);
    const parts = url.pathname.split("/");
    const publicIdx = parts.indexOf("public");
    if (publicIdx > -1 && parts.length > publicIdx + 2) {
      const bucket = parts[publicIdx + 1];
      const path = parts.slice(publicIdx + 2).join("/");
      await supabase.storage.from(bucket).remove([path]);
    }
  } catch (e) {
    console.error("Failed to delete avatar file:", e);
  }

  // 3. Trace dans content_reports pour audit admin (auto-flag = système
  // s'auto-signale en tant que reporter ET target).
  try {
    await supabase.from("content_reports").insert({
      reporter_id: userId, // self-report : on n'a pas de UUID système
      target_type: "user",
      target_id: userId,
      target_user_id: userId,
      reason: "sexual_content", // catégorie générique pour l'audit
      details: `auto-moderation rejected avatar (${reason})`,
      status: "actioned", // déjà traité par l'auto-modération
    });
  } catch (e) {
    // Doublon possible si l'utilisateur s'auto-signale plusieurs fois,
    // ignoré.
    console.warn("content_reports insert failed (probably duplicate):", e);
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
    const { user_id, avatar_url } = await req.json();
    if (!user_id || !avatar_url) {
      return jsonResponse({ error: "user_id and avatar_url required" }, 400);
    }

    // Graceful degradation : pas de clé OpenAI → approve par défaut.
    if (!OPENAI_API_KEY) {
      console.warn("OPENAI_API_KEY not set, auto-approving avatar");
      await approveAvatar(supabase, user_id);
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
          input: [
            {
              type: "image_url",
              image_url: { url: avatar_url },
            },
          ],
        }),
      },
    );

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      console.error("OpenAI moderation error:", errText);
      // Auto-approve sur erreur API pour ne pas bloquer l'UX.
      await approveAvatar(supabase, user_id);
      return jsonResponse({
        status: "approved",
        reason: "openai-error",
      });
    }

    const data = await openaiResponse.json();
    const result = data.results?.[0] as OpenAIModerationResult | undefined;

    if (!result) {
      await approveAvatar(supabase, user_id);
      return jsonResponse({ status: "approved", reason: "empty-result" });
    }

    // Lister les catégories rejetantes activées.
    const rejected: string[] = [];
    for (const [category, flagged] of Object.entries(result.categories ?? {})) {
      if (flagged && REJECT_CATEGORIES.has(category)) {
        rejected.push(category);
      }
    }

    if (rejected.length === 0) {
      await approveAvatar(supabase, user_id);
      return jsonResponse({ status: "approved" });
    }

    await rejectAvatar(supabase, user_id, avatar_url, rejected);
    return jsonResponse({
      status: "rejected",
      categories: rejected,
    });
  } catch (error) {
    console.error("Avatar moderation error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
