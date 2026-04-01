import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;

    if (!record || record.type !== "friend_request") {
      return new Response("Ignored", { status: 200 });
    }

    const recipientId = record.user_id;
    const senderId = record.from_user_id;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Profils
    const [{ data: recipient }, { data: sender }] = await Promise.all([
      supabase.from("profiles").select("display_name, email_friend_requests").eq("id", recipientId).single(),
      supabase.from("profiles").select("display_name").eq("id", senderId).single(),
    ]);

    if (!recipient || !sender) {
      return new Response("Profile not found", { status: 200 });
    }

    if (!recipient.email_friend_requests) {
      return new Response("Notifications disabled", { status: 200 });
    }

    // Email depuis auth.users
    const { data: authUser } = await supabase.auth.admin.getUserById(recipientId);
    const recipientEmail = authUser?.user?.email;

    if (!recipientEmail) {
      return new Response("No email found", { status: 200 });
    }

    const htmlContent = `
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F0E8D8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px;">
<table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;">

  <tr><td style="background:#6B988D;padding:28px 32px;border-radius:12px 12px 0 0;text-align:center;">
    <img src="https://nzbhmshkcwudzydeahrq.supabase.co/storage/v1/object/public/asset/Image/WhatsApp%20Image%202026-03-18%20at%2010.05.09.jpeg" width="32" height="32" alt="LexDay" style="vertical-align:middle;margin-right:10px;">
    <span style="font-size:20px;font-weight:500;color:#FAF3E8;letter-spacing:-0.3px;vertical-align:middle;">LexDay</span>
  </td></tr>

  <tr><td style="background:#FAF3E8;padding:36px 32px 28px;border-left:1px solid rgba(107,152,141,0.15);border-right:1px solid rgba(107,152,141,0.15);">
    <p style="font-size:13px;font-weight:500;color:#6B988D;letter-spacing:0.08em;text-transform:uppercase;margin:0 0 10px 0;">Nouvelle demande d'ami</p>
    <h1 style="font-size:26px;font-weight:400;color:#1a1a1a;margin:0 0 24px 0;line-height:1.3;">${sender.display_name} veut<br>te suivre sur LexDay</h1>

    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;border:0.5px solid rgba(0,0,0,0.07);margin-bottom:28px;">
      <tr><td style="padding:18px 20px;">
        <table cellpadding="0" cellspacing="0"><tr>
          <td style="width:52px;height:52px;border-radius:50%;background:#6B988D;text-align:center;vertical-align:middle;font-size:20px;font-weight:500;color:#FAF3E8;">${sender.display_name.charAt(0).toUpperCase()}</td>
          <td style="padding-left:16px;">
            <div style="font-size:16px;font-weight:500;color:#1a1a1a;">${sender.display_name}</div>
            <div style="font-size:13px;color:#999;margin-top:2px;">souhaite suivre tes lectures</div>
          </td>
        </tr></table>
      </td></tr>
    </table>

    <p style="font-size:15px;color:#555;line-height:1.7;margin:0 0 28px 0;">
      Salut <strong style="color:#1a1a1a;">${recipient.display_name}</strong>&nbsp;! Accepte la demande pour partager vos lectures, commenter vos sessions et vous motiver mutuellement.
    </p>

    <p style="text-align:center;margin:0 0 12px 0;">
      <a href="https://www.lexday.fr/redirect?to=friends/requests" style="display:inline-block;background:#6B988D;color:#FAF3E8;text-decoration:none;font-size:15px;font-weight:500;padding:14px 36px;border-radius:50px;">Accepter la demande</a>
    </p>
    <p style="text-align:center;margin:0;">
      <a href="https://www.lexday.fr/redirect?to=friends/requests" style="font-size:13px;color:#6B988D;text-decoration:none;">Refuser</a>
    </p>
  </td></tr>

  <tr><td style="background:#F0E8D8;padding:20px 32px;border-radius:0 0 12px 12px;border:0.5px solid rgba(107,152,141,0.15);border-top:none;text-align:center;">
    <p style="font-size:12px;color:#6B988D;font-style:italic;margin:0 0 8px 0;">Lis. Partage. Reviens demain.</p>
    <p style="font-size:11px;color:#999;margin:0;line-height:1.6;">Tu reçois cet email car les notifications sont activées sur LexDay.<br>Tu peux les désactiver dans les réglages de l'app.</p>
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
        to: recipientEmail,
        subject: `${sender.display_name} veut t'ajouter comme ami sur LexDay`,
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