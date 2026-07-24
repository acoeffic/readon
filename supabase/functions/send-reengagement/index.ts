// Supabase Edge Function — relances de re-engagement (win-back)
// Appelée toutes les heures par pg_cron. Pour chaque utilisateur dont
// l'heure locale est REENGAGE_HOUR, on regarde depuis combien de jours il
// n'a pas lu et on envoie une relance aux paliers 3 / 7 / 14 jours — une
// seule fois par palier (anti-spam via profiles.reengagement_last_bucket).

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

interface Profile {
  id: string
  display_name: string
  fcm_token: string
  timezone: string | null
  reengagement_last_bucket: number
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
        .select('id, display_name, fcm_token, timezone, reengagement_last_bucket')
        .eq('notifications_enabled', true)
        .not('fcm_token', 'is', null)
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

        // Jamais lu → hors scope de la relance "win-back lecteur".
        if (!lastSession?.end_time) { skipped++; continue }

        const offset = tzOffsetMinutes(user.timezone)
        const lastLocal = new Date(
          new Date(lastSession.end_time).getTime() + offset * 60000
        )
        const lastKey = fmt(lastLocal)

        const daysInactive = Math.floor(
          (new Date(`${todayKey}T00:00:00Z`).getTime() -
            new Date(`${lastKey}T00:00:00Z`).getTime()) / 86400000
        )

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

    const result = { success: true, due: dueUsers.length, sent, reset, skipped, cleaned }
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
