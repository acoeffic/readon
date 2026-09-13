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

// Suggestions cadeaux (outil suggest_gift_books) : plafond mensuel séparé
// pour les utilisateurs gratuits, suivi via ai_usage (feature = "gift_suggest").
// Un tour de désambiguïsation (ami introuvable / plusieurs matchs) ne consomme rien.
const MAX_FREE_MONTHLY_GIFT_SUGGESTIONS = 2;

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

CADEAUX :
- Si l'utilisateur cherche un livre à OFFRIR à quelqu'un (cadeau, anniversaire, Noël, remerciement…), appelle l'outil suggest_gift_books avec le prénom/nom mentionné. N'essaie JAMAIS de deviner les goûts d'un ami toi-même : utilise uniquement ce que l'outil renvoie.
- Si l'outil signale que l'ami est introuvable ou que plusieurs amis correspondent, demande une précision à l'utilisateur (sans appeler l'outil à nouveau dans le même tour).
- Si la personne à qui offrir n'est pas un ami ReadOn (collègue, grand-mère…), n'appelle pas l'outil : demande simplement à l'utilisateur de décrire ses goûts.

Si l'utilisateur pose une question sans rapport avec la lecture ou les livres, rappelle-lui poliment que tu es Muse, sa conseillère lecture, et propose-lui de l'aider à trouver son prochain livre.`;

// Outil OpenAI : déclenché quand l'utilisateur cherche un livre à offrir.
const GIFT_TOOL = {
  type: "function",
  function: {
    name: "suggest_gift_books",
    description:
      "À appeler UNIQUEMENT quand l'utilisateur cherche un livre à OFFRIR à une personne précise (cadeau, anniversaire…). Récupère les lectures et notes publiques visibles de cet ami ReadOn afin de proposer des idées cadeaux personnalisées.",
    parameters: {
      type: "object",
      properties: {
        friend_name: {
          type: "string",
          description:
            "Prénom ou nom de l'ami, exactement tel que mentionné par l'utilisateur (ex: 'Alizée')",
        },
        count: {
          type: "integer",
          description: "Nombre d'idées cadeaux souhaité (1 à 5, défaut 3)",
        },
      },
      required: ["friend_name"],
    },
  },
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Appelle l'API OpenAI avec retry + backoff exponentiel sur les erreurs
// transitoires (429, 5xx, erreurs réseau). Retourne soit la réponse OK,
// soit une Response synthétique portant le dernier status pour le logging.
async function callOpenAIWithRetry(
  payload: unknown,
  apiKey: string,
  maxRetries = 3
): Promise<Response> {
  let lastStatus = 0;
  let lastBody = "";

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);
    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (res.ok) return res;

      lastStatus = res.status;
      lastBody = await res.text();
      console.error(
        `OpenAI error (attempt ${attempt + 1}/${maxRetries + 1}): status=${res.status} body=${lastBody}`
      );

      // Retry uniquement sur erreurs transitoires
      if (res.status === 429 || res.status >= 500) {
        if (attempt < maxRetries) {
          const retryAfter = Number(res.headers.get("retry-after"));
          const backoff =
            Number.isFinite(retryAfter) && retryAfter > 0
              ? retryAfter * 1000
              : Math.min(2 ** attempt * 500, 4000) + Math.random() * 250;
          await sleep(backoff);
          continue;
        }
      }
      // Erreur non-retryable (400/401/403...) — on abandonne
      break;
    } catch (e) {
      clearTimeout(timeout);
      lastStatus = -1;
      lastBody = String(e);
      console.error(
        `OpenAI fetch threw (attempt ${attempt + 1}/${maxRetries + 1}): ${lastBody}`
      );
      if (attempt < maxRetries) {
        await sleep(Math.min(2 ** attempt * 500, 4000) + Math.random() * 250);
        continue;
      }
    }
  }

  return new Response(lastBody || "OpenAI request failed", {
    status: lastStatus > 0 ? lastStatus : 502,
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

// ============================================================================
// Suggestion cadeau — résolution de l'ami + contexte visible
// (spec : SUGGESTION_CADEAU_SPEC.md — sémantique de get_friend_profile_v2)
// ============================================================================

// Normalisation insensible à la casse ET aux accents ("Alizée" → "alizee").
const normalizeName = (s: string) =>
  s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();

type FriendResolution =
  | { status: "ok"; friend: { id: string; display_name: string } }
  | { status: "ambiguous"; candidates: string[] }
  | { status: "not_found" };

// Résout un prénom en ami ACCEPTÉ de l'appelant, hors user_blocks.
// Ne révèle jamais l'existence d'un compte non-ami : bloqué / inexistant /
// non-ami renvoient tous "not_found".
async function resolveFriend(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  friendName: string
): Promise<FriendResolution> {
  const { data: rels } = await supabase
    .from("friends")
    .select("requester_id, addressee_id")
    .eq("status", "accepted")
    .or(`requester_id.eq.${userId},addressee_id.eq.${userId}`);

  const friendIds = [
    ...new Set(
      (rels ?? []).map((r: any) =>
        r.requester_id === userId ? r.addressee_id : r.requester_id
      )
    ),
  ];
  if (!friendIds.length) return { status: "not_found" };

  const { data: blocks } = await supabase
    .from("user_blocks")
    .select("blocker_id, blocked_id")
    .or(`blocker_id.eq.${userId},blocked_id.eq.${userId}`);

  const blocked = new Set<string>();
  for (const b of blocks ?? []) {
    blocked.add(b.blocker_id);
    blocked.add(b.blocked_id);
  }
  blocked.delete(userId);

  const visibleIds = friendIds.filter((id) => !blocked.has(id));
  if (!visibleIds.length) return { status: "not_found" };

  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, display_name")
    .in("id", visibleIds);

  const q = normalizeName(friendName);
  if (!q) return { status: "not_found" };

  const named = (profiles ?? []).filter((p: any) => p.display_name);

  // 1) match exact, 2) match sur un mot du display_name ("Alizée Dupont"),
  // 3) match préfixe ("Ali" → "Alizée")
  let matches = named.filter((p: any) => normalizeName(p.display_name) === q);
  if (!matches.length) {
    matches = named.filter((p: any) =>
      normalizeName(p.display_name).split(/\s+/).includes(q)
    );
  }
  if (!matches.length) {
    matches = named.filter((p: any) => normalizeName(p.display_name).startsWith(q));
  }

  if (matches.length === 1) {
    return {
      status: "ok",
      friend: { id: matches[0].id, display_name: matches[0].display_name },
    };
  }
  if (matches.length > 1) {
    return {
      status: "ambiguous",
      candidates: matches.slice(0, 10).map((p: any) => p.display_name),
    };
  }
  return { status: "not_found" };
}

// Construit le contexte cadeau : UNIQUEMENT ce que l'appelant peut déjà voir
// dans l'app (livres non cachés + notes publiques). La liste d'exclusion, en
// revanche, couvre TOUTE la bibliothèque (cachés et to_read inclus) — elle ne
// sert qu'en négatif et ne fuit rien.
// Retourne null si l'ami n'a aucune donnée visible.
async function buildGiftContext(
  supabase: ReturnType<typeof createClient>,
  friendId: string,
  friendDisplayName: string
): Promise<string | null> {
  const [{ data: allBooks }, { data: publicRatings }] = await Promise.all([
    supabase
      .from("user_books")
      .select(
        "id, book_id, status, is_hidden, updated_at, books(title, author, genre, description, page_count)"
      )
      .eq("user_id", friendId),
    supabase
      .from("book_ratings")
      .select(
        "user_book_id, book_id, rating, would_recommend, emotion_tags, review_text, abandoned"
      )
      .eq("user_id", friendId)
      .eq("is_public", true),
  ]);

  const books = allBooks ?? [];

  // Notes publiques rattachées à une lecture NON cachée uniquement.
  const hiddenByUserBookId: Record<string, boolean> = {};
  for (const b of books) hiddenByUserBookId[b.id] = b.is_hidden === true;
  const visibleRatings = (publicRatings ?? []).filter(
    (r: any) => hiddenByUserBookId[r.user_book_id] === false
  );
  const ratingMap: Record<string, any> = {};
  for (const r of visibleRatings) ratingMap[r.book_id] = r;

  const visible = books.filter(
    (b: any) =>
      b.is_hidden !== true &&
      ["finished", "reading", "abandoned"].includes(b.status) &&
      b.books
  );

  if (!visible.length && !visibleRatings.length) return null;

  const truncate = (text: string | null, maxLen: number): string => {
    if (!text) return "";
    return text.length > maxLen ? text.substring(0, maxLen) + "…" : text;
  };

  const byRecency = (a: any, b: any) =>
    new Date(b.updated_at ?? 0).getTime() - new Date(a.updated_at ?? 0).getTime();

  const finished = visible
    .filter((b: any) => b.status === "finished")
    .sort(byRecency)
    .slice(0, 30);
  const reading = visible.filter((b: any) => b.status === "reading");
  const abandonedList = visible.filter((b: any) => b.status === "abandoned");

  const formatBook = (b: any): string => {
    const book = b.books;
    let line = `- ${book.title}${book.author ? ` de ${book.author}` : ""}${book.genre ? ` (${book.genre})` : ""}`;
    if (book.page_count) line += ` [${book.page_count}p]`;
    const r = ratingMap[b.book_id];
    const signals: string[] = [];
    if (r?.rating != null) {
      signals.push(`noté ${r.rating}★${r.would_recommend ? ", recommandé" : ""}`);
      if (Array.isArray(r.emotion_tags) && r.emotion_tags.length) {
        signals.push(`ressenti: ${r.emotion_tags.join("/")}`);
      }
    }
    if (signals.length) line += ` → ${signals.join(", ")}`;
    const parts = [line];
    if (r?.review_text) parts.push(`  Son avis public : "${truncate(r.review_text, 100)}"`);
    if (book.description) parts.push(`  ${truncate(book.description, 120)}`);
    return parts.join("\n");
  };

  const formatSimple = (b: any): string => {
    const book = b.books;
    let line = `- ${book.title}${book.author ? ` de ${book.author}` : ""}${book.genre ? ` (${book.genre})` : ""}`;
    const r = ratingMap[b.book_id];
    if (r?.rating != null) line += ` (noté ${r.rating}★)`;
    return line;
  };

  // Livres qui ont déplu (note publique ≤ 2★ ou lecture abandonnée notée)
  const disliked = visible.filter((b: any) => {
    const r = ratingMap[b.book_id];
    return r && (r.rating <= 2 || r.abandoned === true);
  });

  // Agrégats calculés sur les livres visibles uniquement
  const genreCounts: Record<string, number> = {};
  const pageCounts: number[] = [];
  for (const b of visible) {
    if (b.books?.genre) genreCounts[b.books.genre] = (genreCounts[b.books.genre] || 0) + 1;
    if (b.books?.page_count > 0) pageCounts.push(b.books.page_count);
  }
  const topGenres = Object.entries(genreCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([g, c]) => `${g} (${c})`);
  const avgPages = pageCounts.length
    ? Math.round(pageCounts.reduce((a, b) => a + b, 0) / pageCounts.length)
    : null;

  // Liste d'exclusion : TOUTE la bibliothèque, tous statuts, cachés inclus.
  const exclusionSet = new Set<string>();
  for (const b of books) {
    if (!b.books?.title) continue;
    exclusionSet.add(
      `${b.books.title}${b.books.author ? ` de ${b.books.author}` : ""}`
    );
  }
  const exclusion = [...exclusionSet].slice(0, 200);

  let ctx = `Goûts de lecture de ${friendDisplayName} (uniquement les informations qu'il/elle partage avec ses amis) :\n\n`;
  if (topGenres.length) ctx += `Genres dominants : ${topGenres.join(", ")}\n`;
  if (avgPages) ctx += `Longueur moyenne des livres lus : ${avgPages} pages\n`;
  ctx += "\n";
  if (finished.length) {
    ctx += `Livres terminés (les notes ★ et ressentis sont ses évaluations publiques — signal n°1) :\n${finished.map(formatBook).join("\n")}\n\n`;
  }
  if (disliked.length) {
    ctx += `Livres qui lui ont DÉPLU (à éviter comme style) :\n${disliked.map(formatSimple).join("\n")}\n\n`;
  }
  if (reading.length) {
    ctx += `En cours de lecture :\n${reading.map(formatSimple).join("\n")}\n\n`;
  }
  if (abandonedList.length) {
    ctx += `Livres abandonnés (signal négatif) :\n${abandonedList.map(formatSimple).join("\n")}\n\n`;
  }
  if (exclusion.length) {
    ctx += `LIVRES À NE JAMAIS PROPOSER (déjà dans sa bibliothèque) :\n${exclusion.map((t) => `- ${t}`).join("\n")}\n`;
  }

  return ctx;
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
    const { conversation_id, message, is_new_conversation } = body;

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      return jsonResponse({ error: "Message requis" }, 400);
    }

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

    await supabase.from("ai_messages").insert({
      conversation_id: convId,
      role: "user",
      content: message.trim(),
    });

    const context = await buildUserContext(supabase, user.id);

    const { data: history } = await supabase
      .from("ai_messages")
      .select("role, content")
      .eq("conversation_id", convId)
      .order("created_at", { ascending: true })
      .limit(20);

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

    const openaiResponse = await callOpenAIWithRetry(
      {
        model: "gpt-4o-mini",
        messages,
        max_tokens: 1000,
        temperature: 0.3,
        tools: [GIFT_TOOL],
        tool_choice: "auto",
      },
      OPENAI_API_KEY
    );

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error(
        `OpenAI failed after retries: status=${openaiResponse.status} body=${error}`
      );
      return jsonResponse(
        { error: "Erreur du service IA", upstream_status: openaiResponse.status },
        502
      );
    }

    const openaiData = await openaiResponse.json();
    const firstChoice = openaiData.choices?.[0]?.message;
    let assistantMessage = firstChoice?.content ?? "";

    // ------------------------------------------------------------------
    // Tour d'outil : suggestion cadeau (au plus UN aller-retour, pas de boucle)
    // ------------------------------------------------------------------
    const toolCall = firstChoice?.tool_calls?.[0];
    if (toolCall?.function?.name === "suggest_gift_books") {
      let args: Record<string, unknown> = {};
      try {
        args = JSON.parse(toolCall.function.arguments ?? "{}");
      } catch (_) {
        // arguments illisibles → traité comme ami introuvable
      }
      const friendName =
        typeof args.friend_name === "string" ? args.friend_name.trim() : "";
      const count = Math.min(Math.max(Number(args.count) || 3, 1), 5);

      let toolResult: Record<string, unknown> | null = null;
      let giftGranted = false;
      let deterministicReply: string | null = null;

      if (!friendName) {
        toolResult = {
          status: "not_found",
          instructions:
            "Aucun prénom exploitable. Demande à l'utilisateur à qui il veut offrir un livre.",
        };
      } else {
        const resolved = await resolveFriend(supabase, user.id, friendName);

        if (resolved.status === "ambiguous") {
          toolResult = {
            status: "ambiguous",
            candidates: resolved.candidates,
            instructions:
              "Plusieurs amis correspondent à ce prénom. Liste-les et demande à l'utilisateur de préciser lequel.",
          };
        } else if (resolved.status === "not_found") {
          toolResult = {
            status: "not_found",
            friend_name: friendName,
            instructions:
              "Cette personne n'est pas dans les amis ReadOn de l'utilisateur (ne spécule pas sur l'existence d'un compte). Propose-lui de vérifier le prénom, ou de te décrire directement les goûts de la personne pour que tu suggères des idées cadeaux.",
          };
        } else {
          // Ami résolu → quota AVANT l'appel OpenAI final (pattern ai-suggest-books)
          let limitReached = false;
          if (!isPremium) {
            const startOfMonth = new Date();
            startOfMonth.setDate(1);
            startOfMonth.setHours(0, 0, 0, 0);
            const { count: usageCount } = await supabase
              .from("ai_usage")
              .select("id", { count: "exact", head: true })
              .eq("user_id", user.id)
              .eq("feature", "gift_suggest")
              .gte("used_at", startOfMonth.toISOString());
            limitReached =
              (usageCount ?? 0) >= MAX_FREE_MONTHLY_GIFT_SUGGESTIONS;
          }

          if (limitReached) {
            // Message Muse normal (pas d'erreur HTTP : on ne casse pas le fil),
            // déterministe → pas de second appel OpenAI.
            deterministicReply =
              `Tu as déjà utilisé tes ${MAX_FREE_MONTHLY_GIFT_SUGGESTIONS} suggestions cadeaux gratuites ce mois-ci 🎁 ` +
              "Passe premium pour des idées cadeaux illimitées ! En attendant, tu peux me décrire les goûts de la personne et je te donnerai des pistes générales.";
          } else {
            const giftContext = await buildGiftContext(
              supabase,
              resolved.friend.id,
              resolved.friend.display_name
            );
            if (!giftContext) {
              toolResult = {
                status: "no_visible_data",
                friend_name: resolved.friend.display_name,
                instructions:
                  "Cet ami n'a aucune lecture visible ni note publique. Explique-le gentiment ; suggère de lui demander de rendre ses notes publiques dans ReadOn, ou de décrire ses goûts directement.",
              };
            } else {
              giftGranted = true;
              toolResult = {
                status: "ok",
                friend_name: resolved.friend.display_name,
                count,
                context: giftContext,
                instructions:
                  `Propose exactement ${count} idées de livres à OFFRIR à ${resolved.friend.display_name}, en te basant UNIQUEMENT sur ce contexte. ` +
                  `Pour chaque idée : "Titre exact" de Auteur exact, puis une phrase chaleureuse expliquant le lien précis avec ses goûts (formulée comme un argument cadeau). ` +
                  "Ne propose JAMAIS un livre de la liste d'exclusion (il/elle l'a déjà). Ne propose que des livres qui existent réellement. " +
                  "Varie les auteurs. Termine par une phrase qui invite à demander d'autres idées si besoin.",
              };
            }
          }
        }
      }

      if (deterministicReply !== null) {
        assistantMessage = deterministicReply;
      } else if (toolResult) {
        const secondMessages = [
          ...messages,
          firstChoice,
          {
            role: "tool",
            tool_call_id: toolCall.id,
            content: JSON.stringify(toolResult),
          },
        ];

        // gpt-4o pour la qualité des recos finales (aligné sur ai-suggest-books)
        const secondResponse = await callOpenAIWithRetry(
          {
            model: giftGranted ? "gpt-4o" : "gpt-4o-mini",
            messages: secondMessages,
            max_tokens: 900,
            temperature: 0.5,
          },
          OPENAI_API_KEY
        );

        if (!secondResponse.ok) {
          const error = await secondResponse.text();
          console.error(
            `OpenAI (gift) failed after retries: status=${secondResponse.status} body=${error}`
          );
          return jsonResponse(
            { error: "Erreur du service IA", upstream_status: secondResponse.status },
            502
          );
        }

        const secondData = await secondResponse.json();
        assistantMessage = secondData.choices?.[0]?.message?.content ?? "";

        // Suggestion réellement servie → on consomme un crédit cadeau
        // (les tours ambiguous / not_found / no_visible_data ne comptent pas).
        if (giftGranted && assistantMessage) {
          await supabase.from("ai_usage").insert({
            user_id: user.id,
            feature: "gift_suggest",
          });
        }
      }
    }

    await supabase.from("ai_messages").insert({
      conversation_id: convId,
      role: "assistant",
      content: assistantMessage,
    });

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
