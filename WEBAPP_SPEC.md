# Spec — LexDay Web App (« Strava de la lecture » sur le web)

> Statut : **cadrage — rien n'est implémenté**. Rédigé le 05/08/2026, mis à
> jour le 05/08/2026 après arbitrages.
> Objectif produit : retrouver sur le web l'expérience de suivi de l'app
> (sessions, stats, streak, feed) à la manière de Strava, et offrir un
> parcours d'**import d'anciennes lectures** bien plus confortable qu'au
> téléphone. Pages publiques partageables = levier d'acquisition clé.

## Arbitrages (05/08/2026)

- **Un seul site sur `lexday.fr`** : le projet Next.js remplace le site
  statique. La landing actuelle est migrée, le login se fait sur le même
  domaine (`lexday.fr/login` → `/dashboard`). Un seul déploiement Vercel.
- **Logger des sessions depuis le web : reporté** (hors périmètre pour
  l'instant). Le web reste en lecture + import. La question « descendre
  flow/défis/badges en RPC serveur vs duplication TS » est reportée avec —
  elle ne se posera qu'au moment de réintroduire l'écriture de sessions.
- **Profils publics : opt-in** (privé par défaut, conforme RGPD).
- **Import Goodreads : via Edge Function** (contrôle serveur — voir
  Phase 2).

## 1. Positionnement et architecture générale

- **Nouveau projet dédié** : repo séparé `lexday-web`, Next.js (App
  Router) + TypeScript, déployé sur Vercel sur **`lexday.fr`** (remplace
  le déploiement statique `website/`).
- **Migration du site vitrine** dans le projet Next.js :
  - la landing actuelle (`index.html`) devient la page d'accueil Next.js ;
  - **pages à préserver absolument** : `/redirect` (pont deep links
    `lexday://` — utilisé par les emails/liens existants), `/privacy`,
    `/cgu`, `/mentions-legales`, et les règles de `vercel.json` ;
  - bouton « Se connecter » dans le header de la landing → `/login`.
- **Supabase = backend commun**, le web n'est qu'un client de plus du
  projet `nzbhmshkcwudzydeahrq` : mêmes tables, mêmes RLS, mêmes Edge
  Functions, mêmes comptes utilisateurs.
- Stack web : `@supabase/ssr` (auth par cookies, PKCE), Tailwind,
  `supabase gen types typescript` pour typer la DB, i18n fr/en/es
  (`next-intl`) pour rester aligné avec l'app.
- Strava est la référence UX : dashboard personnel privé + pages
  d'activité/profil publiques accessibles par lien, propres, rapides,
  indexables.

## 2. Phasage proposé

### Phase 1 — Migration vitrine + Auth + Dashboard (lecture seule)

Le socle : le site actuel refait en Next.js, se connecter avec son compte
LexDay et *voir* sa vie de lecteur.

- Migration de la landing + pages légales + `/redirect` (iso-fonctionnel).
- Login/signup Supabase (email + confirmation existante). À prévoir :
  ajouter les URLs `https://lexday.fr/**` aux **Redirect URLs** de
  Supabase Auth ; le flux de confirmation email actuel pointe vers le
  mobile (PKCE + page `/confirm`) — il faudra une variante web ou une page
  intelligente qui route selon le device.
- Dashboard : dernières sessions (`reading_sessions`), livre en cours
  (`user_books`), flamme/streak, objectifs (`reading_goals`), badges
  (`user_badges`), graphiques hebdo/mensuels (pages, minutes), bibliothèque.
- Tout est faisable en SELECT direct sous RLS `authenticated` — aucun
  changement backend attendu, hors éventuelles RPC de stats agrégées
  (voir §4 pièges : GRANT explicite).

### Phase 2 — Import d'anciennes lectures (le différenciateur desktop)

Décision produit clé : les **livres lus par le passé** (années
précédentes, pas de sessions) créent des `user_books` au statut terminé
(+ dates début/fin approximatives, note via `book_ratings`), **sans créer
de `reading_sessions`** : pas de spam du feed, pas d'interférence
streak/stats. (Les sessions récentes « chrono oublié » restent gérées
dans l'app mobile via le flux `is_manual` existant — le web n'écrit pas
de sessions pour l'instant.)

Parcours d'import v1 :

- **CSV Goodreads / StoryGraph** : upload, parsing, écran de révision
  (table éditable au clavier), validation en lot.
- **Saisie rapide en masse** : champ de recherche → Enter → livre ajouté
  avec statut/année/note, optimisé clavier desktop.
- **Traitement côté serveur (décidé)** : une Edge Function
  `import-past-reads` reçoit les lignes validées et fait, pour chaque
  livre : matching ISBN/titre contre `books`, enrichissement Google Books
  si absent (clé API côté serveur, rate limiting maîtrisé),
  dédoublonnage centralisé de `books`, création des `user_books` +
  `book_ratings`. Le navigateur ne parle à Google Books que via elle.
  Rappels : `verify_jwt` actif (appel authentifié normal), gating premium
  éventuel à décider (import massif = feature premium ?).
- Question produit à trancher : les imports génèrent-ils des activités
  feed (« Adrien a ajouté 47 livres » ?) — recommandation : **non**, ou
  une seule activité agrégée.

### Phase 3 — Social

- Feed (`feed_items`/`activities`), réactions (`activity_reactions`),
  commentaires threadés (`comments.parent_id`), profils amis, notifications
  in-app (`notifications`).
- À respecter : règles de **contenu caché** (invisibilité rétroactive via
  le choke point activities), `user_blocks`, `content_reports`. Le web doit
  passer par les mêmes RPC/vues que l'app, jamais par des SELECT « à
  côté » qui contourneraient ces filtres.
- Clubs de lecture (`reading_groups`, défis) : hors périmètre v1 social,
  bon candidat v2.

### Phase 4 — Pages publiques partageables (l'objectif Strava/SEO)

- **Profil public** `lexday.fr/@pseudo` : livres lus, badges, stats
  agrégées — **opt-in** (décidé) : privé par défaut, activation explicite
  dans les réglages.
- **Session/activité partageable** par lien (façon activité Strava) et
  **Wrapped mensuel** : `monthly_wrapped_shares` + la function
  `render-wrapped` existent déjà — le web leur donne enfin une vraie page
  d'atterrissage avec OG image (aujourd'hui le partage sort image/vidéo).
- **Design d'accès anon — point de sécurité central.** La politique
  actuelle (durcissement 22/07/2026) est : `anon` n'a EXECUTE sur rien,
  et c'est très bien. Ne **pas** ouvrir les tables à `anon`. À la place :
  - RPC dédiées `get_public_profile(handle)`,
    `get_shared_session(share_token)` avec GRANT `anon` **explicite et
    minimal**, ne renvoyant que des champs whitelistés ;
  - tokens de partage non devinables pour les sessions (colonne
    `share_token` à ajouter, opt-in par session ou par profil) ;
  - vues éventuelles en `security_invoker = on` (piège connu :
    DROP/CREATE VIEW repart en DEFINER).
- SEO : rendu serveur Next.js, sitemap des profils publics, OG images
  générées (réutiliser la stack render-wrapped).

### Reporté (hors périmètre pour l'instant)

- **Logger/éditer des sessions depuis le web.** Le jour où on le fait :
  trigger feed AFTER UPDATE only (insert-then-update), règle d'antidatage
  (`is_manual && date(end_time) ≠ date(created_at)` = pas de flamme),
  page courante = `max(end_page)` — et surtout trancher : RPC Postgres
  partagée (`insert_past_session` + hooks défis/badges côté serveur,
  recommandé) vs duplication de la logique Flutter en TypeScript.

## 3. Ce qui se réutilise tel quel

- Toute la DB et les RLS `authenticated` (48 tables, tout est déjà
  RLS-enabled).
- Les Edge Functions premium-gated (ai-chat, generate-reading-sheet,
  sync Notion…) : le web enverra le même JWT Supabase ; le gating
  `profiles.is_premium` fonctionne sans modification.
- RevenueCat/abonnements : le web **affiche** le statut premium mais ne
  vend pas en v1 (l'achat reste dans les stores ; Stripe web = chantier
  séparé, avec impact RevenueCat).

## 4. Pièges connus à garder sous les yeux (hérités du projet)

- Nouvelle RPC ⇒ `GRANT EXECUTE TO authenticated` **explicite**, sinon
  ça échoue silencieusement ; `anon` jamais par défaut.
- `handle_new_user` fire à chaque login → attention aux champs
  user-modifiables de `profiles` dans le `ON CONFLICT` (le web ajoute un
  nouveau chemin de login).
- Vues : toujours `security_invoker = on` + REVOKE anon.
- `get_user_notifications` : cast NUMERIC déjà corrigé — réutiliser la RPC,
  ne pas requêter la table directement.
- Contenu caché : passer par les chemins filtrés existants.
- `/redirect` est référencé par des liens déjà dans la nature (emails,
  partages) : la migration Vercel ne doit pas casser cette URL.

## 5. Estimation grossière

| Phase | Contenu | Ordre de grandeur |
|---|---|---|
| 0 | Setup repo, auth, design system, i18n | ~1 sem |
| 1 | Migration vitrine + dashboard lecture seule | 2 sem |
| 2 | Import (CSV + saisie masse + Edge Function) | 2 sem |
| 3 | Social | 2 sem |
| 4 | Pages publiques + SEO | 1–2 sem |

Chaque phase est shippable indépendamment ; l'ordre 1→2 donne déjà un
produit utile (consulter + importer) avant d'attaquer le social.

## 6. Questions ouvertes

1. L'import massif est-il premium-gated (aligné avec le positionnement
   des autres features serveur) ou gratuit (levier d'activation) ?
2. Les imports génèrent-ils une activité feed agrégée, ou rien ?
3. Bascule DNS : à quel moment `lexday.fr` passe du projet statique au
   projet Next.js (checklist : parité des pages, `/redirect` testé avec
   l'app, redirections 301 si URLs renommées) ?

## Décisions actées

- Un seul site : Next.js sur `lexday.fr`, vitrine migrée, login sur le
  même domaine (05/08/2026).
- Profils publics opt-in (05/08/2026).
- Import via Edge Function `import-past-reads` (05/08/2026).
- Logging de sessions web : reporté (05/08/2026).
