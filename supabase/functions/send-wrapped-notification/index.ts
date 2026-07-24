import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!)

// PostgREST cape chaque SELECT à 1000 lignes. Sans pagination, au-delà de
// 1000 utilisateurs le Wrapped n'est envoyé qu'aux 1000 premiers. Ce helper
// parcourt toutes les pages via .range() (factory avec .order(...) stable).
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

// Même logique getAccessToken que send-streak-reminders : on signe un JWT
// avec la clé de service FCM et on l'échange contre un access_token OAuth.
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

serve(async (req) => {
  const cronSecret = Deno.env.get('CRON_SECRET')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const authorization = req.headers.get('authorization') ?? ''
  const token = authorization.replace('Bearer ', '')

  const isAuthorized = (cronSecret && token === cronSecret) || (serviceRoleKey && token === serviceRoleKey)
  if (!isAuthorized) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const now = new Date()
  const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1)
  const monthName = prevMonth.toLocaleString('fr-FR', { month: 'long' })
  const year = prevMonth.getFullYear()

  const profiles = await fetchAllRows<{ id: string; display_name: string; fcm_token: string }>(
    (from, to) =>
      supabase
        .from('profiles')
        .select('id, display_name, fcm_token')
        .eq('notifications_enabled', true)
        .not('fcm_token', 'is', null)
        .order('id', { ascending: true })
        .range(from, to)
  )

  if (profiles.length === 0) {
    return new Response(JSON.stringify({ success: true, sent: 0 }))
  }

  const accessToken = await getAccessToken()
  if (!accessToken) {
    console.error('send-wrapped-notification: échec de getAccessToken (FCM)')
    return new Response(
      JSON.stringify({ error: 'FCM auth failed' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }

  let sent = 0
  let failed = 0

  for (const user of profiles) {
    try {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FCM_SERVICE_ACCOUNT.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: user.fcm_token,
              notification: {
                title: '📚 Ton Wrapped est prêt !',
                body: `Découvre ton résumé de lecture de ${monthName} ${year}`,
              },
              data: { type: 'monthly_wrapped', month: String(prevMonth.getMonth() + 1), year: String(year) },
              apns: { payload: { aps: { sound: 'default' } } },
            },
          }),
        }
      )

      if (res.ok) {
        sent++
      } else {
        failed++
        console.error(`FCM échec pour ${user.display_name}: ${res.status} ${await res.text()}`)
      }
    } catch (e) {
      failed++
      console.error(`Erreur pour ${user.display_name}:`, e)
    }
  }

  return new Response(JSON.stringify({ success: true, sent, failed }), {
    headers: { 'Content-Type': 'application/json' }
  })
})