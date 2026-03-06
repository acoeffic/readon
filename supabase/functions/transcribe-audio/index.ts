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

const MAX_FREE_MONTHLY_TRANSCRIPTIONS = 3;

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
      .select("id, user_id, content, audio_path")
      .eq("id", annotation_id)
      .single();

    if (annotationError || !annotation) {
      return jsonResponse({ error: "Annotation non trouvée" }, 404);
    }

    // Verify ownership
    if (annotation.user_id !== user.id) {
      return jsonResponse({ error: "Annotation non trouvée" }, 404);
    }

    // Check audio exists
    if (!annotation.audio_path) {
      return jsonResponse({ error: "Pas de fichier audio pour cette annotation" }, 400);
    }

    // --- Premium check ---
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium === true;

    // --- Count usage this month ---
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const { count: usageCount } = await supabase
      .from("ai_usage")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("feature", "transcription")
      .gte("used_at", startOfMonth.toISOString());

    const currentCount = usageCount ?? 0;

    // --- If already transcribed, return existing without consuming credit ---
    if (annotation.content && annotation.content.trim() !== "" && annotation.content.trim() !== "...") {
      const remaining = isPremium
        ? -1
        : Math.max(0, MAX_FREE_MONTHLY_TRANSCRIPTIONS - currentCount);
      return jsonResponse({
        transcription: annotation.content,
        remaining,
      });
    }

    // --- Enforce free tier limit ---
    if (!isPremium && currentCount >= MAX_FREE_MONTHLY_TRANSCRIPTIONS) {
      return jsonResponse({ error: "limit_reached", remaining: 0 }, 429);
    }

    // --- Download audio from Storage ---
    const { data: audioData, error: downloadError } = await supabase.storage
      .from("annotations")
      .download(annotation.audio_path);

    if (downloadError || !audioData) {
      console.error("Audio download error:", downloadError);
      return jsonResponse({ error: "Fichier audio introuvable" }, 404);
    }

    // --- Call OpenAI Whisper API ---
    const formData = new FormData();
    formData.append("file", audioData, "recording.m4a");
    formData.append("model", "whisper-1");

    const whisperResponse = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: formData,
      }
    );

    if (!whisperResponse.ok) {
      const error = await whisperResponse.text();
      console.error("Whisper error:", error);
      return jsonResponse({ error: "Erreur du service de transcription" }, 502);
    }

    const whisperData = await whisperResponse.json();
    const transcription = whisperData.text ?? "";

    if (!transcription) {
      return jsonResponse({ error: "Transcription vide" }, 502);
    }

    // --- Update annotation with transcription ---
    await supabase
      .from("annotations")
      .update({ content: transcription })
      .eq("id", annotation_id);

    // --- Record usage ---
    await supabase.from("ai_usage").insert({
      user_id: user.id,
      feature: "transcription",
    });

    const remaining = isPremium
      ? -1
      : Math.max(0, MAX_FREE_MONTHLY_TRANSCRIPTIONS - currentCount - 1);

    return jsonResponse({ transcription, remaining });
  } catch (error) {
    console.error("Transcribe error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
