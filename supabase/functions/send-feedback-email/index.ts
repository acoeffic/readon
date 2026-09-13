// supabase/functions/send-feedback-email/index.ts
//
// Email de notification admin pour les feedbacks in-app.
// Appelée par le trigger SQL `trg_feedback_email_after_insert` (migration
// 20260810_app_feedback.sql) à chaque INSERT dans `app_feedback`.
//
// Même modèle d'auth que send-report-email : verify_jwt = false côté
// gateway, vérification du Bearer service_role dans le code.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ADMIN_EMAIL = Deno.env.get("MODERATION_ADMIN_EMAIL") ??
  "a.coeffic@gmail.com";

const STUDIO_URL =
  "https://supabase.com/dashboard/project/nzbhmshkcwudzydeahrq/editor";

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

function isAuthorized(req: Request): boolean {
  if (!SERVICE_ROLE_KEY) return false;
  const token = (req.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  return token.length > 0 && timingSafeEqual(token, SERVICE_ROLE_KEY);
}

interface FeedbackEmailPayload {
  feedback_id: string;
  message: string;
  user_name?: string | null;
  user_email?: string | null;
  app_version?: string | null;
  platform?: string | null;
  locale?: string | null;
  created_at?: string | null;
}

function escapeHtml(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

serve(async (req) => {
  if (!isAuthorized(req)) {
    return new Response("Unauthorized", { status: 401 });
  }
  try {
    const payload = (await req.json()) as FeedbackEmailPayload;

    if (!payload?.feedback_id || !payload?.message) {
      return new Response("Missing required fields", { status: 400 });
    }

    const userName = escapeHtml(payload.user_name ?? "Inconnu");
    const userEmail = payload.user_email ? escapeHtml(payload.user_email) : null;
    const message = escapeHtml(payload.message.slice(0, 2000))
      .replace(/\n/g, "<br>");
    const meta = [payload.app_version, payload.platform, payload.locale]
      .filter(Boolean)
      .map((v) => escapeHtml(String(v)))
      .join(" · ");

    const subject = `[LexDay] Feedback de ${payload.user_name ?? "?"}`;

    const row = (label: string, value: string) => `
      <tr>
        <td style="padding:6px 12px 6px 0;font-size:13px;color:#888;white-space:nowrap;vertical-align:top;">${label}</td>
        <td style="padding:6px 0;font-size:14px;color:#1a1a1a;">${value}</td>
      </tr>`;

    const htmlContent = `
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#F0E8D8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px;">
<table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;">

  <tr><td style="background:#2C3E50;padding:24px 32px;border-radius:12px 12px 0 0;">
    <span style="font-size:18px;font-weight:600;color:#FAF3E8;">LexDay · Feedback</span>
  </td></tr>

  <tr><td style="background:#FAF3E8;padding:28px 32px;border-left:1px solid rgba(0,0,0,0.08);border-right:1px solid rgba(0,0,0,0.08);">
    <table cellpadding="0" cellspacing="0" style="width:100%;background:#fff;border-radius:10px;border:0.5px solid rgba(0,0,0,0.07);padding:0;">
      <tr><td style="padding:16px 20px;">
        <table cellpadding="0" cellspacing="0" style="width:100%;">
          ${row("De", `<strong>${userName}</strong>`)}
          ${userEmail ? row("Email", `<a href="mailto:${userEmail}">${userEmail}</a>`) : ""}
          ${meta ? row("Contexte", meta) : ""}
          ${payload.created_at ? row("Date", escapeHtml(payload.created_at)) : ""}
        </table>
        <div style="margin-top:14px;padding:14px 16px;background:#F7F2E9;border-radius:8px;font-size:14px;color:#1a1a1a;line-height:1.5;">${message}</div>
      </td></tr>
    </table>
    <p style="text-align:center;margin:24px 0 0 0;">
      <a href="${STUDIO_URL}" style="display:inline-block;background:#2C3E50;color:#FAF3E8;text-decoration:none;font-size:14px;font-weight:500;padding:12px 32px;border-radius:50px;">Ouvrir app_feedback dans Studio</a>
    </p>
  </td></tr>

  <tr><td style="background:#F0E8D8;padding:16px 32px;border-radius:0 0 12px 12px;border:0.5px solid rgba(0,0,0,0.08);border-top:none;text-align:center;">
    <p style="font-size:11px;color:#999;margin:0;">Notification automatique — feedback envoyé depuis l'app LexDay.</p>
  </td></tr>

</table>
</td></tr></table>
</body></html>
`;

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      },
      body: JSON.stringify({
        from: "LexDay <hello@lexday.fr>",
        to: ADMIN_EMAIL,
        subject,
        html: htmlContent,
        ...(payload.user_email ? { reply_to: payload.user_email } : {}),
      }),
    });

    if (!resendRes.ok) {
      const err = await resendRes.text();
      throw new Error(`Resend error: ${err}`);
    }

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
