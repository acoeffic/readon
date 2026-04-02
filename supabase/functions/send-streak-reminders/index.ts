// Supabase Edge Function pour envoyer les rappels de streak quotidien
// Appelée toutes les 15 minutes par pg_cron — filtre les utilisateurs
// dont l'heure de rappel tombe dans la fenêtre courante.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

function getNotificationMessage(streak: number, displayName: string): { title: string, body: string } {
  const name = displayName || 'Lecteur'
  if (streak === 0) {
    return {
      title: "📚 Commence ton flow aujourd'hui !",
      body: `Salut ${name} ! C'est le moment de lire quelques pages.`
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

    console.log(`🚀 Rappels de flow — fenêtre ${nowUtcHours}:${String(nowUtcMinutes).padStart(2, '0')} UTC`)

    const { data: profiles, error: profilesError } = await supabase
      .from('profiles')
      .select('id, display_name, fcm_token, notification_reminder_time, notification_days, timezone')
      .eq('notifications_enabled', true)
      .not('fcm_token', 'is', null)

    if (profilesError) throw profilesError

    if (!profiles || profiles.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Sessions d'aujourd'hui (pour exclure ceux qui ont déjà lu)
    const { data: todayReadings, error: readingsError } = await supabase
      .from('reading_sessions')
      .select('user_id')
      .gte('end_time', `${today}T00:00:00`)
      .lte('end_time', `${today}T23:59:59`)
      .not('end_time', 'is', null)

    if (readingsError) throw readingsError

    const usersWhoReadToday = new Set(todayReadings?.map(r => r.user_id) || [])

    const jsDay = now.getUTCDay()
    const isoDay = jsDay === 0 ? 7 : jsDay

    // Filtrer : bon jour + pas encore lu + heure dans la fenêtre
    const usersToNotify = (profiles as Profile[]).filter((p) => {
      if (usersWhoReadToday.has(p.id)) return false
      const days = p.notification_days ?? [1, 2, 3, 4, 5, 6, 7]
      if (!days.includes(isoDay)) return false
      const reminderTime = p.notification_reminder_time ?? '20:00'
      return isInCurrentWindow(reminderTime, p.timezone, nowUtcHours, nowUtcMinutes)
    })

    console.log(`🔔 ${usersToNotify.length} notification(s) à envoyer`)

    if (usersToNotify.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const accessToken = await getAccessToken()

    let successCount = 0
    let errorCount = 0
    let cleanedTokens = 0

    for (const user of usersToNotify) {
      try {
        // Calcul du flow pour cet utilisateur
        const { data: sessions } = await supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', user.id)
          .not('end_time', 'is', null)

        const { data: freezes } = await supabase
          .from('streak_freezes')
          .select('freeze_date')
          .eq('user_id', user.id)

        const sessionDates = [...new Set(
          (sessions || []).map(s => s.end_time.split('T')[0])
        )]
        const frozenDates = (freezes || []).map(f => f.freeze_date)

        const currentFlow = calculateCurrentFlow(sessionDates, frozenDates)

        const { title, body } = getNotificationMessage(currentFlow, user.display_name)

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
          console.log(`🧹 Token invalide nettoyé pour ${user.display_name}`)
        } else {
          successCount++
          console.log(`✅ Notification envoyée à ${user.display_name} (flow: ${currentFlow})`)
        }
      } catch (error) {
        errorCount++
        console.error(`❌ Erreur pour ${user.display_name}:`, error)
      }
    }

    const result = {
      success: true,
      window: `${nowUtcHours}:${String(nowUtcMinutes).padStart(2, '0')}`,
      total_profiles: profiles.length,
      users_who_read_today: usersWhoReadToday.size,
      notifications_sent: successCount,
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