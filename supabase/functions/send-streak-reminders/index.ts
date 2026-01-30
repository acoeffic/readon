// Supabase Edge Function pour envoyer les rappels de streak quotidien
// Cette fonction doit être appelée via un cron job quotidien

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface User {
  id: string
  username: string
  fcm_token: string
  notification_reminder_time: string
  notification_days: number[] | null
  current_streak: number
}

async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')

  if (!FCM_SERVER_KEY) {
    throw new Error('FCM_SERVER_KEY not configured')
  }

  const message = {
    to: fcmToken,
    notification: {
      title: title,
      body: body,
      sound: 'default',
    },
    data: data,
    priority: 'high',
  }

  const response = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify(message),
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`FCM request failed: ${error}`)
  }

  return await response.json()
}

function getNotificationMessage(streak: number, username: string): { title: string, body: string } {
  if (streak === 0) {
    return {
      title: "📚 Commence ton streak aujourd'hui !",
      body: `Salut ${username} ! C'est le moment de lire quelques pages.`
    }
  } else if (streak < 7) {
    return {
      title: `🔥 Ne perds pas ton streak de ${streak} jour${streak > 1 ? 's' : ''} !`,
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

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Créer le client Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    console.log('🚀 Début de l\'envoi des rappels de streak')

    // Récupérer tous les utilisateurs qui ont :
    // 1. Les notifications activées
    // 2. Un token FCM valide
    // 3. N'ont pas encore lu aujourd'hui
    const today = new Date().toISOString().split('T')[0]

    // Récupérer les utilisateurs avec notifications activées
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, username, fcm_token, notification_reminder_time, notification_days, current_streak')
      .eq('notifications_enabled', true)
      .not('fcm_token', 'is', null)

    if (usersError) {
      throw usersError
    }

    if (!users || users.length === 0) {
      console.log('✅ Aucun utilisateur avec notifications activées')
      return new Response(
        JSON.stringify({ success: true, message: 'No users to notify' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📊 ${users.length} utilisateur(s) avec notifications activées`)

    // Récupérer les lectures d'aujourd'hui
    const { data: todayReadings, error: readingsError } = await supabase
      .from('reading_sessions')
      .select('user_id')
      .gte('read_at', `${today}T00:00:00`)
      .lte('read_at', `${today}T23:59:59`)

    if (readingsError) {
      throw readingsError
    }

    const usersWhoReadToday = new Set(
      todayReadings?.map(r => r.user_id) || []
    )

    console.log(`📖 ${usersWhoReadToday.size} utilisateur(s) ont déjà lu aujourd'hui`)

    // Jour actuel : 1=Lundi, 7=Dimanche (ISO 8601)
    const now = new Date()
    const jsDay = now.getDay() // 0=Dimanche, 1=Lundi, ..., 6=Samedi
    const isoDay = jsDay === 0 ? 7 : jsDay // Convertir en 1=Lundi, 7=Dimanche

    // Filtrer les utilisateurs qui :
    // - n'ont pas encore lu aujourd'hui
    // - ont le jour actuel dans leurs jours de notification sélectionnés
    const usersToNotify = users.filter(
      (user: User) => {
        if (usersWhoReadToday.has(user.id)) return false
        const days = user.notification_days ?? [1, 2, 3, 4, 5, 6, 7]
        return days.includes(isoDay)
      }
    )

    console.log(`🔔 ${usersToNotify.length} notification(s) à envoyer`)

    // Envoyer les notifications
    let successCount = 0
    let errorCount = 0

    for (const user of usersToNotify) {
      try {
        const { title, body } = getNotificationMessage(
          user.current_streak || 0,
          user.username || 'Lecteur'
        )

        await sendFCMNotification(
          user.fcm_token,
          title,
          body,
          {
            type: 'streak_reminder',
            user_id: user.id,
          }
        )

        successCount++
        console.log(`✅ Notification envoyée à ${user.username}`)
      } catch (error) {
        errorCount++
        console.error(`❌ Erreur pour ${user.username}:`, error)
      }
    }

    const result = {
      success: true,
      total_users: users.length,
      users_who_read_today: usersWhoReadToday.size,
      notifications_sent: successCount,
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
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
