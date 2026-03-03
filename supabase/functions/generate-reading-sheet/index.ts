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

const MIN_ANNOTATIONS = 3;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function buildSystemPrompt(
  title: string,
  author: string | null,
  annotationCount: number
): string {
  const authorPart = author ? ` de ${author}` : "";
  return `Tu es un assistant littéraire expert. L'utilisateur a lu le livre "${title}"${authorPart} et a pris ${annotationCount} annotations pendant sa lecture.

Analyse toutes ses annotations et produis une fiche de lecture structurée au format JSON avec les clés suivantes :

1. "themes" : Un tableau de 3-5 thèmes principaux identifiés dans les annotations. Chaque thème a un "title" (string, 2-4 mots) et une "description" (string, 1-2 phrases).

2. "quotes" : Un tableau des 3-5 citations les plus marquantes parmi les annotations. Chaque quote a un "text" (la citation exacte tirée des annotations), un "page" (le numéro de page si disponible, sinon null), et un "comment" (1 phrase d'analyse du pourquoi cette citation est notable).

3. "progression" : Un texte de 2-3 paragraphes décrivant l'évolution de la pensée du lecteur à travers ses annotations, de la première à la dernière.

4. "synthesis" : Un texte de 2-3 paragraphes constituant une synthèse personnelle de la lecture, basée uniquement sur ce que les annotations révèlent de l'expérience du lecteur.

Réponds UNIQUEMENT en JSON valide, sans markdown, sans backticks. Réponds en français si les annotations sont en français, en anglais si elles sont en anglais.`;
}

serve(async (req) => {
  // CORS preflight
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

  // Service-role client for data queries
  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const body = await req.json();
    const { book_id, force } = body;

    if (!book_id) {
      return jsonResponse({ error: "book_id requis" }, 400);
    }

    const bookIdInt = parseInt(book_id, 10);
    if (isNaN(bookIdInt)) {
      return jsonResponse({ error: "book_id invalide" }, 400);
    }

    // --- Premium check (100% premium feature) ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const devForcePremium = Deno.env.get("DEV_FORCE_PREMIUM") === "true";
    const isPremium = devForcePremium || profile?.is_premium === true;

    if (!isPremium) {
      return jsonResponse({ error: "premium_required", message: "Cette fonctionnalité est réservée aux utilisateurs Premium." }, 403);
    }

    // --- Check cached reading sheet ---
    const { data: userBook } = await supabase
      .from("user_books")
      .select("reading_sheet, reading_sheet_generated_at")
      .eq("user_id", user.id)
      .eq("book_id", bookIdInt)
      .maybeSingle();

    if (!userBook) {
      return jsonResponse({ error: "Livre non trouvé dans votre bibliothèque" }, 404);
    }

    if (userBook.reading_sheet && !force) {
      return jsonResponse({ reading_sheet: userBook.reading_sheet });
    }

    // --- Fetch book info ---
    const { data: book } = await supabase
      .from("books")
      .select("title, author, genre")
      .eq("id", bookIdInt)
      .single();

    if (!book) {
      return jsonResponse({ error: "Livre non trouvé" }, 404);
    }

    // --- Fetch all annotations ---
    const { data: annotations, error: annotationsError } = await supabase
      .from("annotations")
      .select("content, page_number, ai_summary, created_at")
      .eq("user_id", user.id)
      .eq("book_id", book_id)
      .order("page_number", { ascending: true, nullsFirst: false })
      .order("created_at", { ascending: true });

    if (annotationsError) {
      console.error("Annotations fetch error:", annotationsError);
      return jsonResponse({ error: "Erreur lors de la récupération des annotations" }, 500);
    }

    if (!annotations || annotations.length < MIN_ANNOTATIONS) {
      return jsonResponse({
        error: "not_enough_annotations",
        message: `Il faut au moins ${MIN_ANNOTATIONS} annotations pour générer une fiche de lecture.`,
        min_required: MIN_ANNOTATIONS,
        current_count: annotations?.length ?? 0,
      }, 400);
    }

    // --- Build user message with all annotations ---
    const annotationTexts = annotations.map((a: { content: string; page_number: number | null; ai_summary: string | null }, i: number) => {
      const pageInfo = a.page_number ? ` (page ${a.page_number})` : "";
      return `[Annotation ${i + 1}${pageInfo}]\n${a.content}`;
    });

    const userMessage = annotationTexts.join("\n\n");

    // --- Call OpenAI API ---
    const systemPrompt = buildSystemPrompt(book.title, book.author, annotations.length);

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
          max_tokens: 2000,
          temperature: 0.4,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userMessage },
          ],
        }),
      }
    );

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error("OpenAI error:", error);
      return jsonResponse({ error: "Erreur du service IA" }, 502);
    }

    const openaiData = await openaiResponse.json();
    const rawContent = openaiData.choices?.[0]?.message?.content ?? "";

    if (!rawContent) {
      return jsonResponse({ error: "Réponse IA vide" }, 502);
    }

    // --- Parse JSON response ---
    let readingSheet: Record<string, unknown>;
    try {
      readingSheet = JSON.parse(rawContent);
    } catch {
      console.error("Failed to parse OpenAI JSON:", rawContent);
      return jsonResponse({ error: "Réponse IA invalide" }, 502);
    }

    // Add metadata
    readingSheet.annotation_count = annotations.length;

    // --- Store in user_books ---
    await supabase
      .from("user_books")
      .update({
        reading_sheet: readingSheet,
        reading_sheet_generated_at: new Date().toISOString(),
      })
      .eq("user_id", user.id)
      .eq("book_id", bookIdInt);

    // --- Record AI usage ---
    await supabase.from("ai_usage").insert({
      user_id: user.id,
      feature: "reading_sheet",
    });

    return jsonResponse({ reading_sheet: readingSheet });
  } catch (error) {
    console.error("Reading sheet error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
