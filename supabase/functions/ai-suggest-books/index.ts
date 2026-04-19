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

const SYSTEM_PROMPT = `Tu es un moteur de recommandation de livres ultra-pertinent. On te donne le profil de lecture complet d'un utilisateur avec des signaux d'engagement.

STRATÉGIE :
1. Identifie le PROFIL : fiction vs non-fiction, thèmes dominants, complexité, langue préférée.
2. Respecte le profil : si le lecteur est principalement non-fiction/business, recommande dans cette catégorie. Ne propose pas de romans à un lecteur 100% non-fiction.
3. Priorise la RÉCENCE : les 5 derniers livres terminés pèsent 3x plus. Recommande dans la continuité thématique des lectures récentes.
4. Utilise les SIGNAUX D'ENGAGEMENT : livres annotés ou lus rapidement = forte appréciation → recommande dans la même veine. Livres abandonnés = signal négatif → évite ce style.
5. Adapte la longueur : respecte la longueur moyenne des livres lus par l'utilisateur.
6. Analyse les DESCRIPTIONS des livres lus pour comprendre les thèmes précis, pas juste le genre.

RÈGLES :
- Recommande exactement le nombre de livres demandé.
- Ne recommande JAMAIS un livre déjà dans l'historique de l'utilisateur (lu, en cours, ou à lire).
- Ne recommande QUE des livres qui existent réellement. N'invente rien.
- Varie les auteurs dans tes suggestions.
- Réponds UNIQUEMENT avec un JSON valide, sans texte autour.

FORMAT DE RÉPONSE (JSON uniquement) :
[
  {
    "title": "Titre exact du livre",
    "author": "Auteur exact",
    "reason": "Courte explication en français (1 phrase) du lien PRÉCIS avec les lectures récentes de l'utilisateur"
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

    // Fetch all data in parallel
    const [
      { data: finished },
      { data: reading },
      { data: toRead },
      { data: sessions },
      { data: annotationCounts },
    ] = await Promise.all([
      supabase
        .from("user_books")
        .select("book_id, updated_at, books(title, author, genre, description, page_count, language)")
        .eq("user_id", user.id)
        .eq("status", "finished")
        .order("updated_at", { ascending: false })
        .limit(30),
      supabase
        .from("user_books")
        .select("book_id, created_at, books(title, author, genre)")
        .eq("user_id", user.id)
        .eq("status", "reading"),
      supabase
        .from("user_books")
        .select("books(title, author, genre)")
        .eq("user_id", user.id)
        .eq("status", "to_read")
        .limit(20),
      supabase
        .from("reading_sessions")
        .select("book_id, start_page, end_page, start_time, end_time")
        .eq("user_id", user.id)
        .not("end_time", "is", null)
        .gte("start_time", new Date(Date.now() - 180 * 86400000).toISOString())
        .limit(200),
      supabase
        .from("annotations")
        .select("book_id")
        .eq("user_id", user.id),
    ]);

    // Build annotation count map
    const annotationMap: Record<string, number> = {};
    for (const a of annotationCounts ?? []) {
      annotationMap[a.book_id] = (annotationMap[a.book_id] || 0) + 1;
    }

    // Build reading pace map
    const bookPace: Record<string, { totalPages: number; totalDays: number }> = {};
    for (const s of sessions ?? []) {
      if (!s.end_page || !s.start_page || !s.end_time || !s.start_time) continue;
      const pages = s.end_page - s.start_page;
      const hours = (new Date(s.end_time).getTime() - new Date(s.start_time).getTime()) / 3600000;
      if (pages <= 0 || hours <= 0) continue;
      if (!bookPace[s.book_id]) bookPace[s.book_id] = { totalPages: 0, totalDays: 0 };
      bookPace[s.book_id].totalPages += pages;
      bookPace[s.book_id].totalDays += hours / 24;
    }

    // Detect abandoned books
    const thirtyDaysAgo = Date.now() - 30 * 86400000;
    const lastSessionByBook: Record<string, number> = {};
    for (const s of sessions ?? []) {
      if (!s.end_time) continue;
      const t = new Date(s.end_time).getTime();
      if (!lastSessionByBook[s.book_id] || t > lastSessionByBook[s.book_id]) {
        lastSessionByBook[s.book_id] = t;
      }
    }

    const truncate = (text: string | null, maxLen: number): string => {
      if (!text) return "";
      return text.length > maxLen ? text.substring(0, maxLen) + "…" : text;
    };

    const formatFinishedBooks = (books: any[]) =>
      (books ?? [])
        .map((b: any) => {
          const book = b.books;
          if (!book) return null;
          const parts = [`- ${book.title}`];
          if (book.author) parts[0] += ` de ${book.author}`;
          if (book.genre) parts[0] += ` (${book.genre})`;
          if (book.page_count) parts[0] += ` [${book.page_count}p]`;
          const annotations = annotationMap[b.book_id] || 0;
          const pace = bookPace[b.book_id];
          const signals: string[] = [];
          if (annotations > 0) signals.push(`${annotations} annotations`);
          if (pace && pace.totalDays > 0) {
            const pagesPerDay = Math.round(pace.totalPages / pace.totalDays);
            if (pagesPerDay > 100) signals.push("lu rapidement");
            else if (pagesPerDay < 20 && pace.totalDays > 14) signals.push("lu lentement");
          }
          if (signals.length) parts[0] += ` → ${signals.join(", ")}`;
          if (book.description) parts.push(`  ${truncate(book.description, 120)}`);
          return parts.join("\n");
        })
        .filter(Boolean)
        .join("\n");

    const formatSimpleBooks = (books: any[]) =>
      (books ?? [])
        .map((b: any) => {
          const book = b.books;
          if (!book) return null;
          return `- ${book.title}${book.author ? ` de ${book.author}` : ""}${book.genre ? ` (${book.genre})` : ""}`;
        })
        .filter(Boolean)
        .join("\n");

    // Analyse des patterns
    const allBooks = [...(finished ?? []), ...(reading ?? [])];
    const genreCounts: Record<string, number> = {};
    const fictionGenres = new Set(["fiction", "roman", "fantasy", "science-fiction", "sf", "thriller", "policier", "romance", "horreur", "aventure", "literary fiction", "mystery", "comics", "manga", "bd", "poésie", "jeunesse", "young adult"]);
    let fictionCount = 0, nonFictionCount = 0;
    for (const b of allBooks) {
      const book = b.books;
      if (book?.genre) {
        genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
        if (fictionGenres.has(book.genre.toLowerCase())) fictionCount++;
        else nonFictionCount++;
      }
    }

    const topGenres = Object.entries(genreCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([genre, count]) => `${genre} (${count} livres)`);

    // Average page count
    const pageCounts = allBooks.map((b: any) => b.books?.page_count).filter((p: any) => p && p > 0);
    const avgPages = pageCounts.length
      ? Math.round(pageCounts.reduce((a: number, b: number) => a + b, 0) / pageCounts.length)
      : null;

    const abandoned = (reading ?? []).filter((b: any) => {
      const lastSession = lastSessionByBook[b.book_id];
      if (!lastSession) return b.created_at && new Date(b.created_at).getTime() < thirtyDaysAgo;
      return lastSession < thirtyDaysAgo;
    });

    // Build context
    let userContext = "";
    const profileParts: string[] = [];
    if (fictionCount + nonFictionCount > 0) {
      const fictionPct = Math.round((fictionCount / (fictionCount + nonFictionCount)) * 100);
      if (fictionPct > 70) profileParts.push("Profil : lecteur majoritairement FICTION");
      else if (fictionPct < 30) profileParts.push("Profil : lecteur majoritairement NON-FICTION");
      else profileParts.push(`Profil : lecteur mixte (${fictionPct}% fiction, ${100 - fictionPct}% non-fiction)`);
    }
    if (avgPages) profileParts.push(`Longueur moyenne : ${avgPages} pages`);
    if (profileParts.length) userContext += profileParts.join("\n") + "\n\n";

    if (topGenres.length) userContext += `Genres préférés : ${topGenres.join(", ")}\n\n`;
    if (finished?.length) userContext += `Livres terminés (${finished.length}):\n${formatFinishedBooks(finished)}\n\n`;
    if (reading?.length) userContext += `En cours de lecture :\n${formatSimpleBooks(reading)}\n\n`;
    if (abandoned.length) userContext += `Livres probablement abandonnés :\n${formatSimpleBooks(abandoned)}\n\n`;
    if (toRead?.length) userContext += `Liste à lire (NE PAS recommander) :\n${formatSimpleBooks(toRead)}\n`;

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
          model: "gpt-4o",
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            {
              role: "user",
              content: `Recommande ${limit} livres pour cet utilisateur.\n\n${userContext}`,
            },
          ],
          max_tokens: 800,
          temperature: 0.5,
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
