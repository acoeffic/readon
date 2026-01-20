# Guide d'installation des notifications FCM pour ReadOn

Ce guide vous accompagne étape par étape pour configurer les notifications push Firebase Cloud Messaging (FCM) dans votre application ReadOn.

## 📋 Prérequis

- Un projet Firebase (gratuit)
- Accès à votre console Supabase
- Flutter installé sur votre machine
- Xcode (pour iOS) et/ou Android Studio (pour Android)

---

## 🚀 Étape 1 : Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Cliquez sur "Ajouter un projet"
3. Donnez un nom à votre projet (ex: "ReadOn")
4. Suivez les étapes de création

---

## 📱 Étape 2 : Configurer Firebase pour Flutter

### Pour Android

1. Dans Firebase Console, cliquez sur l'icône Android
2. Entrez le package name de votre app (trouvez-le dans `android/app/build.gradle`, ligne `applicationId`)
3. Téléchargez le fichier `google-services.json`
4. Placez `google-services.json` dans `android/app/`
5. Modifiez `android/build.gradle` (niveau projet) :
   ```gradle
   buildscript {
     dependencies {
       // Ajoutez cette ligne
       classpath 'com.google.gms:google-services:4.3.15'
     }
   }
   ```
6. Modifiez `android/app/build.gradle` :
   ```gradle
   // En haut du fichier après les autres plugins
   apply plugin: 'com.google.gms.google-services'
   ```

### Pour iOS

1. Dans Firebase Console, cliquez sur l'icône iOS
2. Entrez le Bundle ID (trouvez-le dans Xcode ou dans `ios/Runner/Info.plist`)
3. Téléchargez le fichier `GoogleService-Info.plist`
4. Ouvrez le projet dans Xcode : `open ios/Runner.xcworkspace`
5. Glissez-déposez `GoogleService-Info.plist` dans le dossier `Runner` dans Xcode
6. Cochez "Copy items if needed"

#### Configuration des capabilities iOS

1. Dans Xcode, sélectionnez le projet Runner
2. Onglet "Signing & Capabilities"
3. Cliquez sur "+ Capability"
4. Ajoutez "Push Notifications"
5. Ajoutez "Background Modes" et cochez "Remote notifications"

---

## 🔑 Étape 3 : Obtenir la clé serveur FCM

1. Dans Firebase Console, allez dans **Paramètres du projet** (⚙️)
2. Onglet **Cloud Messaging**
3. Dans la section **API Cloud Messaging (héritée)**, copiez la **Clé du serveur**
4. ⚠️ Conservez cette clé en sécurité, vous en aurez besoin pour Supabase

---

## 🗄️ Étape 4 : Configurer Supabase

### 4.1 Appliquer les migrations

Exécutez les migrations pour créer les colonnes nécessaires :

```bash
# Si vous utilisez Supabase CLI
supabase db push

# Ou exécutez manuellement dans l'éditeur SQL de Supabase :
# - supabase/migrations/20260120_add_notifications.sql
```

### 4.2 Ajouter les variables d'environnement

1. Allez dans votre projet Supabase
2. **Settings** → **Edge Functions** → **Environment Variables**
3. Ajoutez la variable :
   - **Name:** `FCM_SERVER_KEY`
   - **Value:** Votre clé serveur FCM copiée à l'étape 3

### 4.3 Déployer l'Edge Function

```bash
# Installer Supabase CLI si ce n'est pas déjà fait
npm install -g supabase

# Se connecter
supabase login

# Lier votre projet
supabase link --project-ref YOUR_PROJECT_REF

# Déployer la fonction
supabase functions deploy send-streak-reminders
```

### 4.4 Configurer le cron job

#### Option A : Via SQL (Recommandé)

Exécutez dans l'éditeur SQL de Supabase :

```sql
-- Activer les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS http;

-- Créer le cron job (tous les jours à 20h UTC)
SELECT cron.schedule(
  'send-streak-reminders-daily',
  '0 20 * * *',
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

⚠️ **Remplacez** :
- `YOUR_PROJECT_REF` par votre référence de projet Supabase
- `YOUR_SERVICE_ROLE_KEY` par votre clé service_role (dans Settings → API)

#### Option B : GitHub Actions

Créez `.github/workflows/streak-reminders.yml` :

```yaml
name: Send Daily Streak Reminders
on:
  schedule:
    - cron: '0 20 * * *' # 20h UTC tous les jours
  workflow_dispatch: # Permet le déclenchement manuel

jobs:
  send-reminders:
    runs-on: ubuntu-latest
    steps:
      - name: Call Supabase Edge Function
        run: |
          curl -X POST \
            https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-streak-reminders \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json"
```

Ajoutez `SUPABASE_SERVICE_ROLE_KEY` dans vos secrets GitHub.

---

## 📲 Étape 5 : Installer les dépendances Flutter

```bash
flutter pub get
```

---

## 🧪 Étape 6 : Tester

### Test local de l'application

```bash
# Android
flutter run

# iOS (nécessite un appareil réel pour les notifications)
flutter run -d <device_id>
```

### Test de l'Edge Function

Appelez manuellement la fonction :

```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-streak-reminders \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

Ou créez un utilisateur test, connectez-vous, et vérifiez que :
1. Le token FCM est enregistré dans la table `users`
2. Vous pouvez activer/désactiver les notifications dans les paramètres
3. L'heure de rappel est personnalisable

---

## 🔍 Vérification et debug

### Vérifier que tout fonctionne

1. **Connexion utilisateur** :
   - Connectez-vous à l'app
   - Vérifiez dans la table `users` que `fcm_token` est rempli

2. **Paramètres notifications** :
   - Allez dans Profil → Paramètres → Notifications de streak
   - Activez les notifications
   - Changez l'heure de rappel

3. **Test Edge Function** :
   - Exécutez la commande curl ci-dessus
   - Vérifiez les logs dans Supabase : Edge Functions → Logs

### Logs utiles

**Dans l'app Flutter :**
```bash
flutter logs
# Recherchez les messages comme :
# ✅ Permission de notification accordée
# 📱 FCM Token: xxx
# ✅ Token FCM sauvegardé
```

**Dans Supabase Edge Functions :**
- Dashboard → Edge Functions → send-streak-reminders → Logs
- Vous verrez le nombre de notifications envoyées

---

## 📊 Formats de notification

Les messages sont personnalisés selon le streak :

| Streak | Message |
|--------|---------|
| 0 jour | "📚 Commence ton streak aujourd'hui !" |
| 1-6 jours | "🔥 Ne perds pas ton streak de X jours !" |
| 7-29 jours | "🔥 Impressionnant ! X jours de suite !" |
| 30+ jours | "🏆 X jours consécutifs ! Incroyable !" |

---

## ⚙️ Personnalisation

### Changer l'heure par défaut

Dans [supabase/migrations/20260120_add_notifications.sql](supabase/migrations/20260120_add_notifications.sql:5), ligne 5 :
```sql
ADD COLUMN IF NOT EXISTS notification_reminder_time TEXT DEFAULT '20:00';
```

### Modifier les messages

Dans [supabase/functions/send-streak-reminders/index.ts](supabase/functions/send-streak-reminders/index.ts:54), fonction `getNotificationMessage()` :
```typescript
function getNotificationMessage(streak: number, username: string): { title: string, body: string } {
  // Personnalisez vos messages ici
}
```

---

## 🔐 Sécurité

### Bonnes pratiques

1. **Ne commitez jamais** :
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)
   - Vos clés API Firebase
   - Votre service_role_key Supabase

2. **Ajoutez au `.gitignore`** :
   ```
   **/google-services.json
   **/GoogleService-Info.plist
   ```

3. **Utilisez des secrets** pour les clés sensibles dans les workflows CI/CD

---

## ❓ Problèmes courants

### "Permission de notification refusée"
- iOS : Vérifiez que les capabilities sont activées dans Xcode
- Android : Vérifiez les permissions dans `AndroidManifest.xml`

### Les notifications ne s'affichent pas
- Vérifiez que le token FCM est bien dans la base de données
- Testez avec l'outil Firebase Notifications dans la console
- Sur iOS, les notifications ne fonctionnent que sur un appareil réel (pas le simulateur)

### Le cron job ne s'exécute pas
- Vérifiez que `pg_cron` est activé sur votre instance Supabase
- Les cron jobs ne sont disponibles que sur le plan Pro de Supabase
- Alternative : utilisez GitHub Actions (gratuit)

### Token FCM invalide
- Le token peut expirer, il est automatiquement rafraîchi par le service
- En cas de désinstallation/réinstallation, un nouveau token sera généré

---

## 📚 Ressources

- [Documentation Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Documentation Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Documentation pg_cron](https://github.com/citusdata/pg_cron)
- [Package firebase_messaging Flutter](https://pub.dev/packages/firebase_messaging)

---

## ✅ Checklist finale

- [ ] Projet Firebase créé
- [ ] Fichiers de configuration téléchargés et placés
- [ ] Clé serveur FCM récupérée
- [ ] Variables d'environnement Supabase configurées
- [ ] Migrations SQL exécutées
- [ ] Edge Function déployée
- [ ] Cron job configuré
- [ ] Dépendances Flutter installées
- [ ] Test sur un appareil réel effectué
- [ ] Fichiers sensibles ajoutés au .gitignore

---

Bon courage ! 🚀 Si vous rencontrez des problèmes, vérifiez les logs à chaque étape.
