# Send Streak Reminders - Edge Function

Cette Edge Function envoie des notifications push quotidiennes aux utilisateurs pour leur rappeler de maintenir leur streak de lecture.

## Configuration

### 1. Variables d'environnement

Ajoutez les variables d'environnement suivantes dans votre projet Supabase :

```bash
# Clé serveur Firebase (FCM)
FCM_SERVER_KEY=your_firebase_server_key_here
```

Pour obtenir la clé FCM :
1. Allez sur la [Console Firebase](https://console.firebase.google.com/)
2. Sélectionnez votre projet
3. Allez dans Paramètres du projet > Cloud Messaging
4. Copiez la "Clé du serveur" (Server Key)

### 2. Déploiement

Déployez la fonction avec la CLI Supabase :

```bash
supabase functions deploy send-streak-reminders
```

### 3. Configuration du Cron Job

Pour exécuter cette fonction automatiquement chaque jour, vous avez plusieurs options :

#### Option A : Supabase Cron (pg_cron)

Créez un cron job dans votre base de données :

```sql
-- Exécuter tous les jours à 20h (heure serveur UTC)
SELECT cron.schedule(
  'send-streak-reminders',
  '0 20 * * *', -- Tous les jours à 20h UTC
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-streak-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
```

#### Option B : Service externe (GitHub Actions, Vercel Cron, etc.)

Créez un workflow GitHub Actions (`.github/workflows/streak-reminders.yml`) :

```yaml
name: Send Streak Reminders
on:
  schedule:
    - cron: '0 20 * * *' # Tous les jours à 20h UTC
  workflow_dispatch: # Permet de déclencher manuellement

jobs:
  send-reminders:
    runs-on: ubuntu-latest
    steps:
      - name: Call Edge Function
        run: |
          curl -X POST \
            https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-streak-reminders \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json"
```

### 4. Test manuel

Testez la fonction manuellement :

```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-streak-reminders \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

## Personnalisation

### Modifier l'heure d'envoi par utilisateur

Les utilisateurs peuvent définir leur heure de rappel préférée dans la colonne `notification_reminder_time` (format HH:mm).

Pour supporter les heures personnalisées, vous pouvez :
1. Créer plusieurs cron jobs (un par tranche horaire)
2. Filtrer les utilisateurs selon leur `notification_reminder_time` dans la fonction

### Messages de notification

Les messages sont personnalisés selon le streak actuel :
- 0 jour : Message de motivation pour commencer
- 1-6 jours : Encouragement à continuer
- 7-29 jours : Félicitations pour la constance
- 30+ jours : Message admiratif pour l'exploit

Modifiez la fonction `getNotificationMessage()` pour personnaliser les messages.

## Logs et monitoring

Les logs sont disponibles dans le dashboard Supabase :
- Nombre d'utilisateurs notifiés
- Nombre d'erreurs
- Détails par utilisateur

## Sécurité

- La fonction utilise la `SERVICE_ROLE_KEY` pour accéder à toutes les données
- Seules les requêtes authentifiées peuvent déclencher la fonction
- Les tokens FCM invalides génèrent des erreurs loggées mais n'arrêtent pas le processus
