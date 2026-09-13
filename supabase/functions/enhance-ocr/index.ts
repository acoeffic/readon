// supabase/functions/enhance-ocr/index.ts
//
// Repli « vision » de l'OCR embarqué : le client envoie le crop de la zone
// surlignée sur la photo, on le fait relire par un modèle vision et on renvoie
// le texte propre. Utilisé quand ML Kit lit mal (photo floue, page courbée,
// typographie exotique).
//
// Gratuit : MAX_FREE_MONTHLY_ENHANCEMENTS par mois. Premium : illimité.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY"
  );
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_FREE_MONTHLY_ENHANCEMENTS = 3;
const USAGE_FEATURE = "ocr";

// ~8 Mo de base64 (le client envoie un PNG gris de la seule zone surlignée,
// on est normalement bien en dessous).
const MAX_IMAGE_BASE64_LENGTH = 8_000_000;

const SYSTEM_PROMPT = `Tu es un moteur de reconnaissance de texte de haute précision.
On te donne la photo d'un extrait de livre — parfois floue, courbée ou mal éclairée — et, en indice, la lecture approximative d'un OCR embarqué.

Règles strictes :
- Retranscris EXACTEMENT le texte visible sur l'image, dans sa langue d'origine.
- Ne traduis pas, ne résume pas, ne reformule pas, n'ajoute ni commentaire ni guillemets d'encadrement.
- Recolle les mots coupés en fin de ligne (« géo- / graphie » → « géographie ») et rends un texte au fil courant, sans retour à la ligne artificiel.
- Conserve la ponctuation, les majuscules, les italiques marqués par des guillemets et la typographie d'origine.
- Ignore les numéros de page, titres courants et appels de note qui ne font pas partie du passage.
- N'invente jamais un mot illisible : si un mot est vraiment indéchiffrable, reprends la proposition de l'indice OCR.
- Si aucun texte n'est lisible sur l'image, réponds exactement : NO_TEXT

Réponds uniquement par le texte retranscrit.`;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function readImage(
  imageBase64: string,
  hintText: string | null
): Promise<string | null> {
  const MAX_ATTEMPTS = 2;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${OPENAI_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            temperature: 0,
            max_tokens: 1200,
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              {
                role: "user",
                content: [
                  {
                    type: "text",
                    text: hintText
                      ? `Lecture approximative de l'OCR embarqué (indice, peut contenir des erreurs) :\n${hintText}`
                      : "Aucun indice OCR disponible.",
                  },
                  {
                    type: "image_url",
                    image_url: {
                      url: `data:image/png;base64,${imageBase64}`,
                      detail: "high",
                    },
                  },
                ],
              },
            ],
          }),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();
        console.error(
          `enhance-ocr attempt ${attempt} failed (${response.status}):`,
          errorText
        );
        if (
          (response.status === 429 || response.status >= 500) &&
          attempt < MAX_ATTEMPTS
        ) {
          await new Promise((r) => setTimeout(r, 1000 * attempt));
          continue;
        }
        return null;
      }

      const data = await response.json();
      const text: string | undefined = data.choices?.[0]?.message?.content?.trim();
      return text && text.length > 0 ? text : null;
    } catch (error) {
      console.error(`enhance-ocr attempt ${attempt} error:`, error);
      if (attempt < MAX_ATTEMPTS) {
        await new Promise((r) => setTimeout(r, 1000 * attempt));
      }
    }
  }
  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!OPENAI_API_KEY) {
    return jsonResponse({ error: "OPENAI_API_KEY non configurée" }, 500);
  }

  // --- Auth ---
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
    const body = await req.json();
    const imageBase64 = body?.image_base64;
    const hintText =
      typeof body?.hint_text === "string" && body.hint_text.trim() !== ""
        ? String(body.hint_text).slice(0, 4000)
        : null;

    if (typeof imageBase64 !== "string" || imageBase64.length < 100) {
      return jsonResponse({ error: "image_base64 requis" }, 400);
    }
    if (imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
      return jsonResponse({ error: "Image trop lourde" }, 413);
    }

    // --- Premium check ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium === true;

    // --- Quota mensuel ---
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const { count: usageCount } = await supabase
      .from("ai_usage")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("feature", USAGE_FEATURE)
      .gte("used_at", startOfMonth.toISOString());

    const currentCount = usageCount ?? 0;

    if (!isPremium && currentCount >= MAX_FREE_MONTHLY_ENHANCEMENTS) {
      return jsonResponse({ error: "limit_reached", remaining: 0 }, 429);
    }

    // --- Lecture par le modèle vision ---
    const text = await readImage(imageBase64, hintText);

    if (!text) {
      return jsonResponse(
        { error: "read_failed", message: "La relecture a échoué. Réessaie." },
        502
      );
    }

    if (text === "NO_TEXT") {
      // Pas de crédit consommé : il n'y avait rien à lire.
      return jsonResponse(
        {
          error: "no_text",
          message: "Aucun texte lisible sur cette zone.",
        },
        422
      );
    }

    await supabase.from("ai_usage").insert({
      user_id: user.id,
      feature: USAGE_FEATURE,
    });

    const remaining = isPremium
      ? -1
      : Math.max(0, MAX_FREE_MONTHLY_ENHANCEMENTS - currentCount - 1);

    return jsonResponse({ text, remaining });
  } catch (error) {
    console.error("enhance-ocr error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
