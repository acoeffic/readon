import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface WikidataBook {
  wikidataId: string;
  title?: string;
  author?: string;
  isbn?: string;
  year?: number | null;
}

interface OpenLibraryData {
  cover_url?: string | null;
  description?: string | null;
  page_count?: number | null;
  open_library_id?: string | null;
}

async function queryWikidata(
  prizeWikidataId: string
): Promise<WikidataBook[]> {
  const query = `
    SELECT DISTINCT ?book ?bookLabel ?authorName ?isbn ?year WHERE {
      ?book wdt:P166 wd:${prizeWikidataId} .
      ?book rdfs:label ?bookLabel . FILTER(LANG(?bookLabel) = "fr")
      OPTIONAL {
        ?book wdt:P50 ?author .
        ?author rdfs:label ?authorName . FILTER(LANG(?authorName) = "fr")
      }
      OPTIONAL { ?book wdt:P212 ?isbn }
      OPTIONAL {
        ?book wdt:P577 ?date .
        BIND(YEAR(?date) AS ?year)
      }
    }
    ORDER BY DESC(?year)
    LIMIT 50
  `;

  const url = `https://query.wikidata.org/sparql?query=${encodeURIComponent(query)}&format=json`;
  const response = await fetch(url, {
    headers: { "User-Agent": "LexDay/1.0 (hello@lexday.fr)" },
  });

  if (!response.ok) {
    throw new Error(
      `Wikidata query failed for ${prizeWikidataId}: ${response.status}`
    );
  }

  const data = await response.json();

  // Deduplicate by wikidataId (keep first occurrence which has latest year)
  const seen = new Set<string>();
  const results: WikidataBook[] = [];

  for (const b of data.results.bindings) {
    const wikidataId = b.book?.value?.split("/").pop();
    if (!wikidataId || seen.has(wikidataId)) continue;
    seen.add(wikidataId);

    results.push({
      wikidataId,
      title: b.bookLabel?.value,
      author: b.authorName?.value,
      isbn: b.isbn?.value,
      year: b.year?.value ? parseInt(b.year.value) : null,
    });
  }

  return results;
}

async function enrichWithOpenLibrary(
  isbn: string | null,
  title: string,
  author: string
): Promise<OpenLibraryData> {
  try {
    // Strategy 1: ISBN lookup
    if (isbn) {
      const res = await fetch(
        `https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=details`
      );
      const data = await res.json();
      const book = data[`ISBN:${isbn}`];
      if (book) {
        const details = book.details;
        const coverId = details?.covers?.[0];
        return {
          cover_url: coverId
            ? `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`
            : null,
          description:
            details?.description?.value || details?.description || null,
          page_count: details?.number_of_pages || null,
          open_library_id: details?.key || null,
        };
      }
    }

    // Strategy 2: Search by title + author
    const searchRes = await fetch(
      `https://openlibrary.org/search.json?title=${encodeURIComponent(title)}&author=${encodeURIComponent(author)}&limit=1&lang=fre`
    );
    const searchData = await searchRes.json();
    const doc = searchData.docs?.[0];
    if (!doc) return {};

    return {
      cover_url: doc.cover_i
        ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg`
        : null,
      description: null,
      page_count: doc.number_of_pages_median || null,
      open_library_id: doc.key || null,
    };
  } catch (e) {
    console.error(`Open Library enrichment failed for "${title}":`, e);
    return {};
  }
}

serve(async (_req) => {
  try {
    // Fetch active prize configs
    const { data: prizes, error: prizesError } = await supabase
      .from("prize_configs")
      .select("*")
      .eq("is_active", true);

    if (prizesError) throw prizesError;

    const results: string[] = [];

    for (const prize of prizes ?? []) {
      // Query Wikidata for laureates
      const books = await queryWikidata(prize.wikidata_id);

      // Group by year
      const byYear: Record<number, WikidataBook[]> = {};
      for (const book of books) {
        if (book.year) {
          if (!byYear[book.year]) byYear[book.year] = [];
          byYear[book.year].push(book);
        }
      }

      for (const [yearStr, yearBooks] of Object.entries(byYear)) {
        const year = parseInt(yearStr);

        // Upsert prize_list
        const { data: list, error: listError } = await supabase
          .from("prize_lists")
          .upsert(
            {
              title: `${prize.prize_name} ${year}`,
              prize_name: prize.prize_name,
              prize_wikidata_id: prize.wikidata_id,
              list_type: "prize_year",
              year,
              is_active: true,
              last_synced_at: new Date().toISOString(),
            },
            { onConflict: "prize_wikidata_id,year,list_type" }
          )
          .select()
          .single();

        if (listError || !list) {
          console.error(`Error upserting list ${prize.prize_name} ${year}:`, listError);
          continue;
        }

        // Set cover_url from first book's cover (after enrichment)
        let firstCoverUrl: string | null = null;

        // Enrich and upsert each book
        for (let i = 0; i < yearBooks.length; i++) {
          const book = yearBooks[i];
          // Rate limit: 300ms between Open Library calls
          await new Promise((r) => setTimeout(r, 300));

          const enriched = await enrichWithOpenLibrary(
            book.isbn ?? null,
            book.title ?? "",
            book.author ?? ""
          );

          if (i === 0 && enriched.cover_url) {
            firstCoverUrl = enriched.cover_url;
          }

          await supabase.from("prize_list_books").upsert(
            {
              list_id: list.id,
              isbn: book.isbn ?? null,
              wikidata_book_id: book.wikidataId,
              title: book.title ?? "Titre inconnu",
              author: book.author ?? null,
              publication_year: book.year,
              position: i + 1,
              cover_url: enriched.cover_url ?? null,
              description: enriched.description ?? null,
              page_count: enriched.page_count ?? null,
              open_library_id: enriched.open_library_id ?? null,
            },
            { onConflict: "list_id,wikidata_book_id" }
          );
        }

        // Update list cover with first book's cover
        if (firstCoverUrl) {
          await supabase
            .from("prize_lists")
            .update({ cover_url: firstCoverUrl })
            .eq("id", list.id);
        }

        results.push(
          `${prize.prize_name} ${year}: ${yearBooks.length} livre(s)`
        );
      }

      // Thematic list: "Les 10 dernières années" for Goncourt
      if (prize.wikidata_id === "Q163020") {
        const currentYear = new Date().getFullYear();
        const recentBooks = books.filter(
          (b) => b.year && b.year >= currentYear - 10
        );

        const { data: thematicList, error: thematicError } = await supabase
          .from("prize_lists")
          .upsert(
            {
              title: `Les Goncourt des 10 dernières années`,
              description: `Les lauréats du Prix Goncourt de ${currentYear - 10} à ${currentYear}`,
              prize_name: "Prix Goncourt",
              prize_wikidata_id: prize.wikidata_id,
              list_type: "thematic",
              year: null,
              is_active: true,
              last_synced_at: new Date().toISOString(),
            },
            { onConflict: "prize_wikidata_id,year,list_type" }
          )
          .select()
          .single();

        if (!thematicError && thematicList) {
          // Delete existing books and recreate
          await supabase
            .from("prize_list_books")
            .delete()
            .eq("list_id", thematicList.id);

          const sorted = recentBooks.sort(
            (a, b) => (b.year ?? 0) - (a.year ?? 0)
          );

          for (let i = 0; i < sorted.length; i++) {
            const book = sorted[i];
            await new Promise((r) => setTimeout(r, 300));
            const enriched = await enrichWithOpenLibrary(
              book.isbn ?? null,
              book.title ?? "",
              book.author ?? ""
            );

            await supabase.from("prize_list_books").insert({
              list_id: thematicList.id,
              isbn: book.isbn ?? null,
              wikidata_book_id: book.wikidataId,
              title: book.title ?? "Titre inconnu",
              author: book.author ?? null,
              publication_year: book.year,
              position: i + 1,
              cover_url: enriched.cover_url ?? null,
              description: enriched.description ?? null,
              page_count: enriched.page_count ?? null,
              open_library_id: enriched.open_library_id ?? null,
            });

            // Use first book cover as list cover
            if (i === 0 && enriched.cover_url) {
              await supabase
                .from("prize_lists")
                .update({ cover_url: enriched.cover_url })
                .eq("id", thematicList.id);
            }
          }

          results.push(
            `${prize.prize_name} thématique: ${sorted.length} livre(s)`
          );
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, synced: results }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("sync-literary-prizes error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
