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

const SYSTEM_PROMPT = `Tu es un moteur de recommandation de livres. On te donne l'historique de lecture d'un utilisateur avec les genres, auteurs et titres.

RÈGLES :
- Recommande exactement le nombre de livres demandé.
- Ne recommande JAMAIS un livre déjà dans l'historique de l'utilisateur (lu, en cours, ou à lire).
- Ne recommande QUE des livres qui existent réellement. N'invente rien.
- Base-toi sur les patterns de lecture : genres dominants, auteurs favoris, thèmes récurrents.
- Si l'utilisateur lit beaucoup d'un genre spécifique (ex: jeunesse, SF, policier), la majorité des suggestions doivent être de ce genre.
- Varie les auteurs dans tes suggestions.
- Réponds UNIQUEMENT avec un JSON valide, sans texte autour.

FORMAT DE RÉPONSE (JSON uniquement) :
[
  {
    "title": "Titre exact du livre",
    "author": "Auteur exact",
    "reason": "Courte explication en français (1 phrase) du lien avec les lectures de l'utilisateur"
  }
]`;

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
    const limit = Math.min(body.limit ?? 5, 10);

    // Récupérer l'historique de lecture
    const { data: finished } = await supabase
      .from("user_books")
      .select("books(title, author, genre)")
      .eq("user_id", user.id)
      .eq("status", "finished")
      .order("updated_at", { ascending: false })
      .limit(30);

    const { data: reading } = await supabase
      .from("user_books")
      .select("books(title, author, genre)")
      .eq("user_id", user.id)
      .eq("status", "reading");

    const { data: toRead } = await supabase
      .from("user_books")
      .select("books(title, author, genre)")
      .eq("user_id", user.id)
      .eq("status", "to_read")
      .limit(20);

    const formatBooks = (books: any[]) =>
      (books ?? [])
        .map((b: any) => {
          const book = b.books;
          if (!book) return null;
          return `- ${book.title}${book.author ? ` de ${book.author}` : ""}${book.genre ? ` (${book.genre})` : ""}`;
        })
        .filter(Boolean)
        .join("\n");

    // Analyse des genres
    const allBooks = [...(finished ?? []), ...(reading ?? [])];
    const genreCounts: Record<string, number> = {};
    for (const b of allBooks) {
      const book = b.books;
      if (book?.genre) genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
    }

    const topGenres = Object.entries(genreCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([genre, count]) => `${genre} (${count} livres)`);

    let userContext = "";
    if (topGenres.length) userContext += `Genres préférés: ${topGenres.join(", ")}\n\n`;
    if (finished?.length) userContext += `Livres terminés (${finished.length}):\n${formatBooks(finished)}\n\n`;
    if (reading?.length) userContext += `En cours de lecture:\n${formatBooks(reading)}\n\n`;
    if (toRead?.length) userContext += `Liste à lire (NE PAS recommander):\n${formatBooks(toRead)}\n`;

    if (!userContext.trim()) {
      return jsonResponse({ suggestions: [] });
    }

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
            {
              role: "user",
              content: `Recommande ${limit} livres pour cet utilisateur.\n\n${userContext}`,
            },
          ],
          max_tokens: 800,
          temperature: 0.7,
        }),
      }
    );

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error("OpenAI error:", error);
      return jsonResponse({ error: "Erreur du service IA" }, 502);
    }

    const openaiData = await openaiResponse.json();
    const content = openaiData.choices?.[0]?.message?.content ?? "[]";

    // Parser le JSON de la réponse
    let suggestions: any[];
    try {
      // Extraire le JSON même si GPT ajoute du texte autour
      const jsonMatch = content.match(/\[[\s\S]*\]/);
      suggestions = jsonMatch ? JSON.parse(jsonMatch[0]) : [];
    } catch {
      console.error("Failed to parse GPT response:", content);
      suggestions = [];
    }

    // Valider la structure
    const validated = suggestions
      .filter(
        (s: any) =>
          typeof s.title === "string" &&
          typeof s.author === "string" &&
          s.title.length > 0
      )
      .slice(0, limit)
      .map((s: any) => ({
        title: s.title,
        author: s.author,
        reason: s.reason ?? "",
      }));

    return jsonResponse({ suggestions: validated });
  } catch (error) {
    console.error("ai-suggest-books error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
