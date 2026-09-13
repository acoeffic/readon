// supabase/functions/send-report-email/index.ts
//
// Email de notification admin pour la modération.
// Appelée par le trigger SQL `trg_report_email_after_insert` (migration
// 20260809_report_email_notifications.sql) à chaque INSERT dans
// `content_reports` — ce qui couvre :
//   - les signalements manuels des utilisateurs (status = 'pending')
//   - les auto-rejets de l'auto-modération avatar/display-name
//     (status = 'actioned', details commence par "auto-moderation")
//
// Même modèle d'auth que send-comment-email : verify_jwt = false côté
// gateway, vérification du Bearer service_role dans le code.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ADMIN_EMAIL = Deno.env.get("MODERATION_ADMIN_EMAIL") ??
  "a.coeffic@gmail.com";

const STUDIO_REPORTS_URL =
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

interface ReportEmailPayload {
  report_id: string;
  target_type: string;
  target_id: string;
  reason: string;
  status: string;
  details?: string | null;
  reporter_name?: string | null;
  target_user_name?: string | null;
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

const REASON_LABELS: Record<string, string> = {
  spam: "Spam",
  harassment: "Harcèlement",
  hate_speech: "Discours haineux",
  sexual_content: "Contenu sexuel",
  violence: "Violence",
  self_harm: "Automutilation",
  misinformation: "Désinformation",
  impersonation: "Usurpation d'identité",
  illegal: "Contenu illégal",
  other: "Autre",
};

const TARGET_LABELS: Record<string, string> = {
  user: "Utilisateur",
  profile: "Profil",
  comment: "Commentaire",
  activity: "Activité",
  reading_session: "Session de lecture",
  review: "Avis",
};

serve(async (req) => {
  if (!isAuthorized(req)) {
    return new Response("Unauthorized", { status: 401 });
  }
  try {
    const payload = (await req.json()) as ReportEmailPayload;

    if (!payload?.report_id || !payload?.target_type || !payload?.reason) {
      return new Response("Missing required fields", { status: 400 });
    }

    const isAuto = payload.status === "actioned" &&
      (payload.details ?? "").startsWith("auto-moderation");

    const reasonLabel = REASON_LABELS[payload.reason] ?? payload.reason;
    const targetLabel = TARGET_LABELS[payload.target_type] ??
      payload.target_type;
    const reporter = escapeHtml(payload.reporter_name ?? "Inconnu");
    const targetUser = escapeHtml(payload.target_user_name ?? "Inconnu");
    const details = payload.details
      ? escapeHtml(payload.details.slice(0, 800))
      : null;

    const subject = isAuto
      ? `[LexDay modération] Auto-rejet : ${reasonLabel} (${targetLabel.toLowerCase()})`
      : `[LexDay modération] Signalement : ${reasonLabel} (${targetLabel.toLowerCase()})`;

    const badge = isAuto
      ? `<span style="background:#B87900;color:#fff;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:600;">AUTO-MODÉRATION (déjà traité)</span>`
      : `<span style="background:#C0392B;color:#fff;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:600;">ACTION REQUISE</span>`;

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
    <span style="font-size:18px;font-weight:600;color:#FAF3E8;">LexDay · Modération</span>
  </td></tr>

  <tr><td style="background:#FAF3E8;padding:28px 32px;border-left:1px solid rgba(0,0,0,0.08);border-right:1px solid rgba(0,0,0,0.08);">
    <p style="margin:0 0 16px 0;">${badge}</p>
    <table cellpadding="0" cellspacing="0" style="width:100%;background:#fff;border-radius:10px;border:0.5px solid rgba(0,0,0,0.07);padding:0;">
      <tr><td style="padding:16px 20px;">
        <table cellpadding="0" cellspacing="0" style="width:100%;">
          ${row("Type de cible", escapeHtml(targetLabel))}
          ${row("Raison", `<strong>${escapeHtml(reasonLabel)}</strong>`)}
          ${row("Signalé par", reporter)}
          ${row("Utilisateur visé", targetUser)}
          ${row("ID cible", `<code style="font-size:12px;">${escapeHtml(payload.target_id)}</code>`)}
          ${row("Report ID", `<code style="font-size:12px;">${escapeHtml(payload.report_id)}</code>`)}
          ${payload.created_at ? row("Date", escapeHtml(payload.created_at)) : ""}
          ${details ? row("Détails", `<em>${details}</em>`) : ""}
        </table>
      </td></tr>
    </table>
    <p style="text-align:center;margin:24px 0 0 0;">
      <a href="${STUDIO_REPORTS_URL}" style="display:inline-block;background:#2C3E50;color:#FAF3E8;text-decoration:none;font-size:14px;font-weight:500;padding:12px 32px;border-radius:50px;">Ouvrir content_reports dans Studio</a>
    </p>
  </td></tr>

  <tr><td style="background:#F0E8D8;padding:16px 32px;border-radius:0 0 12px 12px;border:0.5px solid rgba(0,0,0,0.08);border-top:none;text-align:center;">
    <p style="font-size:11px;color:#999;margin:0;">Notification automatique de modération LexDay (guidelines Apple §1.2 : traiter sous 24h).</p>
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
