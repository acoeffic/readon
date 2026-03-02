import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

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

const MAX_FREE_MONTHLY_SUMMARIES = 3;
const MIN_CONTENT_LENGTH = 20;

const SYSTEM_PROMPT = `Tu es un assistant littéraire. Résume le passage suivant de manière concise et claire, en 2-3 phrases maximum. Capture l'idée principale et le ton du texte. Réponds en français si le texte est en français, en anglais si le texte est en anglais.`;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!OPENAI_API_KEY) {
    return jsonResponse({ error: "OPENAI_API_KEY non configurée" }, 500);
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

  // Service-role client for data queries
  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const body = await req.json();
    const { annotation_id } = body;

    if (!annotation_id || typeof annotation_id !== "string") {
      return jsonResponse({ error: "annotation_id requis" }, 400);
    }

    // --- Fetch annotation ---
    const { data: annotation, error: annotationError } = await supabase
      .from("annotations")
      .select("id, user_id, content, ai_summary")
      .eq("id", annotation_id)
      .single();

    if (annotationError || !annotation) {
      return jsonResponse({ error: "Annotation non trouvée" }, 404);
    }

    // Verify ownership
    if (annotation.user_id !== user.id) {
      return jsonResponse({ error: "Annotation non trouvée" }, 404);
    }

    // --- Premium check ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const devForcePremium = Deno.env.get("DEV_FORCE_PREMIUM") === "true";
    const isPremium = devForcePremium || profile?.is_premium === true;

    // --- Count usage this month ---
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const { count: usageCount } = await supabase
      .from("ai_usage")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("feature", "summary")
      .gte("used_at", startOfMonth.toISOString());

    const currentCount = usageCount ?? 0;

    // --- If already summarized, return existing without consuming credit ---
    if (annotation.ai_summary) {
      const remaining = isPremium
        ? -1
        : Math.max(0, MAX_FREE_MONTHLY_SUMMARIES - currentCount);
      return jsonResponse({
        summary: annotation.ai_summary,
        remaining,
      });
    }

    // --- Validate content length ---
    if (
      !annotation.content ||
      annotation.content.trim().length < MIN_CONTENT_LENGTH
    ) {
      return jsonResponse({ error: "text_too_short" }, 400);
    }

    // --- Enforce free tier limit ---
    if (!isPremium && currentCount >= MAX_FREE_MONTHLY_SUMMARIES) {
      return jsonResponse({ error: "limit_reached", remaining: 0 }, 429);
    }

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
          max_tokens: 300,
          temperature: 0.3,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: annotation.content },
          ],
        }),
      }
    );

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error("OpenAI error:", error);
      return jsonResponse({ error: "Erreur du service IA" }, 502);
    }

    const openaiData = await openaiResponse.json();
    const summary =
      openaiData.choices?.[0]?.message?.content ?? "";

    if (!summary) {
      return jsonResponse({ error: "Réponse IA vide" }, 502);
    }

    // --- Update annotation with summary ---
    await supabase
      .from("annotations")
      .update({ ai_summary: summary })
      .eq("id", annotation_id);

    // --- Record usage ---
    await supabase.from("ai_usage").insert({
      user_id: user.id,
      feature: "summary",
    });

    const remaining = isPremium
      ? -1
      : Math.max(0, MAX_FREE_MONTHLY_SUMMARIES - currentCount - 1);

    return jsonResponse({ summary, remaining });
  } catch (error) {
    console.error("Summarize error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
