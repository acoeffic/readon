// Supabase Edge Function — Nightly book cover refresh.
// Called by pg_cron once a day. Iterates over books with missing or
// low-quality covers and tries multiple sources:
//   1. Google Books API (by ISBN, then by title+author)
//   2. Open Library (by ISBN, with placeholder detection)
//   3. BnF / Bibliothèque nationale de France (by ISBN — excellent for French books)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_BOOKS_API_KEY = Deno.env.get("GOOGLE_BOOKS_API_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ── Helpers ─────────────────────────────────────────────────────

/** Minimum bytes for a Google Books cover to be considered real (not placeholder). */
const MIN_GB_BYTES = 8_000;
/** Minimum bytes for an Open Library cover (placeholder is ~800 B). */
const MIN_OL_BYTES = 1_500;
/** Minimum bytes for a BnF cover. */
const MIN_BNF_BYTES = 2_000;

/** HEAD-check a URL and return true only if response is ≥ minBytes. */
async function isRealCover(url: string, minBytes: number): Promise<boolean> {
  try {
    const resp = await fetch(url, { method: "HEAD", redirect: "follow" });
    if (!resp.ok) return false;
    const len = parseInt(resp.headers.get("content-length") ?? "0", 10);
    if (len >= minBytes) return true;
    if (len > 0 && len < minBytes) return false;
    // content-length missing — do a full GET to measure
    const getResp = await fetch(url);
    if (!getResp.ok) return false;
    const body = await getResp.arrayBuffer();
    return body.byteLength >= minBytes;
  } catch {
    return false;
  }
}

// ── Source 1: Google Books API ───────────────────────────────────

async function fetchGoogleBooksCover(
  isbn: string | null,
  title: string,
  author: string | null,
): Promise<string | null> {
  const apiKeySuffix = GOOGLE_BOOKS_API_KEY
    ? `&key=${GOOGLE_BOOKS_API_KEY}`
    : "";

  // Strategy A: search by ISBN (most reliable)
  if (isbn) {
    const url = await _searchGoogleBooks(
      `isbn:${isbn}`,
      apiKeySuffix,
    );
    if (url) return url;
  }

  // Strategy B: search by title + author
  const cleanTitle = cleanBookTitle(title);
  const query = author
    ? `intitle:${cleanTitle}+inauthor:${author}`
    : `intitle:${cleanTitle}`;
  return _searchGoogleBooks(query, apiKeySuffix);
}

async function _searchGoogleBooks(
  query: string,
  apiKeySuffix: string,
): Promise<string | null> {
  try {
    const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=3${apiKeySuffix}`;
    const resp = await fetch(url);
    if (!resp.ok) return null;
    const data = await resp.json();
    const items = data.items as Array<Record<string, unknown>> | undefined;
    if (!items?.length) return null;

    for (const item of items) {
      const volumeInfo = item.volumeInfo as Record<string, unknown> | undefined;
      if (!volumeInfo) continue;
      const imageLinks = volumeInfo.imageLinks as Record<string, string> | undefined;
      if (!imageLinks) continue;
      const coverUrl =
        imageLinks.extraLarge ??
        imageLinks.large ??
        imageLinks.medium ??
        imageLinks.small ??
        imageLinks.thumbnail;
      if (!coverUrl) continue;

      const secureUrl = coverUrl.replace(/^http:/, "https:");

      // HEAD-check to filter out gray placeholders
      if (await isRealCover(secureUrl, MIN_GB_BYTES)) {
        return secureUrl;
      }

      // Try publisher-content endpoint as fallback
      const volumeId = (item.id as string) ?? "";
      if (volumeId) {
        const pubUrl = `https://books.google.com/books/publisher/content/images/frontcover/${volumeId}?fife=w400-h600&source=gbs_api`;
        if (await isRealCover(pubUrl, 5_000)) {
          return pubUrl;
        }
      }
    }
    return null;
  } catch {
    return null;
  }
}

// ── Source 2: Open Library ───────────────────────────────────────

async function fetchOpenLibraryCover(isbn: string): Promise<string | null> {
  try {
    const cleanIsbn = isbn.replace(/[\s-]/g, "");
    const url = `https://covers.openlibrary.org/b/isbn/${cleanIsbn}-L.jpg?default=false`;
    if (await isRealCover(url, MIN_OL_BYTES)) {
      return url;
    }
    return null;
  } catch {
    return null;
  }
}

// ── Source 3: BnF (Bibliothèque nationale de France) ────────────

async function fetchBnfCover(isbn: string): Promise<string | null> {
  try {
    const cleanIsbn = isbn.replace(/[\s-]/g, "");
    const sruUrl =
      `https://catalogue.bnf.fr/api/SRU?version=1.2` +
      `&operation=searchRetrieve` +
      `&query=bib.isbn%20adj%20%22${cleanIsbn}%22` +
      `&maximumRecords=1`;
    const resp = await fetch(sruUrl);
    if (!resp.ok) return null;
    const xml = await resp.text();

    // Extract ARK identifier from MARC-XML response
    const arkMatch = xml.match(/ark:\/12148\/cb\d+[a-z]?/);
    if (!arkMatch) return null;

    const coverUrl = `https://catalogue.bnf.fr/couverture?&appName=NE&idArk=${arkMatch[0]}&couession=1`;
    if (await isRealCover(coverUrl, MIN_BNF_BYTES)) {
      return coverUrl;
    }
    return null;
  } catch {
    return null;
  }
}

// ── Source 4: iTunes / Apple Books ──────────────────────────────

async function fetchItunesCover(
  isbn: string | null,
  title: string,
  author: string | null,
): Promise<string | null> {
  // Try by ISBN first
  if (isbn) {
    for (const country of ["fr", "us"]) {
      try {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(isbn)}&media=ebook&limit=1&country=${country}`;
        const resp = await fetch(url);
        if (!resp.ok) continue;
        const data = await resp.json();
        const results = data.results as Array<Record<string, string>> | undefined;
        if (results?.length) {
          const artwork = results[0].artworkUrl100;
          if (artwork) {
            return artwork.replace("100x100bb", "600x600bb");
          }
        }
      } catch { /* try next */ }
    }
  }

  // Try by title + author
  if (title) {
    const query = `${title} ${author ?? ""}`.trim();
    for (const country of ["fr", "us"]) {
      try {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=ebook&limit=3&country=${country}`;
        const resp = await fetch(url);
        if (!resp.ok) continue;
        const data = await resp.json();
        const results = data.results as Array<Record<string, string>> | undefined;
        if (!results?.length) continue;

        // Find best match by title similarity
        const normalizedTitle = normalize(title);
        for (const r of results) {
          const trackName = r.trackName ?? r.collectionName ?? "";
          if (jaccardSimilarity(normalizedTitle, normalize(trackName)) > 0.4) {
            const artwork = r.artworkUrl100;
            if (artwork) {
              return artwork.replace("100x100bb", "600x600bb");
            }
          }
        }
      } catch { /* try next */ }
    }
  }

  return null;
}

// ── Title cleaning ──────────────────────────────────────────────

function cleanBookTitle(title: string): string {
  return title
    .replace(/\s*\(French Edition\)\s*/gi, "")
    .replace(/\s*\(Kindle Edition\)\s*/gi, "")
    .replace(/\s*\(Edition française\)\s*/gi, "")
    .replace(/\s*\(édition française\)\s*/gi, "")
    .replace(/\s*\(English Edition\)\s*/gi, "")
    .replace(
      /\s*:\s*(récit|roman|essai|nouvelles?|témoignage|document|enquête|chronique|mémoires?)\s*$/i,
      "",
    )
    .trim();
}

function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[\s\-–—:,;.!?'"«»()]+/g, " ")
    .replace(/[éèêë]/g, "e")
    .replace(/[àâä]/g, "a")
    .replace(/[ùûü]/g, "u")
    .replace(/[ôö]/g, "o")
    .replace(/[îï]/g, "i")
    .replace(/ç/g, "c")
    .replace(/œ/g, "oe")
    .replace(/æ/g, "ae")
    .trim();
}

function jaccardSimilarity(a: string, b: string): number {
  const wordsA = new Set(a.split(/\s+/).filter((w) => w.length > 1));
  const wordsB = new Set(b.split(/\s+/).filter((w) => w.length > 1));
  if (wordsA.size === 0 || wordsB.size === 0) return a === b ? 1 : 0;
  let common = 0;
  for (const w of wordsA) if (wordsB.has(w)) common++;
  const union = new Set([...wordsA, ...wordsB]).size;
  return common / union;
}

function isValidIsbn(isbn: string | null): boolean {
  if (!isbn) return false;
  const clean = isbn.replace(/[\s-]/g, "");
  return /^\d{10}$|^\d{13}$/.test(clean);
}

// ── Main handler ────────────────────────────────────────────────

serve(async (_req: Request) => {
  try {
    // Fetch books with missing or low-quality covers.
    // We process ALL books (not just user-specific) since this is a global job.
    const { data: books, error } = await supabase
      .from("books")
      .select("id, title, author, isbn, cover_url, google_id")
      .or(
        "cover_url.is.null," +
        "cover_url.eq.," +
        "cover_url.ilike.%covers.openlibrary.org%"
      )
      .order("id", { ascending: false })
      .limit(200); // Process in batches to stay within edge function timeout

    if (error) throw error;
    if (!books?.length) {
      return new Response(
        JSON.stringify({ updated: 0, processed: 0, message: "No books need cover refresh" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    let updated = 0;
    const errors: string[] = [];

    for (const book of books) {
      const { id, title, author, isbn, cover_url } = book;
      try {
        let newCoverUrl: string | null = null;

        // 1. Google Books API
        newCoverUrl = await fetchGoogleBooksCover(isbn, title, author);

        // 2. iTunes / Apple Books
        if (!newCoverUrl) {
          newCoverUrl = await fetchItunesCover(isbn, title, author);
        }

        // 3. Open Library (by ISBN only)
        if (!newCoverUrl && isValidIsbn(isbn)) {
          newCoverUrl = await fetchOpenLibraryCover(isbn);
        }

        // 4. BnF — excellent for French-published books
        if (!newCoverUrl && isValidIsbn(isbn)) {
          newCoverUrl = await fetchBnfCover(isbn);
        }

        if (newCoverUrl && newCoverUrl !== cover_url) {
          const { error: updateError } = await supabase
            .from("books")
            .update({ cover_url: newCoverUrl })
            .eq("id", id);

          if (updateError) {
            errors.push(`Book ${id} ("${title}"): ${updateError.message}`);
          } else {
            updated++;
            console.log(`✓ Updated cover for "${title}" (id=${id})`);
          }
        }
      } catch (e) {
        errors.push(`Book ${id} ("${title}"): ${e.message}`);
      }
    }

    console.log(`Cover refresh done: ${updated}/${books.length} updated`);

    return new Response(
      JSON.stringify({
        updated,
        processed: books.length,
        errors: errors.length > 0 ? errors : undefined,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("refresh-covers error:", e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
