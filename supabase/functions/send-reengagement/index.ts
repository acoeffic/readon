// Supabase Edge Function — relances de re-engagement (win-back)
// Appelée toutes les heures par pg_cron. Pour chaque utilisateur dont
// l'heure locale est REENGAGE_HOUR, on regarde depuis combien de jours il
// n'a pas lu et on envoie une relance aux paliers 3 / 7 / 14 jours — une
// seule fois par palier (anti-spam via profiles.reengagement_last_bucket).
//
// 19/08/2026 — ajout de la piste "activation".
// Jusqu'ici `if (!lastSession?.end_time) continue` excluait les inscrits qui
// n'ont jamais démarré de session, c'est-à-dire 21 des 26 inscrits d'août :
// la fonction n'a donc jamais envoyé un seul message (reengagement_last_bucket
// = 0 sur les 55 profils). Ces utilisateurs sont désormais traités avec une
// référence temporelle différente (1er livre ajouté, sinon inscription) et des
// messages qui parlent de leur livre, jamais de "flow" — ils n'en ont pas.
// Ils sont par ailleurs exclus du rappel quotidien de send-streak-reminders :
// cette fonction est leur unique canal, plafonné à 3 messages puis silence.
//
// 02/09/2026 — piste "activation" resserrée à J+1 / J+3 / J+7, avec e-mail.
// Diagnostic : les 13 inscrits d'août avec un livre et 0 session avaient TOUS
// leur dernière connexion le jour de l'inscription. Le premier contact à J+3
// (puis J+7, J+14) arrivait après la mort du compte, et 8 des 13 n'avaient
// pas de token push (la permission n'est demandée qu'après la 1re session) :
// ils n'ont jamais rien reçu. Désormais : J+1 en priorité, push si on a un
// token, sinon e-mail (Resend) pour ceux qui ont ajouté un livre — l'e-mail
// est confirmé à 100 % et c'est le seul canal qui reste.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// PostgREST cape chaque SELECT à 1000 lignes. Sans pagination, au-delà de
// 1000 profils éligibles le reste est silencieusement ignoré. Ce helper
// parcourt toutes les pages via .range(). La factory doit fournir un
// .order(...) stable + .range(from, to).
async function fetchAllRows<T>(
  makeQuery: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>,
  pageSize = 1000,
): Promise<T[]> {
  const rows: T[] = []
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await makeQuery(from, from + pageSize - 1)
    if (error) throw error
    if (!data || data.length === 0) break
    rows.push(...data)
    if (data.length < pageSize) break
  }
  return rows
}

// Heure locale (24h) à laquelle on envoie les relances.
const REENGAGE_HOUR = 10
// Paliers d'inactivité (en jours) — ordre croissant.
const BUCKETS = [3, 7, 14]
// Paliers de la piste "activation" (jours depuis le 1er livre / l'inscription).
// Le message n° step part dès que daysSince >= ACTIVATION_BUCKETS[step].
const ACTIVATION_BUCKETS = [1, 3, 7]
// Au-delà de ce nombre de jours depuis la référence, on ne relance plus du
// tout : un compte mort depuis des semaines ne se réveille pas, et le premier
// contact serait un adieu.
const ACTIVATION_MAX_DAYS = 14
// Espacement minimum entre deux messages de la séquence d'activation.
const ACTIVATION_MIN_GAP_DAYS = 2
// Expéditeur des e-mails de relance (même domaine que les autres e-mails).
const EMAIL_FROM = 'LexDay <hello@lexday.fr>'
const READ_LINK = 'https://www.lexday.fr/redirect?to=read'

// ── FCM v1 auth ──

const FCM_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!)

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: FCM_SERVICE_ACCOUNT.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const header = { alg: 'RS256', typ: 'JWT' }
  const encoder = new TextEncoder()
  const toBase64 = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const unsignedToken = `${toBase64(header)}.${toBase64(payload)}`

  const privateKey = FCM_SERVICE_ACCOUNT.private_key
  const pemBody = privateKey.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')
  const binaryKey = Uint8Array.from(atob(pemBody), (c: string) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign']
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(unsignedToken)
  )

  const signedToken = `${unsignedToken}.${btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${signedToken}`,
  })

  const { access_token } = await res.json()
  return access_token
}

interface FCMResult {
  success: boolean
  unregistered: boolean
}

async function sendFCMNotification(
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<FCMResult> {
  const projectId = FCM_SERVICE_ACCOUNT.project_id

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data,
          android: {
            notification: { sound: 'default', channel_id: 'reading_reminder' },
          },
          apns: {
            payload: { aps: { sound: 'default' } },
          },
        },
      }),
    }
  )

  if (!response.ok) {
    const errorText = await response.text()
    const isUnregistered = errorText.includes('UNREGISTERED') ||
      errorText.includes('NOT_FOUND') ||
      errorText.includes('INVALID_ARGUMENT')
    if (isUnregistered) return { success: false, unregistered: true }
    throw new Error(`FCM request failed: ${errorText}`)
  }

  return { success: true, unregistered: false }
}

// ── E-mail (Resend) ──

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}

interface ActivationBook {
  title: string
  author: string | null
  cover_url: string | null
}

/**
 * E-mail de relance "activation" : même charte que send-friend-request-email,
 * centré sur LE livre ajouté, un seul bouton. `step` suit la même sémantique
 * que buildActivationMessage (0 = premier contact, 2 = dernier).
 */
function buildActivationEmail(
  step: number,
  displayName: string | null,
  book: ActivationBook,
  daysSince: number,
): { subject: string; html: string } {
  // « Hier » n'est vrai que pour un vrai J+1 ; un inscrit rattrapé plus tard
  // (déploiement, token mort) reçoit une formulation neutre.
  const when = daysSince <= 1 ? 'Hier' : 'Il y a quelques jours'
  const name = escapeHtml((displayName ?? '').trim() || 'toi')
  const title = escapeHtml(book.title)
  const author = book.author ? escapeHtml(book.author) : null
  const cover = book.cover_url && /^https:\/\//.test(book.cover_url)
    ? book.cover_url.replace(/"/g, '')
    : null

  let subject: string
  let kicker: string
  let headline: string
  let paragraph: string
  let cta: string
  if (step >= 2) {
    subject = `Pas le bon moment pour « ${book.title} » ?`
    kicker = 'Dernier rappel'
    headline = `« ${title} »<br>reste dans ta bibliothèque`
    paragraph = `On arrête de te relancer, promis. Si l'envie revient, ton livre t'attend au même endroit — et 5 minutes suffisent pour la première session.`
    cta = 'Reprendre quand je veux'
  } else if (step === 1) {
    subject = `« ${book.title} » n'a pas bougé`
    kicker = 'Ta première session'
    headline = `Cinq minutes,<br>c'est tout ce qu'il faut`
    paragraph = `Tu as ajouté « <strong style="color:#1a1a1a;">${title}</strong> » mais tu n'as pas encore lancé de session. Ouvre l'app, appuie sur Lire, pose ton téléphone : LexDay chronomètre le reste.`
    cta = 'Lire 5 minutes'
  } else {
    subject = `« ${book.title} » t'attend`
    kicker = 'Ta première session'
    headline = `Et si tu lisais<br>5 minutes ce soir ?`
    paragraph = `${when} tu as ajouté « <strong style="color:#1a1a1a;">${title}</strong> » dans LexDay. Il ne manque que la première session — 5 minutes suffisent, tu peux t'arrêter quand tu veux.`
    cta = 'Lire 5 minutes maintenant'
  }

  const coverCell = cover
    ? `<td style="width:56px;vertical-align:top;"><img src="${cover}" width="56" height="84" alt="" style="display:block;width:56px;height:84px;object-fit:cover;border-radius:6px;"></td>`
    : `<td style="width:56px;height:84px;border-radius:6px;background:#6B988D;text-align:center;vertical-align:middle;font-size:22px;color:#FAF3E8;">📖</td>`

  const html = `
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
    <p style="font-size:13px;font-weight:500;color:#6B988D;letter-spacing:0.08em;text-transform:uppercase;margin:0 0 10px 0;">${kicker}</p>
    <h1 style="font-size:26px;font-weight:400;color:#1a1a1a;margin:0 0 24px 0;line-height:1.3;">${headline}</h1>

    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;border:0.5px solid rgba(0,0,0,0.07);margin-bottom:28px;">
      <tr><td style="padding:18px 20px;">
        <table cellpadding="0" cellspacing="0"><tr>
          ${coverCell}
          <td style="padding-left:16px;vertical-align:middle;">
            <div style="font-size:16px;font-weight:500;color:#1a1a1a;">${title}</div>
            ${author ? `<div style="font-size:13px;color:#999;margin-top:2px;">${author}</div>` : ''}
            <div style="font-size:12px;color:#6B988D;margin-top:8px;">0 session · en attente</div>
          </td>
        </tr></table>
      </td></tr>
    </table>

    <p style="font-size:15px;color:#555;line-height:1.7;margin:0 0 28px 0;">
      Salut <strong style="color:#1a1a1a;">${name}</strong>&nbsp;! ${paragraph}
    </p>

    <p style="text-align:center;margin:0;">
      <a href="${READ_LINK}" style="display:inline-block;background:#6B988D;color:#FAF3E8;text-decoration:none;font-size:15px;font-weight:500;padding:14px 36px;border-radius:50px;">${cta}</a>
    </p>
  </td></tr>

  <tr><td style="background:#F0E8D8;padding:20px 32px;border-radius:0 0 12px 12px;border:0.5px solid rgba(107,152,141,0.15);border-top:none;text-align:center;">
    <p style="font-size:12px;color:#6B988D;font-style:italic;margin:0 0 8px 0;">Lis. Partage. Reviens demain.</p>
    <p style="font-size:11px;color:#999;margin:0;line-height:1.6;">Tu reçois cet e-mail parce que tu as créé un compte LexDay et ajouté un livre.<br>Au maximum trois rappels, puis plus rien. Tu peux aussi désactiver les notifications dans les réglages de l'app.</p>
  </td></tr>

</table>
</td></tr></table>
</body>
</html>`
  return { subject, html }
}

async function sendActivationEmail(
  to: string,
  subject: string,
  html: string,
): Promise<void> {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  if (!apiKey) throw new Error('RESEND_API_KEY manquant')
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ from: EMAIL_FROM, to, subject, html }),
  })
  if (!res.ok) {
    throw new Error(`Resend ${res.status}: ${await res.text()}`)
  }
}

// ── Date helpers ──

const fmt = (d: Date) => d.toISOString().split('T')[0]

/** Décalage minutes de la timezone par rapport à UTC, maintenant. */
function tzOffsetMinutes(timezone: string | null): number {
  const tz = timezone || 'Europe/Paris'
  const now = new Date()
  const utcDate = new Date(now.toLocaleString('en-US', { timeZone: 'UTC' }))
  const tzDate = new Date(now.toLocaleString('en-US', { timeZone: tz }))
  return Math.round((tzDate.getTime() - utcDate.getTime()) / 60000)
}

/** Heure locale (0-23) de l'utilisateur. */
function localHour(timezone: string | null): number {
  const tz = timezone || 'Europe/Paris'
  const local = new Date(new Date().toLocaleString('en-US', { timeZone: tz }))
  return local.getHours()
}

/** Nombre de jours pleins entre une date de référence (locale) et aujourd'hui. */
function daysBetween(todayKey: string, refKey: string): number {
  return Math.floor(
    (new Date(`${todayKey}T00:00:00Z`).getTime() -
      new Date(`${refKey}T00:00:00Z`).getTime()) / 86400000
  )
}

/**
 * Streak (jours consécutifs) se terminant à la date `endKey` incluse.
 * Sert à dire à l'utilisateur quel flow il a laissé filer.
 */
function streakEndingAt(
  validDays: Set<string>,
  endKey: string
): number {
  let cursor = new Date(`${endKey}T00:00:00Z`)
  let streak = 0
  while (validDays.has(fmt(cursor))) {
    streak++
    cursor.setUTCDate(cursor.getUTCDate() - 1)
  }
  return streak
}

// ── Messages ──

function buildMessage(
  bucket: number,
  lostStreak: number,
  bookTitle: string | null
): { title: string, body: string } {
  // Personnalisation par flow perdu si présent.
  if (lostStreak >= 3) {
    if (bucket >= 14) {
      return {
        title: `📚 Ton flow de ${lostStreak} jours t'attend toujours`,
        body: 'Reprends quand tu veux — une seule page suffit pour repartir.',
      }
    }
    if (bucket >= 7) {
      return {
        title: `🔥 Tu avais un flow de ${lostStreak} jours !`,
        body: 'Ça se reconstruit vite. Et si tu repartais ce soir ?',
      }
    }
    return {
      title: `📖 Ton flow de ${lostStreak} jours s'est mis en pause`,
      body: bookTitle
        ? `Reprends « ${bookTitle} » et relance ta série.`
        : 'Quelques pages aujourd\'hui et c\'est reparti.',
    }
  }

  // Sans flow notable : on parle du livre en cours.
  if (bucket >= 14) {
    return {
      title: '📚 Et si on reprenait la lecture ?',
      body: bookTitle
        ? `« ${bookTitle} » n'attend que toi.`
        : 'Ton prochain chapitre est à portée de main.',
    }
  }
  if (bucket >= 7) {
    return {
      title: '📖 Ça fait un moment !',
      body: bookTitle
        ? `Reprends « ${bookTitle} » là où tu t'es arrêté.`
        : 'Reprends ta lecture là où tu t\'es arrêté.',
    }
  }
  return {
    title: '📖 Ton livre t\'attend',
    body: bookTitle
      ? `Quelques pages de « ${bookTitle} » aujourd'hui ?`
      : 'Prends un moment pour lire quelques pages aujourd\'hui.',
  }
}

/**
 * Messages "activation" : l'utilisateur s'est inscrit et n'a JAMAIS démarré de
 * session. On ne lui parle jamais de flow (il n'en a pas) — on lui parle du
 * livre qu'il a ajouté, parce que c'est la seule chose qu'il a faite chez nous
 * et que la nommer prouve qu'on s'en souvient. Le dernier message assume de le
 * laisser partir plutôt que de continuer à insister.
 *
 * ⚠️ Indexé sur `step` (0, 1, 2 = combien de messages ont DÉJÀ été envoyés),
 * PAS sur l'ancienneté du compte. Un inscrit découvert au 15e jour doit
 * recevoir le message d'accueil en premier, jamais l'adieu en guise de
 * premier contact.
 */
function buildActivationMessage(
  step: number,
  bookTitle: string | null,
  daysSince: number,
): { title: string, body: string } {
  const when = daysSince <= 1 ? 'Hier' : 'L\'autre jour'
  if (bookTitle) {
    if (step >= 2) {
      return {
        title: '📚 Pas le bon moment ?',
        body: `« ${bookTitle} » reste dans ta bibliothèque. On arrête de te relancer — reviens quand tu veux.`,
      }
    }
    if (step === 1) {
      return {
        title: `📖 « ${bookTitle} » n'a pas bougé`,
        body: 'Une session de 5 minutes suffit pour t\'y remettre. On chronomètre le reste.',
      }
    }
    return {
      title: `📖 « ${bookTitle} » t'attend`,
      body: `${when} tu l'as ajouté — 5 minutes de lecture ce soir ? Lance ta première session, on chronomètre le reste.`,
    }
  }

  // Aucun livre ajouté : c'est l'étape d'avant qu'il faut débloquer.
  if (step >= 2) {
    return {
      title: '📚 On te laisse tranquille',
      body: 'Si l\'envie revient : un livre scanné et tu peux commencer.',
    }
  }
  if (step === 1) {
    return {
      title: '📚 Ajoute le livre que tu lis',
      body: 'Scanne sa couverture, et LexDay chronomètre ta prochaine lecture.',
    }
  }
  return {
    title: '📚 Quel livre lis-tu en ce moment ?',
    body: 'Ajoute-le en 10 secondes pour démarrer ta première session.',
  }
}

interface Profile {
  id: string
  display_name: string
  email: string | null
  fcm_token: string | null
  timezone: string | null
  reengagement_last_bucket: number
  reengagement_last_sent_at: string | null
  created_at: string
}

// ── Main handler ──

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const cronSecret = Deno.env.get('CRON_SECRET')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const token = (req.headers.get('authorization') ?? '').replace('Bearer ', '')
  const isAuthorized = (cronSecret && token === cronSecret) ||
    (serviceRoleKey && token === serviceRoleKey)
  if (!isAuthorized) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const now = new Date()
    const todayKey = fmt(now)

    const profiles = await fetchAllRows<Profile>((from, to) =>
      supabase
        .from('profiles')
        .select('id, display_name, email, fcm_token, timezone, reengagement_last_bucket, reengagement_last_sent_at, created_at')
        .eq('notifications_enabled', true)
        // Plus de filtre sur fcm_token : la piste "activation" a un canal
        // e-mail. La piste win-back reste push-only (filtrée plus bas).
        .order('id', { ascending: true })
        .range(from, to)
    )

    if (profiles.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Ne traiter que les utilisateurs dont l'heure locale est REENGAGE_HOUR.
    const dueUsers = (profiles as Profile[]).filter(
      (p) => localHour(p.timezone) === REENGAGE_HOUR
    )

    if (dueUsers.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0, window: 'off-hour' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    let accessToken: string | null = null
    let sent = 0
    let activated = 0
    let activatedByEmail = 0
    let reset = 0
    let skipped = 0
    let cleaned = 0

    for (const user of dueUsers) {
      try {
        // Dernière activité = dernière session de lecture terminée.
        const { data: lastSession } = await supabase
          .from('reading_sessions')
          .select('end_time, books(title)')
          .eq('user_id', user.id)
          .not('end_time', 'is', null)
          .order('end_time', { ascending: false })
          .limit(1)
          .maybeSingle()

        const offset = tzOffsetMinutes(user.timezone)

        // ── Piste "activation" : jamais démarré une seule session ──
        if (!lastSession?.end_time) {
          // Référence = 1er livre ajouté (signal d'intention le plus fort),
          // sinon date d'inscription.
          const { data: firstBook } = await supabase
            .from('user_books')
            .select('created_at, books(title, author, cover_url)')
            .eq('user_id', user.id)
            .order('created_at', { ascending: true })
            .limit(1)
            .maybeSingle()

          const refIso = firstBook?.created_at ?? user.created_at
          if (!refIso) { skipped++; continue }

          const refLocal = new Date(new Date(refIso).getTime() + offset * 60000)
          const daysSince = daysBetween(todayKey, fmt(refLocal))

          // Compte trop ancien pour qu'une relance ait du sens.
          if (daysSince > ACTIVATION_MAX_DAYS) { skipped++; continue }

          // Séquence de 3 messages indexée sur ce qui a DÉJÀ été envoyé, pas
          // sur l'ancienneté du compte : un inscrit découvert au 5e jour doit
          // recevoir le message d'accueil en premier, jamais l'adieu.
          // reengagement_last_bucket ∈ {0, 1, 3, 7} → step ∈ {0, 1, 2, 3}.
          // Une valeur héritée de l'ancienne séquence (14) = séquence close.
          const last = user.reengagement_last_bucket
          const step = last === 0
            ? 0
            : ACTIVATION_BUCKETS.includes(last) ? ACTIVATION_BUCKETS.indexOf(last) + 1 : ACTIVATION_BUCKETS.length
          if (step >= ACTIVATION_BUCKETS.length) { skipped++; continue } // 3 messages envoyés → silence définitif

          const target = ACTIVATION_BUCKETS[step]
          if (daysSince < target) { skipped++; continue }

          // Espacement minimum entre deux messages de la séquence.
          if (user.reengagement_last_sent_at) {
            const lastSentLocal = new Date(
              new Date(user.reengagement_last_sent_at).getTime() + offset * 60000
            )
            if (daysBetween(todayKey, fmt(lastSentLocal)) < ACTIVATION_MIN_GAP_DAYS) {
              skipped++; continue
            }
          }

          const bookRow = firstBook?.books as ActivationBook | null | undefined
          const bookTitle = bookRow?.title || null

          // Canal : push si on a un token, sinon e-mail — mais l'e-mail est
          // réservé à ceux qui ont ajouté un livre (signal d'intention réel ;
          // relancer par e-mail un compte vide serait du spam).
          let channel: 'push' | 'email' | null = null
          if (user.fcm_token) {
            const { title, body } = buildActivationMessage(step, bookTitle, daysSince)
            if (!accessToken) accessToken = await getAccessToken()
            const result = await sendFCMNotification(accessToken, user.fcm_token, title, body, {
              type: 'activation',
              user_id: user.id,
              bucket: String(target),
            })
            if (result.unregistered) {
              await supabase.from('profiles').update({ fcm_token: null }).eq('id', user.id)
              cleaned++
              // Le token était mort : on retombe sur l'e-mail ci-dessous.
            } else {
              channel = 'push'
            }
          }
          if (!channel && user.email && bookRow?.title) {
            const { subject, html } = buildActivationEmail(step, user.display_name, bookRow, daysSince)
            await sendActivationEmail(user.email, subject, html)
            channel = 'email'
          }
          if (!channel) { skipped++; continue }

          await supabase
            .from('profiles')
            .update({
              reengagement_last_bucket: target,
              reengagement_last_sent_at: new Date().toISOString(),
            })
            .eq('id', user.id)
          activated++
          if (channel === 'email') activatedByEmail++
          console.log(`✅ Activation msg ${step + 1}/3 (J+${daysSince}, ${channel}) → ${user.display_name} (livre: ${bookTitle ?? '—'})`)
          continue
        }

        // ── Piste "win-back lecteur" : push uniquement ──
        if (!user.fcm_token) { skipped++; continue }

        // ── Piste "win-back lecteur" : a déjà lu, mais plus depuis N jours ──
        const lastLocal = new Date(
          new Date(lastSession.end_time).getTime() + offset * 60000
        )
        const lastKey = fmt(lastLocal)

        const daysInactive = daysBetween(todayKey, lastKey)

        // Redevenu actif (< plus petit palier) → on réarme le compteur.
        if (daysInactive < BUCKETS[0]) {
          if (user.reengagement_last_bucket !== 0) {
            await supabase
              .from('profiles')
              .update({ reengagement_last_bucket: 0 })
              .eq('id', user.id)
            reset++
          }
          continue
        }

        // Palier cible = plus grand palier atteint.
        let target = 0
        for (const b of BUCKETS) if (daysInactive >= b) target = b

        // Déjà relancé à ce palier (ou plus) → ne pas spammer.
        if (target <= user.reengagement_last_bucket) { skipped++; continue }

        // Calcul du flow laissé filer (streak se terminant au dernier jour lu).
        const { data: sessions } = await supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', user.id)
          .not('end_time', 'is', null)
        const { data: freezes } = await supabase
          .from('streak_freezes')
          .select('frozen_date')
          .eq('user_id', user.id)

        const validDays = new Set<string>([
          ...(sessions || []).map((s) => {
            const local = new Date(new Date(s.end_time).getTime() + offset * 60000)
            return fmt(local)
          }),
          ...(freezes || []).map((f) => f.frozen_date as string),
        ])
        const lostStreak = streakEndingAt(validDays, lastKey)

        const bookTitle =
          (lastSession.books && (lastSession.books as { title?: string }).title) || null

        const { title, body } = buildMessage(target, lostStreak, bookTitle)

        if (!accessToken) accessToken = await getAccessToken()
        const result = await sendFCMNotification(accessToken, user.fcm_token, title, body, {
          type: 'reengagement',
          user_id: user.id,
          bucket: String(target),
        })

        if (result.unregistered) {
          await supabase.from('profiles').update({ fcm_token: null }).eq('id', user.id)
          cleaned++
          continue
        }

        await supabase
          .from('profiles')
          .update({
            reengagement_last_bucket: target,
            reengagement_last_sent_at: new Date().toISOString(),
          })
          .eq('id', user.id)
        sent++
        console.log(`✅ Relance J+${target} → ${user.display_name} (flow perdu: ${lostStreak})`)
      } catch (e) {
        console.error(`❌ Erreur pour ${user.id}:`, e)
      }
    }

    const result = { success: true, due: dueUsers.length, sent, activated, activatedByEmail, reset, skipped, cleaned }
    console.log('📊 Re-engagement:', result)
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('❌ Erreur:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
