# Spec — Système de notation et évaluation des livres

> Spec de conception, aucun code. Alignée sur le schéma Supabase existant (`books`, `user_books`, `feed_items`, `badges`).

## 1. Principe

Notation en 3 couches, déclenchée au passage d'un livre en statut `finished` (ou `abandoned`). Seule la couche 1 est proposée d'office ; les couches 2 et 3 sont optionnelles et repliées.

| Couche | Contenu | Friction |
|---|---|---|
| 1 | Note globale ½ à 5 étoiles (pas de 0,5) | 1 tap, skippable |
| 2 | Critères rapides à 3 niveaux : écriture, histoire, rythme, difficulté | ~5 s |
| 3 | Tags émotionnels + avis texte libre + « je recommande » / « je relirais » | libre |

## 2. Modèle de données

### Nouvelle table `book_ratings`

Une ligne **par lecture** (pas par livre) → gère les relectures et l'évolution de l'avis.

| Colonne | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `user_id` | uuid FK → profiles | |
| `book_id` | bigint FK → books | dénormalisé pour agrégats rapides |
| `user_book_id` | bigint FK → user_books | la lecture concernée |
| `rating` | numeric(2,1) | 0.5 → 5.0, pas de 0,5 ; CHECK en base |
| `criteria` | jsonb | `{"writing": 1-3, "story": 1-3, "pace": 1-3, "difficulty": 1-3}` — clés toutes optionnelles |
| `emotion_tags` | text[] | vocabulaire fermé côté app (voir §5) |
| `review_text` | text | avis libre, nullable |
| `would_recommend` | boolean | nullable (non répondu ≠ non) |
| `would_reread` | boolean | nullable |
| `is_public` | boolean | défaut `false` |
| `abandoned` | boolean | défaut `false` |
| `abandoned_at_percent` | smallint | nullable, 0-100 |
| `created_at` / `updated_at` | timestamptz | |

Contraintes : `UNIQUE (user_book_id)` — une note par lecture ; modifier = update, relire = nouvelle ligne via nouvelle lecture. RLS : owner en écriture ; lecture = owner OU (`is_public` ET amis via `friends`), même logique que le feed.

### Pourquoi une table dédiée (et pas des colonnes sur `user_books`)

- `user_books` est déjà chargée (partage vidéo, Notion, reading_sheet…)
- historique par lecture propre, agrégats simples (`avg(rating) group by book_id`)
- RLS publique/privée indépendante du statut de lecture

### Agrégats

Pas de table d'agrégat au début (243 livres, 25 users) : une vue `book_rating_stats` (moyenne, count, % recommande par `book_id`, uniquement sur les notes publiques) suffit. Matérialiser plus tard si besoin.

## 3. Parcours UI

### Écran A — Déclencheur (fin de lecture)

Au passage en `finished` (manuel ou `kindle_auto_finished`), après l'éventuel écran de célébration existant :

1. Couverture + « Tu as terminé {titre} ! »
2. Rangée de 5 étoiles (drag ou tap, demi-étoiles)
3. Bouton « Plus tard » (dismiss silencieux, re-proposable depuis la fiche livre)
4. Dès qu'une note est posée → apparition animée du bloc « Affiner ton avis ? » (couches 2-3, repliées)

Cas abandon : depuis la fiche livre, action « Abandonner » → mini-feuille optionnelle « Pourquoi tu arrêtes ? » (note optionnelle + tags + % lu pré-rempli depuis `current_page`).

### Écran B — Avis détaillé (bottom sheet, tout optionnel)

- 4 lignes de critères, chacune : label + 3 pastilles (ex. rythme : 🐢 / ⚖️ / ⚡)
- Grille de tags émotionnels (chips multi-sélection, max ~5)
- Champ texte « Ton avis en quelques mots » (pas de minimum)
- Toggles « Je le recommande » / « Je le relirais »
- Switch « Partager avec mes amis » (`is_public`) — défaut privé, position mémorisée
- CTA unique « Enregistrer »

### Écran C — Fiche livre

- Ma note (étoiles + badge « recommandé » le cas échéant), tap → réédition (écran B)
- Si notes publiques d'amis : « Tes amis : 4,2 ★ (3 avis) » + liste des avis amis
- Historique si relectures : « 1re lecture 3★ (2025) · 2e lecture 4,5★ (2026) »

### Écran D — Feed social

Nouveau type `feed_items.type = 'book_rated'` (émis seulement si `is_public`). Payload : book, rating, extrait de l'avis, tags. Réactions/commentaires via l'existant (`activity_reactions`, `comments`). Respecter `user_blocks` et `content_reports` pour les avis textes.

### Stats & Wrapped

- Profil : note moyenne, distribution des notes, top genres notés ≥ 4★
- Monthly Wrapped : « Coup de cœur du mois » = meilleure note (tie-break : recommandé)

## 4. Intégrations existantes

| Système | Intégration |
|---|---|
| Badges | `first_rating`, `ratings_10`, `reviews_10` (avis texte), `eclectic_5` (5 genres ≥ 4★) — suivre la procédure badges.md en 4 étapes |
| IA Muse (`ai-suggest-books`) | injecter dans le prompt : livres notés ≥ 4★ (titre, genre, tags émotionnels) + livres ≤ 2★ ou abandonnés (à éviter). Les tags permettent « un livre réconfortant comme X » |
| Notion sync | ajouter note + avis dans la fiche de lecture exportée |
| Fiche de lecture IA (`reading_sheet`) | pré-remplir l'avis texte depuis la note/les tags si l'utilisateur le demande |

## 5. Vocabulaire des tags émotionnels

Fermé, défini côté app (i18n via `.arb`, stocké en clés neutres) : `moving`, `funny`, `instructive`, `comforting`, `disturbing`, `gripping`, `inspiring`, `dark`, `poetic`, `mind_blowing`. Extensible sans migration (text[]).

## 6. Ordre d'implémentation suggéré

1. Migration : table `book_ratings` + RLS + vue `book_rating_stats`
2. Écran A (note simple à la fin de lecture) + affichage fiche livre
3. Écran B (couches 2-3) + réédition
4. Feed `book_rated` + notes amis sur fiche livre
5. Badges + intégration Muse + Notion
6. Flux abandon

Chaque étape est shippable indépendamment ; la valeur existe dès l'étape 2.

## 7. Hors scope (volontairement)

Note sur 10/20, sous-notes chiffrées obligatoires, notation à mi-lecture par défaut, agrégats publics globaux type Goodreads (trop peu d'utilisateurs pour être significatifs — se limiter aux notes d'amis).
