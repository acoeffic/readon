import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RevenueCatEvent {
  type: string;
  app_user_id: string;
  product_id?: string;
  expiration_at_ms?: number;
  purchased_at_ms?: number;
  store?: string;
  period_type?: string;
  environment?: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function verifyWebhookSignature(
  body: string,
  authorization: string | null
): Promise<boolean> {
  if (!REVENUECAT_WEBHOOK_SECRET) {
    console.warn("REVENUECAT_WEBHOOK_SECRET not set, skipping verification");
    return true;
  }

  // RevenueCat sends the secret as Bearer token in Authorization header
  if (!authorization) return false;
  const token = authorization.replace("Bearer ", "");
  return token === REVENUECAT_WEBHOOK_SECRET;
}

function mapPlatform(store?: string): string | null {
  if (!store) return null;
  if (store === "APP_STORE" || store === "MAC_APP_STORE") return "ios";
  if (store === "PLAY_STORE") return "android";
  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const body = await req.text();

  // Vérifier la signature
  const isValid = await verifyWebhookSignature(
    body,
    req.headers.get("authorization")
  );
  if (!isValid) {
    return jsonResponse({ error: "Invalid webhook signature" }, 401);
  }

  let payload: { event: RevenueCatEvent };
  try {
    payload = JSON.parse(body);
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const event = payload.event;
  if (!event || !event.app_user_id) {
    return jsonResponse({ error: "Missing event or app_user_id" }, 400);
  }

  // Ignorer les events sandbox en production si besoin
  // if (event.environment === "SANDBOX") { ... }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { fetch },
  });

  const userId = event.app_user_id;
  const productId = event.product_id ?? null;
  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;
  const purchasedAt = event.purchased_at_ms
    ? new Date(event.purchased_at_ms).toISOString()
    : null;
  const platform = mapPlatform(event.store);

  try {
    switch (event.type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "PRODUCT_CHANGE": {
        const isTrial = event.period_type === "TRIAL";
        const status = isTrial ? "trial" : "premium";

        // Upsert subscriptions
        const { error: subError } = await supabase
          .from("subscriptions")
          .upsert(
            {
              user_id: userId,
              status,
              platform,
              product_id: productId,
              original_purchase_date: purchasedAt,
              expires_at: expiresAt,
              auto_renew: true,
              updated_at: new Date().toISOString(),
            },
            { onConflict: "user_id" }
          );

        if (subError) {
          console.error("Upsert subscription error:", subError);
          return jsonResponse({ error: subError.message }, 500);
        }

        // Sync profiles.is_premium cache
        const { error: profileError } = await supabase
          .from("profiles")
          .update({
            is_premium: true,
            premium_until: expiresAt,
          })
          .eq("id", userId);

        if (profileError) {
          console.error("Update profile error:", profileError);
        }

        console.log(
          `[${event.type}] ${userId}: ${status} until ${expiresAt}`
        );
        break;
      }

      case "CANCELLATION": {
        const { error } = await supabase
          .from("subscriptions")
          .update({
            auto_renew: false,
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);

        if (error) console.error("Cancellation error:", error);
        // L'accès est maintenu jusqu'à expires_at
        console.log(`[CANCELLATION] ${userId}: auto_renew=false`);
        break;
      }

      case "EXPIRATION": {
        const { error: subError } = await supabase
          .from("subscriptions")
          .update({
            status: "expired",
            auto_renew: false,
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);

        if (subError) console.error("Expiration sub error:", subError);

        const { error: profileError } = await supabase
          .from("profiles")
          .update({ is_premium: false })
          .eq("id", userId);

        if (profileError)
          console.error("Expiration profile error:", profileError);

        console.log(`[EXPIRATION] ${userId}: premium revoked`);
        break;
      }

      case "BILLING_ISSUE_DETECTED": {
        const { error } = await supabase
          .from("subscriptions")
          .update({
            status: "billing_issue",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);

        if (error) console.error("Billing issue error:", error);
        console.log(`[BILLING_ISSUE] ${userId}`);
        break;
      }

      default:
        console.log(`[IGNORED] ${event.type} for ${userId}`);
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error("Webhook handler error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
