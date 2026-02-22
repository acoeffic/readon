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

PERSONNALISATION :
- Base tes recommandations principalement sur les lectures passées de l'utilisateur fournies dans le contexte.
- Analyse les genres, auteurs et thèmes récurrents dans ses lectures pour identifier ses goûts.
- Si l'utilisateur a lu beaucoup d'un genre/auteur, propose des titres similaires ou du même auteur.
- Explique le lien entre ta recommandation et les lectures passées de l'utilisateur (ex: "Puisque tu as aimé X de Y, tu devrais apprécier Z car...").
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
  const { data: finished } = await supabase
    .from("user_books")
    .select("books(title, author, genre)")
    .eq("user_id", userId)
    .eq("status", "finished")
    .order("created_at", { ascending: false })
    .limit(30);

  const { data: reading } = await supabase
    .from("user_books")
    .select("books(title, author, genre)")
    .eq("user_id", userId)
    .eq("status", "reading");

  const { data: toRead } = await supabase
    .from("user_books")
    .select("books(title, author, genre)")
    .eq("user_id", userId)
    .eq("status", "to_read")
    .order("created_at", { ascending: false })
    .limit(20);

  const { data: goals } = await supabase
    .from("reading_goals")
    .select("goal_type, target_value")
    .eq("user_id", userId)
    .eq("is_active", true)
    .eq("year", new Date().getFullYear());

  const formatBooks = (books: any[]) =>
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
  for (const b of allReadBooks) {
    const book = b.books;
    if (!book) continue;
    if (book.genre) genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
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

  let ctx = "";
  if (topGenres.length) ctx += `Genres préférés: ${topGenres.join(", ")}\n\n`;
  if (topAuthors.length) ctx += `Auteurs favoris (plusieurs livres lus): ${topAuthors.join(", ")}\n\n`;
  if (finished?.length) ctx += `Livres terminés récemment (${finished.length}):\n${formatBooks(finished)}\n\n`;
  if (reading?.length) ctx += `En cours de lecture:\n${formatBooks(reading)}\n\n`;
  if (toRead?.length) ctx += `Liste à lire (ne pas recommander ceux-ci):\n${formatBooks(toRead)}\n\n`;
  if (goals?.length) {
    ctx += `Objectifs de lecture:\n${goals.map((g: any) => `- ${g.goal_type}: ${g.target_value}`).join("\n")}\n`;
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

    const devForcePremium = Deno.env.get("DEV_FORCE_PREMIUM") === "true";
    const isPremium = devForcePremium || profile?.is_premium === true;

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
          model: "gpt-4o-mini",
          messages,
          max_tokens: 1000,
          temperature: 0.3,
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
