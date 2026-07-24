// supabase/functions/send-comment-email/index.ts
//
// Email envoyé à l'auteur d'une activité quand un commentaire posté
// sur cette activité est *approuvé* par la modération.
// Le trigger SQL `trg_comment_email_after_approve` appelle cette
// function via pg_net en lui fournissant déjà l'email du destinataire,
// le nom du commentateur, le contenu du commentaire et le titre du livre.
//
// On respecte l'opt-out côté trigger (notify_comments_email), donc ici
// pas besoin de re-vérifier la préférence.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Cette fonction est appelée uniquement par le trigger SQL
// `send_comment_email_on_approve`, qui présente la clé service_role
// (stockée dans Vault) en Bearer. On refuse tout autre appelant :
// avec `verify_jwt = false` (voir config.toml), le gateway ne filtre
// plus rien, donc l'auth se fait ici. La clé anon embarquée dans l'app
// ne matche pas la service_role → relais e-mail fermé.
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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

interface CommentEmailPayload {
  to_email: string;
  to_name: string;
  from_name: string;
  book_title?: string;
  comment: string;
  activity_id?: number;
}

function escapeHtml(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function truncate(input: string, max: number): string {
  if (input.length <= max) return input;
  return input.slice(0, max - 1).trimEnd() + "…";
}

serve(async (req) => {
  if (!isAuthorized(req)) {
    return new Response("Unauthorized", { status: 401 });
  }
  try {
    const payload = (await req.json()) as CommentEmailPayload;

    if (!payload?.to_email || !payload?.from_name || !payload?.comment) {
      return new Response("Missing required fields", { status: 400 });
    }

    const senderName = escapeHtml(payload.from_name);
    const recipientName = escapeHtml(payload.to_name || "Lecteur");
    const bookTitle = payload.book_title
      ? escapeHtml(payload.book_title)
      : null;
    const commentText = escapeHtml(truncate(payload.comment, 600));
    const senderInitial = (payload.from_name.charAt(0) || "?").toUpperCase();

    const subject = bookTitle
      ? `${payload.from_name} a commenté ta lecture de « ${payload.book_title} »`
      : `${payload.from_name} a commenté ta session de lecture`;

    const headlineSecondLine = bookTitle
      ? `commenté ta lecture de<br><em style="font-style:italic;color:#6B988D;">${bookTitle}</em>`
      : `commenté ta session de lecture`;

    const htmlContent = `
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F0E8D8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px;">
<table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;">

  <tr><td style="background:#6B988D;padding:28px 32px;border-radius:12px 12px 0 0;text-align:center;">
    <img src="https://nzbhmshkcwudzydeahrq.supabase.co/storage/v1/object/public/asset/email/logo.png" width="32" height="32" alt="LexDay" style="vertical-align:middle;margin-right:10px;border-radius:6px;">
    <span style="font-size:20px;font-weight:500;color:#FAF3E8;letter-spacing:-0.3px;vertical-align:middle;">LexDay</span>
  </td></tr>

  <tr><td style="background:#FAF3E8;padding:36px 32px 28px;border-left:1px solid rgba(107,152,141,0.15);border-right:1px solid rgba(107,152,141,0.15);">
    <p style="font-size:13px;font-weight:500;color:#B87900;letter-spacing:0.08em;text-transform:uppercase;margin:0 0 10px 0;">Nouveau commentaire</p>
    <h1 style="font-size:26px;font-weight:400;color:#1a1a1a;margin:0 0 24px 0;line-height:1.3;">${senderName} a<br>${headlineSecondLine}</h1>

    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;border:0.5px solid rgba(0,0,0,0.07);margin-bottom:24px;">
      <tr><td style="padding:18px 20px;">
        <table cellpadding="0" cellspacing="0" width="100%"><tr>
          <td valign="top" style="width:52px;">
            <div style="width:44px;height:44px;border-radius:50%;background:#6B988D;text-align:center;line-height:44px;font-size:18px;font-weight:500;color:#FAF3E8;">${senderInitial}</div>
          </td>
          <td style="padding-left:14px;" valign="top">
            <div style="font-size:15px;font-weight:600;color:#1a1a1a;margin-bottom:6px;">${senderName}</div>
            <div style="font-size:15px;color:#333;line-height:1.55;white-space:pre-wrap;">${commentText}</div>
          </td>
        </tr></table>
      </td></tr>
    </table>

    <p style="font-size:15px;color:#555;line-height:1.7;margin:0 0 28px 0;">
      Salut <strong style="color:#1a1a1a;">${recipientName}</strong>&nbsp;! Ouvre l'app pour répondre et continuer la discussion.
    </p>

    <p style="text-align:center;margin:0;">
      <a href="https://www.lexday.fr/redirect?to=feed" style="display:inline-block;background:#6B988D;color:#FAF3E8;text-decoration:none;font-size:15px;font-weight:500;padding:14px 36px;border-radius:50px;">Voir dans LexDay</a>
    </p>
  </td></tr>

  <tr><td style="background:#F0E8D8;padding:20px 32px;border-radius:0 0 12px 12px;border:0.5px solid rgba(107,152,141,0.15);border-top:none;text-align:center;">
    <p style="font-size:12px;color:#6B988D;font-style:italic;margin:0 0 8px 0;">Lis. Partage. Reviens demain.</p>
    <p style="font-size:11px;color:#999;margin:0;line-height:1.6;">Tu reçois cet email car les notifications de commentaires sont activées sur LexDay.<br>Tu peux les désactiver dans les réglages de l'app.</p>
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
        to: payload.to_email,
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
