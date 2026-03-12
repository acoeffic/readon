import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MODERATION_PROMPT = `Tu es modérateur pour une app de lecture sociale. Réponds uniquement APPROVE ou REJECT.
REJECT si: spam, insulte, harcèlement, contenu adulte, publicité, attaque personnelle.
APPROVE si: encouragement, discussion sur les livres, conversation amicale, emojis.
Sois indulgent : c'est une communauté bienveillante de lecteurs. La plupart des commentaires doivent être approuvés.
Les commentaires en toute langue sont acceptables (français, anglais, espagnol, etc.).`;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const { comment_id, content } = await req.json();

    if (!comment_id || !content) {
      return jsonResponse({ error: "comment_id and content required" }, 400);
    }

    // Graceful degradation: auto-approve if no OpenAI key
    if (!OPENAI_API_KEY) {
      console.warn("OPENAI_API_KEY not set, auto-approving comment");
      await supabase
        .from("comments")
        .update({ status: "approved" })
        .eq("id", comment_id);
      return jsonResponse({ status: "approved", reason: "auto-approved" });
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
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: MODERATION_PROMPT },
            {
              role: "user",
              content: `Commentaire: ${content}`,
            },
          ],
          max_tokens: 50,
          temperature: 0,
        }),
      }
    );

    if (!openaiResponse.ok) {
      console.error("OpenAI error:", await openaiResponse.text());
      // Auto-approve on AI failure to not block user experience
      await supabase
        .from("comments")
        .update({ status: "approved" })
        .eq("id", comment_id);
      return jsonResponse({ status: "approved", reason: "auto-approved (AI error)" });
    }

    const data = await openaiResponse.json();
    const aiResponse = (data.choices?.[0]?.message?.content ?? "").trim().toUpperCase();

    const newStatus = aiResponse.startsWith("REJECT") ? "rejected" : "approved";

    await supabase
      .from("comments")
      .update({ status: newStatus })
      .eq("id", comment_id);

    return jsonResponse({ status: newStatus });
  } catch (error) {
    console.error("Moderation error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
