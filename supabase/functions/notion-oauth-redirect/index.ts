// supabase/functions/notion-oauth-redirect/index.ts
//
// HTTPS bridge for the Notion OAuth flow.
//
// Notion does not accept custom URI schemes (like `lexday://`) as a
// `redirect_uri`. So we register THIS function's HTTPS URL with Notion
// instead, and when Notion redirects the user here with the auth `code`,
// we forward them to the app via the custom scheme deep link.
//
// Registered redirect_uri in Notion integration settings:
//   https://<project>.supabase.co/functions/v1/notion-oauth-redirect
//
// The app side (NotionService) must use that same HTTPS URL as
// `redirect_uri` both in `getOAuthUrl()` and when calling
// `notion-oauth-callback` to exchange the code (Notion verifies the
// redirect_uri matches between authorize and token requests).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const APP_DEEP_LINK = "lexday://notion/callback";

function htmlResponse(title: string, message: string, deepLink?: string) {
  const meta = deepLink
    ? `<meta http-equiv="refresh" content="0; url=${deepLink}">`
    : "";
  const linkBlock = deepLink
    ? `<p>Si l'application ne s'ouvre pas automatiquement, <a href="${deepLink}">cliquez ici</a>.</p>`
    : "";
  return new Response(
    `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  ${meta}
  <title>${title}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
           max-width: 480px; margin: 80px auto; padding: 0 24px; text-align: center;
           color: #2f3437; }
    h1 { font-size: 20px; }
    p  { font-size: 15px; line-height: 1.5; color: #6b6f76; }
  </style>
</head>
<body>
  <h1>${title}</h1>
  <p>${message}</p>
  ${linkBlock}
</body>
</html>`,
    { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } },
  );
}

serve((req) => {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");
  const state = url.searchParams.get("state");

  // User refused or Notion sent an error.
  if (error) {
    const target = `${APP_DEEP_LINK}?error=${encodeURIComponent(error)}`;
    return htmlResponse(
      "Connexion annulée",
      "L'autorisation Notion a été refusée. Vous pouvez fermer cet onglet.",
      target,
    );
  }

  if (!code) {
    return htmlResponse(
      "Code manquant",
      "Aucun code d'autorisation reçu de Notion. Réessayez depuis l'application.",
    );
  }

  const params = new URLSearchParams({ code });
  if (state) params.set("state", state);
  const target = `${APP_DEEP_LINK}?${params.toString()}`;

  // 302 redirect to the app's custom scheme. iOS / Android will catch it
  // and reopen LexDay, where deep_link_service.dart hands the code to
  // NotionService.exchangeCode().
  return new Response(null, {
    status: 302,
    headers: {
      Location: target,
      // Fallback HTML in case the browser doesn't follow the 302 to a
      // non-http scheme — some embedded browsers refuse.
      "Cache-Control": "no-store",
    },
  });
});
