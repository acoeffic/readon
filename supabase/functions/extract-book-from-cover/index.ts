// extract-book-from-cover
// Fallback IA du scan couverture : reçoit le texte OCR brut d'une photo
// (couverture, photo d'écran, page produit…) et en extrait le titre et
// l'auteur du livre principal via gpt-4o-mini.
// Appelée par l'app uniquement quand l'heuristique locale (taille de police
// + Google Books) n'a donné aucun résultat pertinent.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
  throw new Error("Missing SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY");
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

const SYSTEM_PROMPT = `Tu extrais le titre et l'auteur d'UN livre à partir d'un texte OCR bruité.
Le texte peut provenir d'une photo de couverture, d'une photo d'écran ou d'une page produit (Amazon, Fnac…) : il peut contenir des noms d'éditeurs, des prix, des notes, des bouts de description, des éléments d'interface.
Identifie le livre PRINCIPAL dont il est question.
Réponds UNIQUEMENT avec un objet JSON : {"title": "...", "author": "..."}.
- "title" : le titre exact du livre (sans sous-titre marketing, sans nom de collection).
- "author" : le nom de l'auteur, ou "" si tu ne peux pas l'identifier.
Si aucun livre n'est identifiable, réponds {"title": "", "author": ""}.`;

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
    const ocrText = typeof body.ocr_text === "string" ? body.ocr_text : "";
    if (!ocrText.trim()) {
      return jsonResponse({ title: "", author: "" });
    }

    // Borne la taille du texte envoyé au modèle (l'OCR d'une photo d'écran
    // peut être très verbeux)
    const truncated = ocrText.slice(0, 3000);

    const openaiResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: truncated },
          ],
          max_tokens: 120,
          temperature: 0,
          response_format: { type: "json_object" },
        }),
      },
    );

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error("OpenAI error:", error);
      return jsonResponse({ error: "Erreur du service IA" }, 502);
    }

    // Trace l'usage (pas de plafond : gpt-4o-mini, coût négligeable)
    await supabase.from("ai_usage").insert({
      user_id: user.id,
      feature: "scan_extract",
    });

    const openaiData = await openaiResponse.json();
    const content = openaiData.choices?.[0]?.message?.content ?? "{}";

    let parsed: { title?: unknown; author?: unknown } = {};
    try {
      parsed = JSON.parse(content);
    } catch {
      console.error("Failed to parse GPT response:", content);
    }

    const title = typeof parsed.title === "string" ? parsed.title.trim() : "";
    const author = typeof parsed.author === "string" ? parsed.author.trim() : "";

    return jsonResponse({ title, author });
  } catch (error) {
    console.error("extract-book-from-cover error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
