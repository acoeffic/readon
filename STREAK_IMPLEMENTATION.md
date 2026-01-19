# Système de Streak de Lecture - Documentation

## Vue d'ensemble

Le système de streak permet de suivre les jours consécutifs de lecture des utilisateurs et de les récompenser avec des badges à différents paliers.

## Fichiers créés

### 1. Modèle de données
- **`lib/models/reading_streak.dart`**
  - Classe `ReadingStreak` pour représenter un streak
  - Enum `StreakBadgeLevel` avec 5 niveaux de badges :
    - 1 jour (📖)
    - 3 jours (🔥)
    - 7 jours (⭐)
    - 14 jours (💎)
    - 30 jours (👑)

### 2. Service
- **`lib/services/streak_service.dart`**
  - `getUserStreak()` : Récupère le streak actuel de l'utilisateur
  - `checkAndAwardStreakBadges()` : Vérifie et attribue automatiquement les badges
  - `getReadingHistory()` : Retourne l'historique des lectures (pour calendrier futur)
  - `watchUserStreak()` : Stream pour suivre le streak en temps réel

### 3. Widgets
- **`lib/pages/feed/widgets/streak_card.dart`**
  - Carte visuelle affichant le streak actuel
  - Indicateur de progression vers le prochain badge
  - Affichage du record personnel
  - Messages de motivation dynamiques

## Fichiers modifiés

### 1. Feed principal
- **`lib/pages/feed/feed_page.dart`**
  - Ajout de l'import du `StreakService` et du modèle `ReadingStreak`
  - Chargement du streak dans `loadFeed()`
  - Affichage de la `StreakCard` en haut du feed

### 2. Fin de session
- **`lib/pages/reading/end_reading_session_page.dart`**
  - Import du `StreakService`
  - Vérification des badges de streak après chaque session
  - Nouveau widget `_StreakBadgeDialog` pour afficher les badges débloqués

## Fonctionnement

### Calcul du streak

1. Le système récupère toutes les sessions de lecture terminées
2. Il extrait les dates uniques (un jour = au moins une session)
3. Il calcule le nombre de jours consécutifs :
   - Le streak est actif si la dernière lecture était aujourd'hui ou hier
   - Sinon, le streak est cassé et repart à 0
4. Le système garde aussi le record (longest streak)

### Attribution des badges

Automatiquement après chaque session terminée :
1. Vérification du streak actuel
2. Comparaison avec les paliers de badges (1, 3, 7, 14, 30 jours)
3. Attribution des badges non encore obtenus
4. Affichage d'une animation de déblocage

### Affichage dans le feed

La carte de streak montre :
- L'icône du badge actuel (📖/🔥/⭐/💎/👑)
- Le nombre de jours consécutifs
- Un message de motivation
- Le record personnel (si différent du streak actuel)
- Une barre de progression vers le prochain badge

## Tables Supabase requises

### Table `badges` (existante)
```sql
- id (text, PK) : ex: 'streak_1_day', 'streak_3_days', etc.
- name (text) : ex: 'Premier Jour', '3 Jours', etc.
- description (text) : ex: 'Lire 1 jour'
- icon (text) : emoji du badge
- color (text) : couleur hexadécimale
- category (text) : 'streak'
```

### Table `user_badges` (existante)
```sql
- id (serial, PK)
- user_id (uuid, FK)
- badge_id (text, FK)
- earned_at (timestamp)
```

### Table `reading_sessions` (existante)
```sql
- id (uuid, PK)
- user_id (uuid, FK)
- book_id (integer, FK)
- start_page (integer)
- end_page (integer, nullable)
- start_time (timestamp)
- end_time (timestamp, nullable)
- ...
```

## Migration SQL à exécuter

```sql
-- Créer les badges de streak s'ils n'existent pas
INSERT INTO badges (id, name, description, icon, color, category)
VALUES
  ('streak_1_day', 'Premier Jour', 'Lire 1 jour', '📖', '#FFB74D', 'streak'),
  ('streak_3_days', '3 Jours', 'Lire 3 jours d''affilée', '🔥', '#FF9800', 'streak'),
  ('streak_7_days', 'Une Semaine', 'Lire 7 jours consécutifs', '⭐', '#FFC107', 'streak'),
  ('streak_14_days', '2 Semaines', 'Lire 14 jours consécutifs', '💎', '#FF5722', 'streak'),
  ('streak_30_days', 'Un Mois', 'Lire 30 jours d''affilée', '👑', '#9C27B0', 'streak')
ON CONFLICT (id) DO NOTHING;
```

## Fonctionnalités futures (optionnelles)

### 1. Page détaillée du streak
Créer une page `/pages/streak/streak_detail_page.dart` avec :
- Calendrier montrant les jours de lecture (heatmap)
- Statistiques détaillées (plus long streak, jours totaux, etc.)
- Graphique de progression
- Liste des badges débloqués

### 2. Notifications de streak
- Rappel si l'utilisateur n'a pas lu aujourd'hui
- Notification "Ne cassez pas votre streak de X jours!"
- Envoi à 20h00 par exemple

### 3. Streak social
- Voir les streaks de ses amis
- Classement des amis par streak
- Défis de lecture entre amis

### 4. Protection de streak
- "Freeze day" : permettre 1 jour de pause par mois sans casser le streak
- Achat avec points de lecture

### 5. Widget de calendrier
- Afficher un mini calendrier dans le feed
- Jours de lecture colorés
- Clic pour voir les sessions de chaque jour

## Tests à effectuer

1. **Premier streak** : Terminer une session, vérifier le badge "Premier Jour"
2. **Streak consécutif** : Lire 3 jours d'affilée, vérifier le badge "3 Jours"
3. **Streak cassé** : Ne pas lire pendant 2 jours, vérifier que le streak repart à 0
4. **Affichage feed** : Vérifier que la carte s'affiche correctement
5. **Progression** : Vérifier l'indicateur de progression vers le prochain badge
6. **Record** : Faire un streak de 5 jours, le casser, refaire un streak de 3 jours, vérifier que le record reste à 5

## Notes techniques

- Les streaks sont calculés côté client en Dart (pas de fonction SQL)
- Les dates sont normalisées au format YYYY-MM-DD pour éviter les problèmes de timezone
- Un jour = au moins une session terminée
- Le streak se casse si aucune lecture pendant plus de 24h (hier ou aujourd'hui OK)
- Les badges sont créés automatiquement s'ils n'existent pas dans la table `badges`

## Exemple de flux utilisateur

1. L'utilisateur ouvre l'app et voit son feed
2. En haut, une belle carte affiche son streak actuel : "3 jours 🔥"
3. Il démarre une session de lecture
4. Il termine la session
5. Une animation de confetti apparaît : "Badge Streak! 3 Jours"
6. Il retourne au feed et voit son streak mis à jour
7. Le lendemain, il lit à nouveau et débloquer le badge "Une Semaine ⭐"

## Support

Pour toute question ou amélioration, consulter les fichiers :
- [lib/models/reading_streak.dart](lib/models/reading_streak.dart)
- [lib/services/streak_service.dart](lib/services/streak_service.dart)
- [lib/pages/feed/widgets/streak_card.dart](lib/pages/feed/widgets/streak_card.dart)
