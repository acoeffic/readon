import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const AMAZON_BASE = "https://read.amazon.com";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing Supabase service credentials");
}

interface KindleBook {
  title: string;
  author?: string;
  cover?: string;
  totalPages?: number;
  progressPages?: number;
  status?: string;
  amazonId?: string;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Not found", { status: 404 });
  }

  let payload: { email?: string; password?: string; user_id?: string };
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const { email, password, user_id } = payload;
  if (!email || !password || !user_id) {
    return jsonResponse(
      { error: "email, password and user_id are required" },
      400,
    );
  }

  try {
    // 1. Authenticate against your backend/Cloud Reader integration
    const token = await loginToAmazon(email, password);

    // 2. Fetch Kindle library
    const kindleBooks = await fetchLibrary(token);

    // 3. Persist data in Supabase
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { fetch },
    });

    const bookRows = kindleBooks.map((book) => ({
      title: book.title,
      author: book.author,
      cover_url: book.cover,
      total_pages: book.totalPages,
      external_id: book.amazonId,
    }));

    const { data: upsertedBooks, error: booksError } = await supabase
      .from("books")
      .upsert(bookRows, { onConflict: "external_id" })
      .select("id, external_id");

    if (booksError) throw booksError;

    const bookIdByExternal: Record<string, number> = {};
    for (const row of upsertedBooks ?? []) {
      if (row.external_id) {
        bookIdByExternal[row.external_id] = row.id;
      }
    }

    const userBookRows = kindleBooks
      .map((book) => {
        const bookId = book.amazonId ? bookIdByExternal[book.amazonId] : undefined;
        if (!bookId) return null;
        return {
          user_id,
          book_id: bookId,
          current_page: book.progressPages ?? 0,
          status: book.status ?? "in_progress",
        };
      })
      .filter((row): row is NonNullable<typeof row> => !!row);

    if (userBookRows.length > 0) {
      const { error: userBooksError } = await supabase
        .from("user_books")
        .upsert(userBookRows, { onConflict: "user_id,book_id" });
      if (userBooksError) throw userBooksError;
    }

    return jsonResponse({ imported: userBookRows.length });
  } catch (error) {
    console.error("Kindle sync failed", error);
    return jsonResponse({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

async function loginToAmazon(email: string, _password: string): Promise<string> {
  // Placeholder: implement secure auth via backend/headless browser.
  // For now, throw to remind devs to hook up the integration.
  throw new Error(
    "Connect a backend/headless workflow to authenticate with Kindle. This function expects a token.",
  );
}

async function fetchLibrary(_token: string): Promise<KindleBook[]> {
  // Placeholder: replace with logic that scrapes or uses Kindle API
  // via the authenticated session/token returned by loginToAmazon.
  return [];
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
