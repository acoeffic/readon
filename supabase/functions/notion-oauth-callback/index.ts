import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const NOTION_CLIENT_ID = Deno.env.get("NOTION_CLIENT_ID");
const NOTION_CLIENT_SECRET = Deno.env.get("NOTION_CLIENT_SECRET");

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

  if (!NOTION_CLIENT_ID || !NOTION_CLIENT_SECRET) {
    return jsonResponse({ error: "Notion credentials non configurées" }, 500);
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
    const { action, code, redirect_uri } = body;

    // --- Disconnect ---
    if (action === "disconnect") {
      await supabase
        .from("profiles")
        .update({
          notion_access_token: null,
          notion_workspace_id: null,
          notion_workspace_name: null,
          notion_database_id: null,
          notion_connected_at: null,
        })
        .eq("id", user.id);

      return jsonResponse({ success: true });
    }

    // --- Exchange code for token ---
    if (!code || typeof code !== "string") {
      return jsonResponse({ error: "code requis" }, 400);
    }

    // Premium check
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium === true;

    if (!isPremium) {
      return jsonResponse({ error: "premium_required", message: "Cette fonctionnalité est réservée aux utilisateurs Premium." }, 403);
    }

    // Exchange code for access token
    const credentials = btoa(`${NOTION_CLIENT_ID}:${NOTION_CLIENT_SECRET}`);

    const tokenResponse = await fetch("https://api.notion.com/v1/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${credentials}`,
      },
      body: JSON.stringify({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirect_uri || "lexday://notion/callback",
      }),
    });

    if (!tokenResponse.ok) {
      const error = await tokenResponse.text();
      console.error("Notion OAuth error:", error);
      return jsonResponse({ error: "Erreur d'authentification Notion" }, 502);
    }

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;
    const workspaceId = tokenData.workspace_id;
    const workspaceName = tokenData.workspace_name;

    if (!accessToken) {
      return jsonResponse({ error: "Token Notion manquant" }, 502);
    }

    // Store in profiles
    await supabase
      .from("profiles")
      .update({
        notion_access_token: accessToken,
        notion_workspace_id: workspaceId,
        notion_workspace_name: workspaceName,
        notion_connected_at: new Date().toISOString(),
      })
      .eq("id", user.id);

    return jsonResponse({ workspace_name: workspaceName });
  } catch (error) {
    console.error("Notion OAuth error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});
