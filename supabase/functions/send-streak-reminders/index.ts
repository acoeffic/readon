// Supabase Edge Function pour envoyer les rappels de streak quotidien
// Appelée toutes les 15 minutes par pg_cron — filtre les utilisateurs
// dont l'heure de rappel tombe dans la fenêtre courante.
//
// 19/08/2026 — deux changements :
//  1. Les utilisateurs qui n'ont JAMAIS terminé de session sont exclus du
//     rappel quotidien. Rappeler chaque soir « continue ta série » à
//     quelqu'un qui n'a jamais lu est du nag pur (11 suppressions depuis le
//     2 août pour 5 activations). Ils sont pris en charge par
//     send-reengagement, piste "activation", plafonnée à 3 messages.
//  2. Rétablissement de l'écriture dans streak_notification_log, disparue
//     lors d'un redéploiement (dernière ligne : 07/07/2026) — sans elle on
//     est aveugle sur ce qui part réellement.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// PostgREST cape chaque SELECT à 1000 lignes. Sans pagination, au-delà de
// 1000 lignes le reste est silencieusement ignoré (utilisateurs jamais
// notifiés, ou lecteurs actifs notifiés à tort). Ce helper parcourt toutes
// les pages via .range(). La factory doit fournir un .order(...) stable.
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
  response?: any
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
            notification: {
              sound: 'default',
              channel_id: 'streak_reminder',
            },
          },
          apns: {
            payload: {
              aps: { sound: 'default' },
            },
          },
        },
      }),
    }
  )

  if (!response.ok) {
    const errorText = await response.text()
    // Detect unregistered / invalid token
    const isUnregistered = errorText.includes('UNREGISTERED') ||
      errorText.includes('NOT_FOUND') ||
      errorText.includes('INVALID_ARGUMENT')
    if (isUnregistered) {
      return { success: false, unregistered: true }
    }
    throw new Error(`FCM request failed: ${errorText}`)
  }

  return { success: true, unregistered: false, response: await response.json() }
}

// ── Calcul du flow (streak) depuis reading_sessions + streak_freezes ──
// Reproduit la logique Flutter : jours consécutifs en remontant depuis aujourd'hui/hier

function calculateCurrentFlow(
  sessionDates: string[],   // format 'YYYY-MM-DD'
  frozenDates: string[]     // format 'YYYY-MM-DD'
): number {
  const validDays = new Set([...sessionDates, ...frozenDates])
  if (validDays.size === 0) return 0

  const today = new Date()
  today.setUTCHours(0, 0, 0, 0)

  const fmt = (d: Date) => d.toISOString().split('T')[0]

  // Tolérance : si aujourd'hui n'est pas lu, on commence à hier
  let cursor = new Date(today)
  if (!validDays.has(fmt(cursor))) {
    cursor.setUTCDate(cursor.getUTCDate() - 1)
    if (!validDays.has(fmt(cursor))) return 0
  }

  let flow = 0
  while (validDays.has(fmt(cursor))) {
    flow++
    cursor.setUTCDate(cursor.getUTCDate() - 1)
  }

  return flow
}

// ── Notification messages ──

interface Profile {
  id: string
  display_name: string
  fcm_token: string
  notification_reminder_time: string
  notification_days: number[] | null
  timezone: string | null
}

// Heure locale de la notification "dernière chance" (streak > 0 et pas encore lu).
// Indépendante de l'heure de rappel choisie par l'utilisateur.
const LAST_CHANCE_TIME = '21:30'

function getLastChanceMessage(streak: number): { title: string, body: string } {
  return {
    title: `⏰ Ton flow de ${streak} jour${streak > 1 ? 's' : ''} expire à minuit !`,
    body: 'Quelques pages suffisent pour le sauver. 🔥',
  }
}

function getNotificationMessage(streak: number, displayName: string): { title: string, body: string } {
  const name = displayName || 'Lecteur'
  if (streak === 0) {
    // NB : n'est plus jamais envoyé à un inscrit qui n'a jamais lu (filtre
    // everRead plus bas). Ne concerne donc qu'un lecteur dont la série est
    // retombée à 0 — là, le rappel a du sens.
    return {
      title: "📚 Reprends ton flow aujourd'hui !",
      body: `Salut ${name} ! Quelques pages suffisent pour relancer ta série.`
    }
  } else if (streak < 7) {
    return {
      title: `🔥 Ne perds pas ton flow de ${streak} jour${streak > 1 ? 's' : ''} !`,
      body: "Continue ta progression, lis un peu aujourd'hui !"
    }
  } else if (streak < 30) {
    return {
      title: `🔥 Impressionnant ! ${streak} jours de suite !`,
      body: "Tu es sur une belle lancée, ne t'arrête pas maintenant !"
    }
  } else {
    return {
      title: `🏆 ${streak} jours consécutifs ! Incroyable !`,
      body: "Tu es une légende ! Continue ton incroyable série."
    }
  }
}

/**
 * Convert local reminder time to UTC using IANA timezone,
 * then check if it falls in the current 15-min UTC window.
 */
function isInCurrentWindow(
  reminderTime: string,
  timezone: string | null,
  nowUtcHours: number,
  nowUtcMinutes: number
): boolean {
  const parts = reminderTime.split(':')
  if (parts.length !== 2) return false
  const localHour = parseInt(parts[0], 10)
  const localMinute = parseInt(parts[1], 10)
  if (isNaN(localHour) || isNaN(localMinute)) return false

  const tz = timezone || 'Europe/Paris'

  // Build a Date object for "today at localHour:localMinute in the user's tz"
  // We use Intl to figure out the UTC offset for that timezone right now.
  const now = new Date()
  const utcString = now.toLocaleString('en-US', { timeZone: 'UTC' })
  const tzString = now.toLocaleString('en-US', { timeZone: tz })
  const utcDate = new Date(utcString)
  const tzDate = new Date(tzString)
  // offset in minutes: positive means tz is ahead of UTC (e.g. +120 for Europe/Paris in summer)
  const offsetMinutes = Math.round((tzDate.getTime() - utcDate.getTime()) / 60000)

  // Convert local reminder time to UTC minutes-of-day
  const localTotalMinutes = localHour * 60 + localMinute
  let utcTotalMinutes = localTotalMinutes - offsetMinutes
  // Wrap around midnight
  if (utcTotalMinutes < 0) utcTotalMinutes += 1440
  if (utcTotalMinutes >= 1440) utcTotalMinutes -= 1440

  const utcReminderHour = Math.floor(utcTotalMinutes / 60)
  const utcReminderMinute = utcTotalMinutes % 60

  const windowStart = nowUtcMinutes - (nowUtcMinutes % 15)
  return utcReminderHour === nowUtcHours && utcReminderMinute >= windowStart && utcReminderMinute < windowStart + 15
}

// ── Main handler ──

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Accept either CRON_SECRET or SUPABASE_SERVICE_ROLE_KEY for auth
  const cronSecret = Deno.env.get('CRON_SECRET')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const authorization = req.headers.get('authorization') ?? ''
  const token = authorization.replace('Bearer ', '')

  const isAuthorized = (cronSecret && token === cronSecret) || (serviceRoleKey && token === serviceRoleKey)
  if (!isAuthorized) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const now = new Date()
    const nowUtcHours = now.getUTCHours()
    const nowUtcMinutes = now.getUTCMinutes()
    const today = now.toISOString().split('T')[0]
    const windowLabel = `${nowUtcHours}:${String(nowUtcMinutes).padStart(2, '0')}`

    // Journalisation des envois. Best-effort : un échec d'insert ne doit
    // jamais empêcher l'envoi suivant, mais il est loggé (c'est la
    // disparition silencieuse de cet INSERT qui a rendu la table muette
    // depuis le 07/07).
    const logNotification = async (
      userId: string,
      kind: 'reminder' | 'last_chance',
      flow: number | null,
      fcmStatus: string,
      errorMessage: string | null = null,
    ) => {
      const { error } = await supabase.from('streak_notification_log').insert({
        user_id: userId,
        kind,
        flow,
        window_utc: windowLabel,
        fcm_status: fcmStatus,
        error_message: errorMessage,
      })
      if (error) console.error('⚠️ streak_notification_log insert KO:', error.message)
    }

    console.log(`🚀 Rappels de flow — fenêtre ${windowLabel} UTC`)

    const profiles = await fetchAllRows<Profile>((from, to) =>
      supabase
        .from('profiles')
        .select('id, display_name, fcm_token, notification_reminder_time, notification_days, timezone')
        .eq('notifications_enabled', true)
        .not('fcm_token', 'is', null)
        .order('id', { ascending: true })
        .range(from, to)
    )

    if (profiles.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Sessions d'aujourd'hui (pour exclure ceux qui ont déjà lu) — paginé
    // aussi : un jour chargé peut dépasser 1000 sessions, ce qui laisserait
    // des lecteurs actifs se faire notifier à tort.
    const todayReadings = await fetchAllRows<{ user_id: string }>((from, to) =>
      supabase
        .from('reading_sessions')
        .select('user_id')
        .gte('end_time', `${today}T00:00:00`)
        .lte('end_time', `${today}T23:59:59`)
        .not('end_time', 'is', null)
        .order('user_id', { ascending: true })
        .range(from, to)
    )

    const usersWhoReadToday = new Set(todayReadings.map(r => r.user_id))

    // Utilisateurs ayant terminé AU MOINS UNE session dans leur vie.
    // Un rappel de flow n'a de sens que pour eux : on ne demande pas à
    // quelqu'un de continuer une série qu'il n'a jamais commencée.
    // Les autres relèvent de send-reengagement (piste "activation").
    const everReadRows = await fetchAllRows<{ user_id: string }>((from, to) =>
      supabase
        .from('reading_sessions')
        .select('user_id')
        .not('end_time', 'is', null)
        .order('user_id', { ascending: true })
        .range(from, to)
    )
    const everRead = new Set(everReadRows.map(r => r.user_id))

    let skippedNeverRead = 0

    // Filtrer : a déjà lu une fois + bon jour + pas encore lu + heure dans la fenêtre
    const usersToNotify = (profiles as Profile[]).filter((p) => {
      if (!everRead.has(p.id)) { skippedNeverRead++; return false }
      if (usersWhoReadToday.has(p.id)) return false

      // Compute the day of week in the USER's timezone, not UTC.
      // A user in Paris (UTC+2) setting a reminder for Wednesday 23:00
      // should NOT be notified on Tuesday at 21:00 UTC.
      const tz = p.timezone || 'Europe/Paris'
      const userLocalDate = new Date(now.toLocaleString('en-US', { timeZone: tz }))
      const jsDay = userLocalDate.getDay() // 0=Sun in user's local tz
      const isoDay = jsDay === 0 ? 7 : jsDay

      const days = p.notification_days ?? [1, 2, 3, 4, 5, 6, 7]
      if (!days.includes(isoDay)) return false
      const reminderTime = p.notification_reminder_time ?? '20:00'
      return isInCurrentWindow(reminderTime, p.timezone, nowUtcHours, nowUtcMinutes)
    })

    // "Dernière chance" : utilisateurs pas encore lus dont l'heure locale est
    // LAST_CHANCE_TIME. Volontairement indépendant de notification_days : un
    // streak se perd n'importe quel jour. N'est envoyée que si flow > 0
    // (vérifié plus bas, après calcul du flow) — donc jamais à un non-lecteur,
    // mais on filtre quand même en amont pour éviter les requêtes inutiles.
    const notifiedIds = new Set(usersToNotify.map((p) => p.id))
    const lastChanceUsers = (profiles as Profile[]).filter((p) => {
      if (!everRead.has(p.id)) return false
      if (usersWhoReadToday.has(p.id)) return false
      if (notifiedIds.has(p.id)) return false // déjà notifié dans cette fenêtre
      return isInCurrentWindow(LAST_CHANCE_TIME, p.timezone, nowUtcHours, nowUtcMinutes)
    })

    console.log(`🔔 ${usersToNotify.length} rappel(s) + ${lastChanceUsers.length} candidat(s) dernière chance (${skippedNeverRead} non-activé(s) écarté(s))`)

    if (usersToNotify.length === 0 && lastChanceUsers.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, skipped_never_read: skippedNeverRead }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const accessToken = await getAccessToken()

    let successCount = 0
    let errorCount = 0
    let cleanedTokens = 0
    let lastChanceSkipped = 0

    const queue: Array<{ user: Profile, isLastChance: boolean }> = [
      ...usersToNotify.map((user) => ({ user, isLastChance: false })),
      ...lastChanceUsers.map((user) => ({ user, isLastChance: true })),
    ]

    for (const { user, isLastChance } of queue) {
      const kind: 'reminder' | 'last_chance' = isLastChance ? 'last_chance' : 'reminder'
      let currentFlow: number | null = null
      try {
        // Calcul du flow pour cet utilisateur
        const { data: sessions } = await supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', user.id)
          .not('end_time', 'is', null)

        const { data: freezes } = await supabase
          .from('streak_freezes')
          .select('frozen_date')
          .eq('user_id', user.id)

        const sessionDates = [...new Set(
          (sessions || []).map(s => s.end_time.split('T')[0])
        )]
        const frozenDates = (freezes || []).map(f => f.frozen_date)

        currentFlow = calculateCurrentFlow(sessionDates, frozenDates)

        // Dernière chance : seulement si un streak est réellement en jeu
        if (isLastChance && currentFlow === 0) {
          lastChanceSkipped++
          continue
        }

        const { title, body } = isLastChance
          ? getLastChanceMessage(currentFlow)
          : getNotificationMessage(currentFlow, user.display_name)

        const result = await sendFCMNotification(accessToken, user.fcm_token, title, body, {
          type: 'streak_reminder',
          user_id: user.id,
        })

        if (result.unregistered) {
          // Token is no longer valid — clean it from the database
          await supabase
            .from('profiles')
            .update({ fcm_token: null })
            .eq('id', user.id)
          cleanedTokens++
          await logNotification(user.id, kind, currentFlow, 'unregistered')
          console.log(`🧹 Token invalide nettoyé pour ${user.display_name}`)
        } else {
          successCount++
          await logNotification(user.id, kind, currentFlow, 'sent')
          console.log(`✅ Notification${isLastChance ? ' dernière chance' : ''} envoyée à ${user.display_name} (flow: ${currentFlow})`)
        }
      } catch (error) {
        errorCount++
        await logNotification(user.id, kind, currentFlow, 'error', String((error as Error)?.message ?? error))
        console.error(`❌ Erreur pour ${user.display_name}:`, error)
      }
    }

    const result = {
      success: true,
      window: windowLabel,
      total_profiles: profiles.length,
      users_who_read_today: usersWhoReadToday.size,
      skipped_never_read: skippedNeverRead,
      notifications_sent: successCount,
      last_chance_skipped: lastChanceSkipped,
      cleaned_tokens: cleanedTokens,
      errors: errorCount,
    }

    console.log('📊 Résultat:', result)

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Erreur:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
