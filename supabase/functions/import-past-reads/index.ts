// Edge Function : import-past-reads
// Import en masse d'anciennes lectures depuis le web (CSV Goodreads/StoryGraph
// ou saisie rapide). Décisions produit (WEBAPP_SPEC.md) :
//   - livres passés → user_books (status finished/reading/to_read), JAMAIS de
//     reading_sessions (pas de spam feed, pas d'impact flamme/stats sessions) ;
//   - notes importées → book_ratings avec is_public = false : le trigger
//     sync_book_rated_activity ne crée AUCUNE activité pour les notes privées ;
//   - aucun trigger d'INSERT sur user_books → aucune activité feed créée ;
//   - matching côté serveur : ISBN → google_id → titre+auteur → Google Books
//     (clé API optionnelle GOOGLE_BOOKS_API_KEY côté serveur, jamais exposée) ;
//   - dédoublonnage books centralisé via l'unique books.google_id ;
//   - created_at/updated_at des user_books "finished" antidatés à la date de
//     lecture fournie (ou 31/12 de l'année) pour ne pas polluer les stats
//     "terminés cette année".
//
// verify_jwt = false MAIS l'auth est exigée dans le code (getUser sur le
// Bearer) — nécessaire pour que les préflights CORS du navigateur passent.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_KEY = Deno.env.get("GOOGLE_BOOKS_API_KEY") ?? "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ImportItem = {
  title?: string;
  author?: string;
  isbn?: string;
  status?: string; // finished | reading | to_read
  year_read?: number;
  date_read?: string; // YYYY-MM-DD
  rating?: number; // 0.5..5
  review?: string;
};

type ItemResult = {
  index: number;
  title: string;
  outcome: "imported" | "already_in_library" | "not_found" | "error";
  book_id?: number;
  matched_title?: string;
  rated?: boolean;
  detail?: string;
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function cleanIsbn(raw?: string): string | null {
  if (!raw) return null;
  const digits = raw.replace(/[^0-9Xx]/g, "");
  if (digits.length === 10 || digits.length === 13) return digits.toUpperCase();
  return null;
}

function normalizeStatus(s?: string): "finished" | "reading" | "to_read" {
  if (s === "reading") return "reading";
  if (s === "to_read") return "to_read";
  return "finished";
}

/** Échappe les caractères spéciaux PostgREST dans un pattern ilike. */
function likeEscape(s: string): string {
  return s.replace(/[%_,().]/g, (c) => "\\" + c).trim();
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

type GBook = {
  google_id: string;
  title: string;
  author: string | null;
  isbn: string | null;
  cover_url: string | null;
  page_count: number | null;
  published_date: string | null;
  publisher: string | null;
  language: string | null;
  genre: string | null;
  description: string | null;
};

async function searchGoogleBooks(item: ImportItem): Promise<GBook | null> {
  const isbn = cleanIsbn(item.isbn);
  const queries: string[] = [];
  if (isbn) queries.push(`isbn:${isbn}`);
  if (item.title) {
    const t = `intitle:${item.title}`;
    queries.push(item.author ? `${t}+inauthor:${item.author}` : t);
  }

  for (const q of queries) {
    const url =
      `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(q)}` +
      `&maxResults=3&printType=books${GOOGLE_KEY ? `&key=${GOOGLE_KEY}` : ""}`;
    try {
      const res = await fetch(url);
      if (res.status === 429) {
        await sleep(1200);
        continue;
      }
      if (!res.ok) continue;
      const data = await res.json();
      const vol = data?.items?.[0];
      if (!vol?.id || !vol?.volumeInfo?.title) continue;
      const info = vol.volumeInfo;
      const ids: { type: string; identifier: string }[] =
        info.industryIdentifiers ?? [];
      const isbn13 = ids.find((i) => i.type === "ISBN_13")?.identifier;
      const isbn10 = ids.find((i) => i.type === "ISBN_10")?.identifier;
      return {
        google_id: vol.id,
        title: info.title,
        author: Array.isArray(info.authors) ? info.authors.join(", ") : null,
        isbn: isbn13 ?? isbn10 ?? isbn ?? null,
        cover_url:
          info.imageLinks?.thumbnail?.replace(/^http:\/\//, "https://") ?? null,
        page_count: typeof info.pageCount === "number" ? info.pageCount : null,
        published_date: info.publishedDate ?? null,
        publisher: info.publisher ?? null,
        language: info.language ?? null,
        genre: Array.isArray(info.categories) ? info.categories[0] : null,
        description: info.description ?? null,
      };
    } catch {
      // réseau : on tente la requête suivante
    }
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  // ── Auth (obligatoire) ────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  const authClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: authError,
  } = await authClient.auth.getUser();
  if (authError || !user) return json(401, { error: "unauthorized" });

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  let body: { items?: ImportItem[] };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const items = Array.isArray(body.items) ? body.items.slice(0, 100) : [];
  if (!items.length) return json(400, { error: "no_items" });

  const results: ItemResult[] = [];
  let googleCalls = 0;

  for (let index = 0; index < items.length; index++) {
    const item = items[index];
    const title = (item.title ?? "").trim();
    try {
      if (!title && !cleanIsbn(item.isbn)) {
        results.push({ index, title, outcome: "error", detail: "empty" });
        continue;
      }

      // ── 1. Matching local : ISBN → titre+auteur ──────────────────
      let bookId: number | null = null;
      let matchedTitle: string | null = null;

      const isbn = cleanIsbn(item.isbn);
      if (isbn) {
        const { data } = await admin
          .from("books")
          .select("id, title")
          .eq("isbn", isbn)
          .limit(1);
        if (data?.[0]) {
          bookId = data[0].id;
          matchedTitle = data[0].title;
        }
      }
      if (!bookId && title) {
        let q = admin
          .from("books")
          .select("id, title, author")
          .ilike("title", likeEscape(title))
          .limit(3);
        if (item.author?.trim()) {
          // dernier mot du nom d'auteur : tolérant aux "Prénom Nom" vs "Nom, Prénom"
          const lastWord = item.author.trim().split(/\s+/).pop()!;
          q = q.ilike("author", `%${likeEscape(lastWord)}%`);
        }
        const { data } = await q;
        if (data?.[0]) {
          bookId = data[0].id;
          matchedTitle = data[0].title;
        }
      }

      // ── 2. Google Books si aucun match local ─────────────────────
      if (!bookId) {
        googleCalls++;
        if (googleCalls > 1) await sleep(200); // rate limiting doux
        const gb = await searchGoogleBooks(item);
        if (!gb) {
          results.push({ index, title, outcome: "not_found" });
          continue;
        }
        // Dédoublonnage centralisé sur books.google_id (unique)
        const { data: upserted, error: upsertError } = await admin
          .from("books")
          .upsert(
            {
              google_id: gb.google_id,
              title: gb.title,
              author: gb.author,
              isbn: gb.isbn,
              cover_url: gb.cover_url,
              page_count: gb.page_count,
              published_date: gb.published_date,
              publisher: gb.publisher,
              language: gb.language,
              genre: gb.genre,
              description: gb.description,
              source: "google_books",
            },
            { onConflict: "google_id" },
          )
          .select("id, title")
          .single();
        if (upsertError || !upserted) {
          results.push({
            index,
            title,
            outcome: "error",
            detail: upsertError?.message,
          });
          continue;
        }
        bookId = upserted.id;
        matchedTitle = upserted.title;
      }

      // ── 3. user_books (sans sessions, sans activité feed) ────────
      const status = normalizeStatus(item.status);
      let finishedAt: string | null = null;
      if (status === "finished") {
        if (item.date_read && /^\d{4}-\d{2}-\d{2}$/.test(item.date_read)) {
          finishedAt = `${item.date_read}T12:00:00Z`;
        } else if (
          item.year_read &&
          item.year_read >= 1900 &&
          item.year_read <= new Date().getFullYear()
        ) {
          finishedAt = `${item.year_read}-12-31T12:00:00Z`;
        }
      }

      const { data: inserted, error: ubError } = await admin
        .from("user_books")
        .insert({
          user_id: user.id,
          book_id: bookId,
          status,
          current_page: 0,
          ...(finishedAt
            ? { created_at: finishedAt, updated_at: finishedAt }
            : {}),
        })
        .select("id")
        .single();

      let userBookId: number;
      let alreadyThere = false;
      if (ubError) {
        if (ubError.code === "23505") {
          // Déjà dans la bibliothèque : on n'écrase rien
          alreadyThere = true;
          const { data: existing } = await admin
            .from("user_books")
            .select("id")
            .eq("user_id", user.id)
            .eq("book_id", bookId)
            .single();
          userBookId = existing!.id;
        } else {
          results.push({
            index,
            title,
            outcome: "error",
            detail: ubError.message,
          });
          continue;
        }
      } else {
        userBookId = inserted!.id;
      }

      // ── 4. Note éventuelle — PRIVÉE (is_public=false → pas de feed)
      let rated = false;
      if (
        !alreadyThere &&
        status === "finished" &&
        typeof item.rating === "number" &&
        item.rating >= 0.5 &&
        item.rating <= 5
      ) {
        const { error: ratingError } = await admin.from("book_ratings").insert({
          user_id: user.id,
          book_id: bookId,
          user_book_id: userBookId,
          rating: item.rating,
          review_text: item.review?.trim() ? item.review.trim().slice(0, 2000) : null,
          is_public: false,
          ...(finishedAt
            ? { created_at: finishedAt, updated_at: finishedAt }
            : {}),
        });
        rated = !ratingError;
      }

      results.push({
        index,
        title,
        outcome: alreadyThere ? "already_in_library" : "imported",
        book_id: bookId,
        matched_title: matchedTitle ?? undefined,
        rated,
      });
    } catch (e) {
      results.push({
        index,
        title,
        outcome: "error",
        detail: e instanceof Error ? e.message : String(e),
      });
    }
  }

  const summary = {
    imported: results.filter((r) => r.outcome === "imported").length,
    already_in_library: results.filter(
      (r) => r.outcome === "already_in_library",
    ).length,
    not_found: results.filter((r) => r.outcome === "not_found").length,
    errors: results.filter((r) => r.outcome === "error").length,
  };

  return json(200, { summary, results });
});
