import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY"
  );
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const NOTION_API = "https://api.notion.com/v1";
const NOTION_VERSION = "2022-06-28";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function notionHeaders(token: string) {
  return {
    Authorization: `Bearer ${token}`,
    "Notion-Version": NOTION_VERSION,
    "Content-Type": "application/json",
  };
}

function richText(content: string) {
  return [{ type: "text", text: { content } }];
}

function heading2(text: string) {
  return { object: "block", type: "heading_2", heading_2: { rich_text: richText(text) } };
}

function heading3(text: string) {
  return { object: "block", type: "heading_3", heading_3: { rich_text: richText(text) } };
}

function paragraph(text: string) {
  return { object: "block", type: "paragraph", paragraph: { rich_text: richText(text) } };
}

function quoteBlock(text: string) {
  return { object: "block", type: "quote", quote: { rich_text: richText(text) } };
}

function divider() {
  return { object: "block", type: "divider", divider: {} };
}

interface Theme { title: string; description: string }
interface Quote { text: string; page: number | null; comment: string }
interface ReadingSheet {
  themes: Theme[];
  quotes: Quote[];
  progression: string;
  synthesis: string;
  annotation_count: number;
}

function buildNotionBlocks(sheet: ReadingSheet): Record<string, unknown>[] {
  const blocks: Record<string, unknown>[] = [];

  // Themes
  if (sheet.themes?.length > 0) {
    blocks.push(heading2("Thèmes principaux"));
    for (const theme of sheet.themes) {
      blocks.push(heading3(theme.title));
      if (theme.description) blocks.push(paragraph(theme.description));
    }
    blocks.push(divider());
  }

  // Quotes
  if (sheet.quotes?.length > 0) {
    blocks.push(heading2("Citations notables"));
    for (const quote of sheet.quotes) {
      blocks.push(quoteBlock(quote.text));
      const pageInfo = quote.page ? ` (p. ${quote.page})` : "";
      if (quote.comment) blocks.push(paragraph(`${quote.comment}${pageInfo}`));
    }
    blocks.push(divider());
  }

  // Progression
  if (sheet.progression) {
    blocks.push(heading2("Progression de pensée"));
    for (const p of sheet.progression.split("\n\n")) {
      if (p.trim()) blocks.push(paragraph(p.trim()));
    }
    blocks.push(divider());
  }

  // Synthesis
  if (sheet.synthesis) {
    blocks.push(heading2("Synthèse personnelle"));
    for (const p of sheet.synthesis.split("\n\n")) {
      if (p.trim()) blocks.push(paragraph(p.trim()));
    }
    blocks.push(divider());
  }

  // Footer
  blocks.push({
    object: "block",
    type: "callout",
    callout: {
      rich_text: [{ type: "text", text: { content: "Généré par LexDay — lexday.app", link: { url: "https://lexday.app" } } }],
      icon: { type: "emoji", emoji: "📚" },
    },
  });

  return blocks;
}

async function findOrCreateDatabase(
  token: string,
  profileId: string,
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  // Search for an accessible page to use as parent
  const searchRes = await fetch(`${NOTION_API}/search`, {
    method: "POST",
    headers: notionHeaders(token),
    body: JSON.stringify({
      filter: { value: "page", property: "object" },
      page_size: 1,
    }),
  });

  if (!searchRes.ok) {
    throw new Error("Impossible d'accéder à votre workspace Notion. Reconnectez votre compte.");
  }

  const searchData = await searchRes.json();
  if (!searchData.results?.length) {
    throw new Error("Aucune page accessible dans votre workspace Notion. Reconnectez avec accès à au moins une page.");
  }

  const parentPageId = searchData.results[0].id;

  // Create the database
  const dbRes = await fetch(`${NOTION_API}/databases`, {
    method: "POST",
    headers: notionHeaders(token),
    body: JSON.stringify({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "LexDay — Fiches de Lecture" } }],
      properties: {
        "Titre": { title: {} },
        "Auteur": { rich_text: {} },
        "Thèmes": { multi_select: {} },
        "Date": { date: {} },
        "Annotations": { number: {} },
      },
    }),
  });

  if (!dbRes.ok) {
    const err = await dbRes.text();
    console.error("Notion create database error:", err);
    throw new Error("Impossible de créer la base Notion");
  }

  const dbData = await dbRes.json();
  const databaseId = dbData.id;

  // Store database ID in profile
  await supabase
    .from("profiles")
    .update({ notion_database_id: databaseId })
    .eq("id", profileId);

  return databaseId;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // --- Auth ---
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
    const { book_id } = body;

    if (!book_id) {
      return jsonResponse({ error: "book_id requis" }, 400);
    }

    const bookIdInt = parseInt(book_id, 10);
    if (isNaN(bookIdInt)) {
      return jsonResponse({ error: "book_id invalide" }, 400);
    }

    // --- Premium check ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium, notion_access_token, notion_database_id")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium === true;

    if (!isPremium) {
      return jsonResponse({ error: "premium_required", message: "Cette fonctionnalité est réservée aux utilisateurs Premium." }, 403);
    }

    // --- Check Notion connection ---
    const notionToken = profile?.notion_access_token;
    if (!notionToken) {
      return jsonResponse({ error: "notion_not_connected", message: "Connectez votre compte Notion dans les paramètres." }, 400);
    }

    // --- Fetch book + reading sheet ---
    const { data: book } = await supabase
      .from("books")
      .select("title, author")
      .eq("id", bookIdInt)
      .single();

    if (!book) {
      return jsonResponse({ error: "Livre non trouvé" }, 404);
    }

    const { data: userBook } = await supabase
      .from("user_books")
      .select("reading_sheet, reading_sheet_generated_at, notion_page_id")
      .eq("user_id", user.id)
      .eq("book_id", bookIdInt)
      .maybeSingle();

    if (!userBook?.reading_sheet) {
      return jsonResponse({ error: "Aucune fiche de lecture générée pour ce livre" }, 400);
    }

    const sheet = userBook.reading_sheet as ReadingSheet;

    // --- Get or create Notion database ---
    let databaseId = profile?.notion_database_id;
    if (!databaseId) {
      databaseId = await findOrCreateDatabase(notionToken, user.id, supabase);
    }

    // --- Build page properties ---
    const properties: Record<string, unknown> = {
      "Titre": { title: richText(book.title) },
      "Auteur": { rich_text: richText(book.author || "") },
      "Thèmes": {
        multi_select: (sheet.themes || []).map((t: Theme) => ({ name: t.title })),
      },
      "Annotations": { number: sheet.annotation_count || 0 },
    };

    if (userBook.reading_sheet_generated_at) {
      properties["Date"] = { date: { start: userBook.reading_sheet_generated_at } };
    }

    const children = buildNotionBlocks(sheet);

    // --- Create or update page ---
    let notionPageId = userBook.notion_page_id;
    let notionUrl: string;

    if (notionPageId) {
      // Try to update existing page: delete old blocks then add new ones
      // First check if page still exists
      const checkRes = await fetch(`${NOTION_API}/pages/${notionPageId}`, {
        headers: notionHeaders(notionToken),
      });

      if (checkRes.ok) {
        // Update properties
        await fetch(`${NOTION_API}/pages/${notionPageId}`, {
          method: "PATCH",
          headers: notionHeaders(notionToken),
          body: JSON.stringify({ properties }),
        });

        // Get existing blocks to delete them
        const blocksRes = await fetch(`${NOTION_API}/blocks/${notionPageId}/children?page_size=100`, {
          headers: notionHeaders(notionToken),
        });
        if (blocksRes.ok) {
          const blocksData = await blocksRes.json();
          for (const block of blocksData.results || []) {
            await fetch(`${NOTION_API}/blocks/${block.id}`, {
              method: "DELETE",
              headers: notionHeaders(notionToken),
            });
          }
        }

        // Add new blocks
        await fetch(`${NOTION_API}/blocks/${notionPageId}/children`, {
          method: "PATCH",
          headers: notionHeaders(notionToken),
          body: JSON.stringify({ children }),
        });

        notionUrl = `https://notion.so/${notionPageId.replace(/-/g, "")}`;
      } else {
        // Page was deleted, create new one
        notionPageId = null;
      }
    }

    if (!notionPageId) {
      // Create new page
      const createRes = await fetch(`${NOTION_API}/pages`, {
        method: "POST",
        headers: notionHeaders(notionToken),
        body: JSON.stringify({
          parent: { database_id: databaseId },
          properties,
          children,
        }),
      });

      if (!createRes.ok) {
        const err = await createRes.text();
        console.error("Notion create page error:", err);

        // If database not found, clear it and retry
        if (createRes.status === 404 || createRes.status === 400) {
          return jsonResponse({ error: "Base Notion introuvable. Reconnectez votre compte Notion." }, 400);
        }

        return jsonResponse({ error: "Erreur lors de la création de la page Notion" }, 502);
      }

      const pageData = await createRes.json();
      notionPageId = pageData.id;
      notionUrl = pageData.url;
    }

    // --- Store sync info ---
    await supabase
      .from("user_books")
      .update({
        notion_page_id: notionPageId,
        notion_synced_at: new Date().toISOString(),
      })
      .eq("user_id", user.id)
      .eq("book_id", bookIdInt);

    return jsonResponse({ success: true, notion_url: notionUrl! });
  } catch (error) {
    console.error("Notion sync error:", error);
    const message = error instanceof Error ? error.message : "Erreur interne";
    return jsonResponse({ error: message }, 500);
  }
});
