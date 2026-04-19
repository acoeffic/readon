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

const MAX_FREE_MONTHLY_MESSAGES = 3;

const SYSTEM_PROMPT = `Tu es Muse, conseillère littéraire passionnée et bienveillante pour l'application ReadOn.
Tu réponds toujours en français. Sois concise mais chaleureuse (3-4 paragraphes maximum).

RÈGLES IMPORTANTES :
- Tu ne recommandes QUE des livres dont tu es absolument certaine qu'ils existent réellement (titre exact, auteur exact, date de publication connue).
- N'invente JAMAIS de titre, d'auteur ou de livre. Si tu n'es pas sûre qu'un livre existe, ne le mentionne pas.
- FORMATAGE OBLIGATOIRE : quand tu mentionnes un livre, utilise TOUJOURS le format "Titre exact" de Auteur exact (avec les guillemets droits autour du titre). Exemples : "L'Étranger" de Albert Camus, "1984" de George Orwell.
- Ne recommande pas de livres que l'utilisateur a déjà lus, est en train de lire, ou a dans sa liste "à lire".

STRATÉGIE DE RECOMMANDATION :
1. Identifie le PROFIL du lecteur à partir du contexte : fiction vs non-fiction, thèmes dominants, niveau de complexité, langue préférée.
2. Respecte le profil : si le lecteur lit principalement du non-fiction/business/développement personnel, recommande d'ABORD dans ces catégories. Ne propose pas de roman policier à quelqu'un qui lit 100% business, sauf s'il le demande explicitement.
3. Utilise les SIGNAUX D'ENGAGEMENT fournis dans le contexte :
   - Livres lus rapidement (pages/jour élevé) = probablement appréciés → recommande dans la même veine
   - Livres avec beaucoup d'annotations = forte appréciation → recommande des livres similaires en thème et style
   - Livres abandonnés (marqués dans le contexte) = signal négatif → évite ce genre/style
4. Priorise la RÉCENCE : les 5 derniers livres terminés comptent 3x plus que les anciens dans ton analyse des goûts.
5. Analyse les DESCRIPTIONS des livres lus (fournies dans le contexte) pour comprendre les thèmes précis, pas juste le genre.
6. Adapte la LONGUEUR : si le lecteur lit surtout des livres courts (<250 pages), ne recommande pas des pavés de 800 pages, et vice-versa.
7. Si le lecteur a un profil mixte (ex: business + fiction), ancre ta recommandation dans le genre de ses lectures les plus récentes, sauf demande contraire.

PERSONNALISATION :
- Explique le lien PRÉCIS entre ta recommandation et les lectures passées (ex: "Puisque tu as apprécié le thème de l'investissement passif dans X, tu devrais aimer Y qui approfondit la stratégie DCA avec des études de cas concrètes").
- Si l'utilisateur n'a pas encore de lectures, propose des classiques reconnus et demande-lui ses préférences.

Si l'utilisateur pose une question sans rapport avec la lecture ou les livres, rappelle-lui poliment que tu es Muse, sa conseillère lecture, et propose-lui de l'aider à trouver son prochain livre.`;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function buildUserContext(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<string> {
  // Fetch all data in parallel for performance
  const [
    { data: finished },
    { data: reading },
    { data: toRead },
    { data: goals },
    { data: sessions },
    { data: annotationCounts },
  ] = await Promise.all([
    supabase
      .from("user_books")
      .select("book_id, updated_at, books(title, author, genre, description, page_count, language)")
      .eq("user_id", userId)
      .eq("status", "finished")
      .order("updated_at", { ascending: false })
      .limit(30),
    supabase
      .from("user_books")
      .select("book_id, created_at, books(title, author, genre, description, page_count, language)")
      .eq("user_id", userId)
      .eq("status", "reading"),
    supabase
      .from("user_books")
      .select("books(title, author, genre)")
      .eq("user_id", userId)
      .eq("status", "to_read")
      .order("created_at", { ascending: false })
      .limit(20),
    supabase
      .from("reading_goals")
      .select("goal_type, target_value")
      .eq("user_id", userId)
      .eq("is_active", true)
      .eq("year", new Date().getFullYear()),
    // Reading sessions for pace calculation (last 6 months)
    supabase
      .from("reading_sessions")
      .select("book_id, start_page, end_page, start_time, end_time")
      .eq("user_id", userId)
      .not("end_time", "is", null)
      .gte("start_time", new Date(Date.now() - 180 * 86400000).toISOString())
      .order("start_time", { ascending: false })
      .limit(200),
    // Annotation counts per book (engagement signal)
    supabase
      .from("annotations")
      .select("book_id")
      .eq("user_id", userId),
  ]);

  // Build annotation count map
  const annotationMap: Record<string, number> = {};
  for (const a of annotationCounts ?? []) {
    annotationMap[a.book_id] = (annotationMap[a.book_id] || 0) + 1;
  }

  // Build reading pace map (pages per day per book)
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

  // Detect abandoned books (status = reading, no session in 30+ days)
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

        // Engagement signals
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

        // Description (truncated) for thematic understanding
        if (book.description) parts.push(`  ${truncate(book.description, 120)}`);

        // Finished date for recency
        if (b.updated_at) {
          const d = new Date(b.updated_at);
          parts[0] += ` (terminé ${d.toLocaleDateString("fr-FR", { month: "short", year: "numeric" })})`;
        }

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

  // Analyse des patterns de lecture
  const allReadBooks = [...(finished ?? []), ...(reading ?? [])];
  const genreCounts: Record<string, number> = {};
  const authorCounts: Record<string, number> = {};
  let fictionCount = 0;
  let nonFictionCount = 0;
  const fictionGenres = new Set(["fiction", "roman", "fantasy", "science-fiction", "sf", "thriller", "policier", "romance", "horreur", "aventure", "literary fiction", "mystery", "comics", "manga", "bd", "poésie", "jeunesse", "young adult"]);

  for (const b of allReadBooks) {
    const book = b.books;
    if (!book) continue;
    if (book.genre) {
      genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
      if (fictionGenres.has(book.genre.toLowerCase())) fictionCount++;
      else nonFictionCount++;
    }
    if (book.author) authorCounts[book.author] = (authorCounts[book.author] || 0) + 1;
  }

  const topGenres = Object.entries(genreCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([genre, count]) => `${genre} (${count} livres)`);

  const topAuthors = Object.entries(authorCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .filter(([_, count]) => count >= 2)
    .map(([author, count]) => `${author} (${count} livres)`);

  // Average page count
  const pageCounts = allReadBooks
    .map((b: any) => b.books?.page_count)
    .filter((p: any) => p && p > 0);
  const avgPages = pageCounts.length
    ? Math.round(pageCounts.reduce((a: number, b: number) => a + b, 0) / pageCounts.length)
    : null;

  // Abandoned books
  const abandoned = (reading ?? []).filter((b: any) => {
    const lastSession = lastSessionByBook[b.book_id];
    if (!lastSession) {
      // No session at all, check created_at
      return b.created_at && new Date(b.created_at).getTime() < thirtyDaysAgo;
    }
    return lastSession < thirtyDaysAgo;
  });

  // Build context string
  let ctx = "";

  // Reader profile summary
  const profileParts: string[] = [];
  if (fictionCount + nonFictionCount > 0) {
    const fictionPct = Math.round((fictionCount / (fictionCount + nonFictionCount)) * 100);
    if (fictionPct > 70) profileParts.push("Profil : lecteur majoritairement FICTION");
    else if (fictionPct < 30) profileParts.push("Profil : lecteur majoritairement NON-FICTION");
    else profileParts.push(`Profil : lecteur mixte (${fictionPct}% fiction, ${100 - fictionPct}% non-fiction)`);
  }
  if (avgPages) profileParts.push(`Longueur moyenne des livres lus : ${avgPages} pages`);

  // Preferred language
  const langCounts: Record<string, number> = {};
  for (const b of allReadBooks) {
    const lang = b.books?.language;
    if (lang) langCounts[lang] = (langCounts[lang] || 0) + 1;
  }
  const topLang = Object.entries(langCounts).sort((a, b) => b[1] - a[1])[0];
  if (topLang) profileParts.push(`Langue principale : ${topLang[0]}`);

  if (profileParts.length) ctx += profileParts.join("\n") + "\n\n";

  if (topGenres.length) ctx += `Genres préférés : ${topGenres.join(", ")}\n\n`;
  if (topAuthors.length) ctx += `Auteurs favoris : ${topAuthors.join(", ")}\n\n`;
  if (finished?.length) ctx += `Livres terminés récemment (${finished.length}):\n${formatFinishedBooks(finished)}\n\n`;
  if (reading?.length) {
    ctx += `En cours de lecture :\n${formatSimpleBooks(reading)}\n\n`;
  }
  if (abandoned.length) {
    ctx += `Livres probablement abandonnés (pas de session depuis 30+ jours) :\n${formatSimpleBooks(abandoned)}\n\n`;
  }
  if (toRead?.length) ctx += `Liste à lire (ne pas recommander ceux-ci) :\n${formatSimpleBooks(toRead)}\n\n`;
  if (goals?.length) {
    ctx += `Objectifs de lecture :\n${goals.map((g: any) => `- ${g.goal_type}: ${g.target_value}`).join("\n")}\n`;
  }

  return ctx || "Aucune donnée de lecture disponible. Propose des classiques reconnus et demande les préférences du lecteur.";
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

  // Verify user JWT
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
    const { conversation_id, message, is_new_conversation } = body;

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      return jsonResponse({ error: "Message requis" }, 400);
    }

    // --- Premium check & monthly message limit enforcement ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium === true;

    if (!isPremium) {
      const startOfMonth = new Date();
      startOfMonth.setDate(1);
      startOfMonth.setHours(0, 0, 0, 0);

      // Get user's conversation IDs
      const { data: convIds } = await supabase
        .from("ai_conversations")
        .select("id")
        .eq("user_id", user.id);

      const ids = (convIds ?? []).map((c: any) => c.id);

      if (ids.length > 0) {
        const { count } = await supabase
          .from("ai_messages")
          .select("id", { count: "exact", head: true })
          .in("conversation_id", ids)
          .eq("role", "user")
          .gte("created_at", startOfMonth.toISOString());

        if ((count ?? 0) >= MAX_FREE_MONTHLY_MESSAGES) {
          return jsonResponse(
            {
              error: "limit_reached",
              message:
                "Tu as atteint la limite de 3 messages ce mois-ci. Abonne-toi pour une utilisation illimitée !",
            },
            403
          );
        }
      }
    }

    // --- Create or validate conversation ---
    let convId = conversation_id;
    if (is_new_conversation) {
      const { data: conv, error: convError } = await supabase
        .from("ai_conversations")
        .insert({
          user_id: user.id,
          title: message.trim().substring(0, 80),
        })
        .select()
        .single();

      if (convError) throw convError;
      convId = conv.id;
    } else {
      // Verify conversation belongs to user
      const { data: conv } = await supabase
        .from("ai_conversations")
        .select("id")
        .eq("id", convId)
        .eq("user_id", user.id)
        .single();

      if (!conv) {
        return jsonResponse({ error: "Conversation non trouvée" }, 404);
      }
    }

    // --- Save user message ---
    await supabase.from("ai_messages").insert({
      conversation_id: convId,
      role: "user",
      content: message.trim(),
    });

    // --- Build user reading context ---
    const context = await buildUserContext(supabase, user.id);

    // --- Fetch conversation history ---
    const { data: history } = await supabase
      .from("ai_messages")
      .select("role, content")
      .eq("conversation_id", convId)
      .order("created_at", { ascending: true })
      .limit(20);

    // --- Build OpenAI messages ---
    const messages = [
      { role: "system", content: SYSTEM_PROMPT },
      {
        role: "system",
        content: `Contexte du lecteur:\n${context}`,
      },
      ...(history ?? []).map((m: any) => ({
        role: m.role,
        content: m.content,
      })),
    ];

    // --- Call OpenAI API ---
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
          messages,
          max_tokens: 1000,
          temperature: 0.4,
        }),
      }
    );

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error("OpenAI error:", error);
      return jsonResponse({ error: "Erreur du service IA" }, 502);
    }

    const openaiData = await openaiResponse.json();
    const assistantMessage =
      openaiData.choices?.[0]?.message?.content ?? "";

    // --- Save assistant message ---
    await supabase.from("ai_messages").insert({
      conversation_id: convId,
      role: "assistant",
      content: assistantMessage,
    });

    // --- Update conversation timestamp ---
    await supabase
      .from("ai_conversations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", convId);

    return jsonResponse({
      conversation_id: convId,
      message: assistantMessage,
    });
  } catch (error) {
    console.error("AI chat error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
