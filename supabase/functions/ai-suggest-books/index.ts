import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
// Optionnel : clé Google Books (quota plus large). Sans clé, on tente quand même
// et on retombe sur Open Library ; en cas d'indisponibilité, on ne bloque rien.
const GOOGLE_BOOKS_API_KEY = Deno.env.get("GOOGLE_BOOKS_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
  throw new Error("Missing SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Chaque GÉNÉRATION déclenche une requête gpt-4o (coûteuse). On plafonne les
// utilisateurs gratuits comme pour ai-chat / summarize-passage. Premium =
// illimité. Suivi via la table `ai_usage` (feature = "suggest_books").
// Depuis le 28/10/2026 : seules les générations réelles comptent. Le feed
// appelle cette fonction à chaque chargement ; les réponses servies depuis le
// cache (ai_reco_cache, 24 h) ne consomment ni quota ni appel OpenAI.
const MAX_FREE_MONTHLY_SUGGESTIONS = 5;
const CACHE_TTL_MS = 24 * 3600 * 1000;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const LANG_NAMES: Record<string, string> = {
  fr: "français",
  en: "anglais",
  es: "espagnol",
};

const SYSTEM_PROMPT = `Tu es un moteur de recommandation de livres ultra-pertinent. On te donne le profil de lecture complet d'un utilisateur avec des signaux d'engagement.

STRATÉGIE :
1. Identifie le PROFIL : fiction vs non-fiction, thèmes dominants, complexité, langue préférée.
2. Respecte le profil : si le lecteur est principalement non-fiction/business, recommande dans cette catégorie. Ne propose pas de romans à un lecteur 100% non-fiction.
3. Priorise la RÉCENCE : les 5 derniers livres terminés pèsent 3x plus. Recommande dans la continuité thématique des lectures récentes.
4. Les NOTES utilisateur (0.5 à 5★) sont le signal de préférence LE PLUS FIABLE : livres notés ≥ 4★ (surtout \"recommandé\") = adorés → recommande dans la même veine. Livres notés ≤ 2★ = déplu → évite absolument ce style. Les tags de ressenti (moving, funny, gripping, comforting…) décrivent l'expérience émotionnelle recherchée par le lecteur.
5. Utilise les SIGNAUX D'ENGAGEMENT : livres annotés ou lus rapidement = forte appréciation → recommande dans la même veine. Livres abandonnés = signal négatif → évite ce style.
6. Adapte la longueur : respecte la longueur moyenne des livres lus par l'utilisateur.
7. Analyse les DESCRIPTIONS des livres lus pour comprendre les thèmes précis, pas juste le genre.
8. Si le profil est encore PEU RENSEIGNÉ (peu de livres terminés), appuie-toi sur la liste « à lire » et les lectures en cours pour deviner les goûts, et privilégie des livres très appréciés et accessibles dans ces genres plutôt que des choix pointus.

RÈGLES :
- Recommande exactement le nombre de livres demandé.
- Ne recommande JAMAIS un livre présent dans la bibliothèque de l'utilisateur (lu, en cours, abandonné, à lire, ou dans la liste « BIBLIOTHÈQUE COMPLÈTE »).
- Ne recommande QUE des livres qui existent réellement. N'invente rien. Si tu hésites sur l'existence d'un livre, choisis-en un autre.
- Varie les auteurs dans tes suggestions (un seul livre par auteur).
- Réponds UNIQUEMENT avec un JSON valide, sans texte autour.

FORMAT DE RÉPONSE (JSON uniquement) :
[
  {
    "title": "Titre exact du livre",
    "author": "Auteur exact",
    "reason": "Courte explication (1 phrase) du lien PRÉCIS avec les lectures de l'utilisateur"
  }
]`;

// Normalisation insensible à la casse, aux accents et à la ponctuation.
const norm = (s: unknown): string =>
  String(s ?? "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

type Suggestion = { title: string; author: string; reason: string };

// Retire les suggestions déjà dans la bibliothèque (tous statuts, cachés inclus).
function filterOwned(
  suggestions: Suggestion[],
  ownedTitles: Set<string>,
): Suggestion[] {
  return suggestions.filter((s) => !ownedTitles.has(norm(s.title)));
}

// Un seul livre par auteur, ordre conservé.
function onePerAuthor(suggestions: Suggestion[]): Suggestion[] {
  const seen = new Set<string>();
  return suggestions.filter((s) => {
    const a = norm(s.author);
    if (!a) return true;
    if (seen.has(a)) return false;
    seen.add(a);
    return true;
  });
}

// ============================================================================
// Garde-fou anti-hallucination : chaque suggestion est vérifiée sur Google Books
// puis Open Library. « Fail-open » : si les deux services sont injoignables, la
// suggestion est conservée (on ne bloque jamais les recos à cause d'un tiers).
// ============================================================================

type BookCheck = "valid" | "invalid" | "unknown";

const normTitle = (s: string) =>
  norm(s).replace(/^(le|la|les|l|un|une|the|a|an|el|los|las) /, "");

function titlesMatch(claimed: string, candidate: string): boolean {
  const a = normTitle(claimed);
  const b = normTitle(candidate);
  if (!a || !b) return false;
  if (a === b) return true;
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  return short.length >= 8 && long.includes(short);
}

function authorTokens(author: string): string[] {
  return String(author ?? "")
    .split(/\s+/)
    .map(norm)
    .filter((t) => t.length > 2);
}

function authorMatches(claimedAuthor: string, candidateAuthors: string[]): boolean {
  const tokens = authorTokens(claimedAuthor);
  if (!tokens.length) return true; // rien d'exploitable → on ne tranche pas sur l'auteur
  const hay = norm((candidateAuthors ?? []).join(" "));
  return tokens.some((t) => hay.includes(t));
}

async function fetchJson(url: string, timeoutMs = 4000): Promise<any | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function checkGoogleBooks(s: Suggestion): Promise<BookCheck> {
  const lastName = authorTokens(s.author).pop() ?? s.author;
  const q = `intitle:"${s.title}" inauthor:"${lastName}"`;
  let url =
    `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(q)}` +
    `&maxResults=10&printType=books`;
  if (GOOGLE_BOOKS_API_KEY) url += `&key=${GOOGLE_BOOKS_API_KEY}`;
  const data = await fetchJson(url);
  if (!data) return "unknown";
  for (const it of data.items ?? []) {
    const v = it.volumeInfo;
    if (v && titlesMatch(s.title, v.title ?? "") && authorMatches(s.author, v.authors ?? [])) {
      return "valid";
    }
  }
  return "invalid";
}

async function checkOpenLibrary(s: Suggestion): Promise<BookCheck> {
  const url =
    `https://openlibrary.org/search.json?title=${encodeURIComponent(s.title)}` +
    `&limit=15&fields=title,author_name`;
  const data = await fetchJson(url, 5000);
  if (!data) return "unknown";
  for (const d of data.docs ?? []) {
    if (titlesMatch(s.title, d.title ?? "") && authorMatches(s.author, d.author_name ?? [])) {
      return "valid";
    }
  }
  return "invalid";
}

async function verifySuggestion(s: Suggestion): Promise<BookCheck> {
  try {
    const g = await checkGoogleBooks(s);
    if (g === "valid") return "valid";
    const o = await checkOpenLibrary(s);
    if (o === "valid") return "valid";
    if (g === "invalid" && o === "invalid") return "invalid";
    return "unknown"; // au moins une source injoignable → on ne sanctionne pas
  } catch (_) {
    return "unknown";
  }
}

async function callOpenAI(payload: unknown): Promise<Response> {
  let last: Response | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);
    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (res.ok || (res.status !== 429 && res.status < 500)) return res;
      last = res;
    } catch (e) {
      clearTimeout(timeout);
      console.error("OpenAI fetch threw:", String(e));
    }
    await new Promise((r) => setTimeout(r, 700));
  }
  return last ?? new Response("OpenAI request failed", { status: 502 });
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
    const limit = Math.min(Math.max(Number(body.limit) || 5, 1), 10);
    const localeRaw = String(body.locale ?? "fr").toLowerCase().slice(0, 2);
    const locale = LANG_NAMES[localeRaw] ? localeRaw : "fr";
    const forceRefresh = body.refresh === true;

    // --- Premium check ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium === true;

    // --- Bibliothèque complète (exclusion) : tous statuts, cachés inclus ---
    const { data: ownedRows } = await supabase
      .from("user_books")
      .select("books(title)")
      .eq("user_id", user.id)
      .limit(500);
    const ownedTitles = new Set<string>(
      (ownedRows ?? [])
        .map((r: any) => norm(r.books?.title))
        .filter((t: string) => t.length > 0),
    );

    // --- Cache 24 h : pas d'appel OpenAI, pas de quota consommé ---
    const { data: cache } = await supabase
      .from("ai_reco_cache")
      .select("suggestions, locale, limit_count, generated_at")
      .eq("user_id", user.id)
      .maybeSingle();

    const cachedList: Suggestion[] = Array.isArray(cache?.suggestions)
      ? (cache!.suggestions as Suggestion[])
      : [];
    const cachedFiltered = filterOwned(cachedList, ownedTitles).slice(0, limit);

    if (cache && !forceRefresh) {
      const age = Date.now() - new Date(cache.generated_at).getTime();
      let fresh = age < CACHE_TTL_MS && cache.locale === locale;

      // Un livre terminé depuis la génération change le profil → on régénère.
      if (fresh) {
        const { data: lastFinished } = await supabase
          .from("user_books")
          .select("updated_at")
          .eq("user_id", user.id)
          .eq("status", "finished")
          .order("updated_at", { ascending: false })
          .limit(1);
        const lf = lastFinished?.[0]?.updated_at;
        if (lf && new Date(lf).getTime() > new Date(cache.generated_at).getTime()) {
          fresh = false;
        }
      }
      // Cache épuisé par les ajouts de l'utilisateur (≥ moitié filtrée) → régénère.
      if (fresh && cachedFiltered.length < Math.min(limit, 3)) fresh = false;

      if (fresh) {
        return jsonResponse({ suggestions: cachedFiltered, cached: true });
      }
    }

    // --- Quota mensuel (uniquement pour une vraie génération) ---
    if (!isPremium) {
      const startOfMonth = new Date();
      startOfMonth.setDate(1);
      startOfMonth.setHours(0, 0, 0, 0);

      const { count: usageCount } = await supabase
        .from("ai_usage")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("feature", "suggest_books")
        .gte("used_at", startOfMonth.toISOString());

      if ((usageCount ?? 0) >= MAX_FREE_MONTHLY_SUGGESTIONS) {
        // Quota atteint : on sert les dernières recos connues (filtrées) plutôt
        // que rien, et on signale `limited` pour que l'app propose le premium.
        if (cachedFiltered.length > 0) {
          return jsonResponse({
            suggestions: cachedFiltered,
            cached: true,
            limited: true,
          });
        }
        return jsonResponse(
          {
            error: "limit_reached",
            message:
              "Tu as atteint la limite de suggestions ce mois-ci. Passe premium pour des recommandations illimitées !",
          },
          429,
        );
      }
    }

    // Fetch all data in parallel
    const [
      { data: finished },
      { data: reading },
      { data: toRead },
      { data: sessions },
      { data: annotationCounts },
      { data: ratings },
      { data: abandonedBooks },
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
        .order("created_at", { ascending: false })
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
      supabase
        .from("book_ratings")
        .select("book_id, rating, emotion_tags, review_text, would_recommend, abandoned, abandoned_at_percent")
        .eq("user_id", user.id),
      supabase
        .from("user_books")
        .select("book_id, books(title, author, genre)")
        .eq("user_id", user.id)
        .eq("status", "abandoned")
        .limit(20),
    ]);

    // Build annotation count map
    const annotationMap: Record<string, number> = {};
    for (const a of annotationCounts ?? []) {
      annotationMap[a.book_id] = (annotationMap[a.book_id] || 0) + 1;
    }

    // Build rating map (une note par lecture ; on garde la plus récente = dernière ligne)
    const ratingMap: Record<string, any> = {};
    for (const r of ratings ?? []) {
      ratingMap[r.book_id] = r;
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

    // Detect abandoned books (heuristique : livres 'reading' sans session récente)
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
          const rating = ratingMap[b.book_id];
          const signals: string[] = [];
          if (rating?.rating != null) {
            signals.push(`noté ${rating.rating}★${rating.would_recommend ? ", recommandé" : ""}`);
            if (Array.isArray(rating.emotion_tags) && rating.emotion_tags.length) {
              signals.push(`ressenti: ${rating.emotion_tags.join("/")}`);
            }
          }
          if (annotations > 0) signals.push(`${annotations} annotations`);
          if (pace && pace.totalDays > 0) {
            const pagesPerDay = Math.round(pace.totalPages / pace.totalDays);
            if (pagesPerDay > 100) signals.push("lu rapidement");
            else if (pagesPerDay < 20 && pace.totalDays > 14) signals.push("lu lentement");
          }
          if (signals.length) parts[0] += ` → ${signals.join(", ")}`;
          if (rating?.review_text) parts.push(`  Avis du lecteur : \"${truncate(rating.review_text, 100)}\"`);
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

    // Livres explicitement abandonnés (statut 'abandoned'), avec note éventuelle
    const formatAbandonedBooks = (books: any[]) =>
      (books ?? [])
        .map((b: any) => {
          const book = b.books;
          if (!book) return null;
          let line = `- ${book.title}${book.author ? ` de ${book.author}` : ""}${book.genre ? ` (${book.genre})` : ""}`;
          const r = ratingMap[b.book_id];
          if (r) {
            const details: string[] = [];
            if (r.rating != null) details.push(`noté ${r.rating}★`);
            if (r.abandoned_at_percent != null) details.push(`arrêté à ${r.abandoned_at_percent}%`);
            if (details.length) line += ` → ${details.join(", ")}`;
          }
          return line;
        })
        .filter(Boolean)
        .join("\n");

    // Analyse des patterns
    const allBooks = [...(finished ?? []), ...(reading ?? [])];
    const genreCounts: Record<string, number> = {};
    const fictionGenres = new Set(["fiction", "roman", "fantasy", "science-fiction", "sf", "thriller", "policier", "romance", "horreur", "aventure", "literary fiction", "mystery", "comics", "manga", "bd", "poésie", "jeunesse", "young adult"]);
    let fictionCount = 0, nonFictionCount = 0;
    // Démarrage à froid : 60 % des utilisateurs de la fonction n'ont aucun livre
    // terminé. On compte alors aussi la liste « à lire » pour deviner les genres.
    const profileBooks = (finished?.length ?? 0) >= 3
      ? allBooks
      : [...allBooks, ...(toRead ?? [])];
    for (const b of profileBooks) {
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

    // Livres mal notés (≤ 2★) ou lectures abandonnées avec note → signal négatif fort
    const badlyRated = (finished ?? []).filter((b: any) => {
      const r = ratingMap[b.book_id];
      return r && (r.rating <= 2 || r.abandoned === true);
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
    if ((finished?.length ?? 0) < 3) {
      profileParts.push(
        `Profil encore peu renseigné (${finished?.length ?? 0} livre(s) terminé(s)) : déduis les goûts de la liste « à lire » et des lectures en cours.`,
      );
    }
    if (avgPages) profileParts.push(`Longueur moyenne : ${avgPages} pages`);
    if (profileParts.length) userContext += profileParts.join("\n") + "\n\n";

    if (topGenres.length) userContext += `Genres préférés : ${topGenres.join(", ")}\n\n`;
    if (finished?.length) userContext += `Livres terminés (${finished.length}):\n${formatFinishedBooks(finished)}\n\n`;
    if (badlyRated.length) {
      const lines = badlyRated
        .map((b: any) => {
          const r = ratingMap[b.book_id];
          return `- ${b.books?.title ?? "?"}${b.books?.author ? ` de ${b.books.author}` : ""} (noté ${r.rating}★${r.abandoned ? ", abandonné" : ""})`;
        })
        .join("\n");
      userContext += `Livres qui ont DÉPLU (à éviter comme style) :\n${lines}\n\n`;
    }
    if (reading?.length) userContext += `En cours de lecture :\n${formatSimpleBooks(reading)}\n\n`;
    const abandonedExplicit = formatAbandonedBooks(abandonedBooks ?? []);
    const abandonedHeuristic = formatSimpleBooks(abandoned);
    const abandonedAll = [abandonedExplicit, abandonedHeuristic].filter((s) => s).join("\n");
    if (abandonedAll) userContext += `Livres abandonnés (signal négatif, NE PAS recommander) :\n${abandonedAll}\n\n`;
    if (toRead?.length) userContext += `Liste à lire (NE PAS recommander) :\n${formatSimpleBooks(toRead)}\n\n`;

    if (!userContext.trim()) {
      // Bibliothèque vide : rien à personnaliser, on n'appelle pas gpt-4o.
      return jsonResponse({ suggestions: [] });
    }

    // Bibliothèque complète (titres seuls) : couvre ce que les sections
    // ci-dessus tronquent (30 terminés, 20 à lire/abandonnés) + les livres cachés.
    const ownedList = [...(ownedRows ?? [])]
      .map((r: any) => r.books?.title)
      .filter((t: unknown): t is string => typeof t === "string" && t.length > 0)
      .slice(0, 300);
    if (ownedList.length) {
      userContext += `BIBLIOTHÈQUE COMPLÈTE (NE JAMAIS recommander ces titres) :\n${ownedList.map((t) => `- ${t}`).join("\n")}\n`;
    }

    // On demande 2 livres de plus que nécessaire : certains seront retirés
    // par le filtre « déjà dans la bibliothèque » ou « un auteur à la fois ».
    const requested = Math.min(limit + 2, 12);
    const langName = LANG_NAMES[locale];
    const localeRule =
      locale === "fr"
        ? `Rédige le champ "reason" en français. Pour un lecteur francophone, donne le titre français officiel si le livre a été traduit.`
        : `Rédige le champ "reason" en ${langName}. Donne le titre dans la langue de l'utilisateur s'il existe une édition officielle, sinon le titre original.`;

    const openaiResponse = await callOpenAI({
      model: "gpt-4o",
      messages: [
        { role: "system", content: `${SYSTEM_PROMPT}\n\n${localeRule}` },
        {
          role: "user",
          content: `Recommande ${requested} livres pour cet utilisateur.\n\n${userContext}`,
        },
      ],
      max_tokens: 1000,
      temperature: 0.5,
    });

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error("OpenAI error:", openaiResponse.status, error);
      // Panne OpenAI : on retombe sur le cache plutôt que de ne rien afficher.
      if (cachedFiltered.length > 0) {
        return jsonResponse({ suggestions: cachedFiltered, cached: true });
      }
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

    // Valider la structure, retirer ce que l'utilisateur possède déjà, un auteur à la fois
    const candidates: Suggestion[] = onePerAuthor(
      filterOwned(
        suggestions
          .filter(
            (s: any) =>
              typeof s.title === "string" &&
              typeof s.author === "string" &&
              s.title.length > 0,
          )
          .map((s: any) => ({
            title: s.title,
            author: s.author,
            reason: typeof s.reason === "string" ? s.reason : "",
          })),
        ownedTitles,
      ),
    );

    // Garde-fou anti-hallucination : on retire les livres introuvables dans
    // Google Books / Open Library (les « unknown » sont conservés).
    const checks = await Promise.all(candidates.map(verifySuggestion));
    const rejected = candidates.filter((_, i) => checks[i] === "invalid");
    if (rejected.length) {
      console.warn(
        `ai-suggest-books: livres non vérifiés retirés → ${rejected.map((s) => `"${s.title}" / ${s.author}`).join(" | ")}`,
      );
    }
    const validated: Suggestion[] = candidates
      .filter((_, i) => checks[i] !== "invalid")
      .slice(0, limit);

    // Quota et cache : uniquement si la génération a produit quelque chose.
    if (validated.length > 0) {
      await supabase.from("ai_usage").insert({
        user_id: user.id,
        feature: "suggest_books",
      });
      await supabase.from("ai_reco_cache").upsert({
        user_id: user.id,
        suggestions: validated,
        locale,
        limit_count: limit,
        generated_at: new Date().toISOString(),
      });
    }

    return jsonResponse({ suggestions: validated, cached: false });
  } catch (error) {
    console.error("ai-suggest-books error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
