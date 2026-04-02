import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!)

// Même logique getAccessToken que send-streak-reminders
async function getAccessToken(): Promise<string> {
  // ... copie exacte de la fonction dans send-streak-reminders/index.ts
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

  const { data: profiles } = await supabase
    .from('profiles')
    .select('id, display_name, fcm_token')
    .eq('notifications_enabled', true)
    .not('fcm_token', 'is', null)

  if (!profiles?.length) {
    return new Response(JSON.stringify({ success: true, sent: 0 }))
  }

  const accessToken = await getAccessToken()
  let sent = 0

  for (const user of profiles) {
    try {
      await fetch(
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
      sent++
    } catch (e) {
      console.error(`Erreur pour ${user.display_name}:`, e)
    }
  }

  return new Response(JSON.stringify({ success: true, sent }), {
    headers: { 'Content-Type': 'application/json' }
  })
})