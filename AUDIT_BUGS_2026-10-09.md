# Audit LexDay — chasse aux bugs (09/10/2026)

**Périmètre** : code Flutter (`lib/`, HEAD `c375e37` + fichiers non commités), 28 Edge Functions, migrations SQL jusqu'au 27/09.
**Méthode** : 5 relectures statiques parallèles (Flutter non commité, services, UI, Edge Functions, SQL), chacune avec tentative de réfutation. Rien n'a été exécuté (pas de Flutter ici) ni lu en prod.
**Légende confiance** : les constats SQL sont déduits des fichiers du repo ; les policies de `profiles`, `friends`, `activities`, `user_badges` ne sont pas dans le repo → à confirmer en prod (`pg_policies`, `has_function_privilege`). Vérifiés à la main dans le code : A1, B4, B7, B8, B9, C-DST.

---
## A. Sécurité / base de données

1. **`profiles` lisible en entier par tout `authenticated`** (`20260814_restrict_anon_select_on_profiles.sql`) : `notion_access_token`, `fcm_token`, `email` de tous les profils. Fix : `revoke select … from authenticated` + `grant select (colonnes publiques)`. À confirmer en prod.
2. **IDOR via `p_user_id` libre sur des RPC SECURITY DEFINER** : `get_user_notifications` (20260720:139, `WHERE n.user_id = p_user_id`), `get_all_user_badges`, `check_and_award_badges` (20260811), `get_user_groups`, `get_group_invitations` (20260121), `count_unread_notifications`, et l'ancien `get_feed(p_user_id)` (renvoie `author_email`, jamais supprimé). Fix : `IF p_user_id IS DISTINCT FROM auth.uid() THEN RAISE …` ou `drop function get_feed`.
3. **`get_activity_comments`** (20260720:43-84) : le DROP+CREATE a perdu le filtre `user_blocks` et renvoie `p.email AS author_email` ; `activity_id` énumérables → récolte d'e-mails.
4. **Fonctions internes appelables par `authenticated`** : `get_hmac_secret()`, `hmac_hash()`, `write_audit_log()`, `refresh_feed_materialized_views()` (EXECUTE PUBLIC par défaut, jamais révoqué). `get_hmac_secret` donne le secret des hash e-mail/téléphone. Fix : `revoke execute … from authenticated, anon, public`.
5. **`streak_freezes` et `kindle_read_days` insérables en direct** (policy INSERT = `auth.uid()=user_id` seulement) → contourne paywall et quotas de freeze, permet de forger un `longest_streak` et le badge `streak_365_days`, publié ensuite aux amis.
6. **Contenu caché visible dans `mv_community_sessions` / `mv_trending_books`** (régression de 20260521 : filtres `is_hidden` et `hide_reading_hours` perdus) et dans `get_feed_bundle.active_readers`. Contredit la décision du 31/07.
7. **Triggers push/e-mail dépendants de `current_setting('app.settings.*')`** (20260720:284, 20260413, 20260315) — documenté comme inexistant en prod dans 20260802. Les push like/commentaire peuvent ne jamais partir ; `send_friend_request_email` n'a pas d'EXCEPTION. À vérifier dans `cron.job_run_details` / logs.
8. **`search_path` manquant** sur `get_friend_profile_stats`, `notify_activity_comment`, `send_push_on_notification`, `notify_activity_reaction`, `notify_group_join_request`, `use_streak_freeze`, `_auto_freeze_for_user`, `get_freeze_status`…; `get_friend_recent_sessions` sans `revoke … from public, anon`.
9. **`profiles.email` modifiable** (grant UPDATE) ; `search_users_by_name` sans filtre de blocage ni borne de `p_limit`.
10. **Migration `20260926` (`badge_unlocked`)** — le trigger est best-effort et sûr, mais : (a) un client modifié peut insérer lui-même un faux `badge_unlocked` si la policy `activities` ne contraint pas `type` ; (b) doublon de carte pour les <3 amis (`badge_unlocks` n'exclut pas les amis) ; (c) like/commentaire sur une carte badge → notification vide (`get_user_notifications` ne gère pas `badge_*`) ; (d) pas d'unicité → rafale d'activités lors d'un import.
11. **Fuseaux horaires en UTC dans le SQL** : `anim_night_owl`, `anim_early_bird`, `secret_midnight`, `secret_new_year`, auto-freeze (`end_time::date = CURRENT_DATE - 1`), objectifs hebdo — décalés de 1-2 h à Paris, ce qui peut gaspiller un freeze.
12. **Badges incohérents avec `badges.md`** : `v_goal_achieved_count := 0` codé en dur (`goal_achieved_1/5` jamais attribués) ; `social_reviews_50` sans branche ; `WHEN b.id = 'social_comments_%'` (= au lieu de LIKE) ; badges streak premium attribués aux gratuits ; `get_community_badge_unlocks` lit `ub.earned_at` (colonne inexistante).
13. **Dépôt de migrations non rejouable** : préfixes en double (20260713, 20260720, 20260722×5, 20260814×4, 20260820, 20260912), objets non créés dans le repo, migrations non idempotentes.

## B. Edge Functions

1. **`revenuecat-webhook`** : erreurs d'écriture BDD loggées mais réponse 200 (un blip sur `EXPIRATION` laisse `is_premium=true` à vie) ; aucun contrôle d'ordre/rejeu (`event_timestamp_ms`, `event.id`) ; remboursement non traité.
2. **OAuth Notion sans `state`** (`notion_service.dart:60`, `notion-oauth-redirect`) : CSRF de liaison de workspace via `lexday://notion/callback?code=…`.
3. **`grant-referral-reward`** : statut `rewarded` écrit même si un grant RevenueCat échoue → récompense perdue définitivement.
4. **`ai-chat` : historique tronqué du mauvais côté** (`index.ts:580-584`, `ascending:true` + `limit(20)` = les 20 PREMIERS messages). Dès le 21e message, Muse ne voit plus les nouveaux. Vérifié.
5. **Quotas IA contournables en parallèle** (compter → appeler OpenAI → insérer l'usage) : `ai-suggest-books` (gpt-4o), `enhance-ocr`, `summarize-passage`, `transcribe-audio`, `ai-chat`. Fix : réserver la ligne avant l'appel.
6. **`send-streak-reminders`** : pagination sur `ORDER BY user_id` non unique ; « aujourd'hui » et flow calculés en UTC ; balayage complet de `reading_sessions` toutes les 15 min.
7. **FCM périmés non nettoyés** dans `send-push-notification` et `send-wrapped-notification` ; Wrapped envoyé en séquence à tous (risque de timeout) y compris aux inactifs ; `send-push-notification` renvoie toujours 200.
8. Mineurs : `sync-literary-prizes` vide la liste avant réinsertion ; `refresh-covers` retraite les 200 mêmes livres ; `sync-notion-reading-sheet` confond 400 de validation et 404, ne supprime que 100 blocs ; `moderate-comment` injectable par prompt et fail-open ; comparaisons de secrets non constantes sur 6 fonctions cron ; `import-past-reads` : item non-objet → 500 ; `transcribe-audio` : `audio_path` non contraint à `user.id/`.

## C. Flutter — logique et données

- **C-DST. Flamme cassée au changement d'heure — échéance dim 25 → lun 26/10/2026** : `flow_service.dart:350,374,382,443,448` et `reading_flow.dart:73` font `subtract(Duration(days:1))` (24 h) sur des dates locales ; le 26/10 la veille tombe à 25/10 01:00 → `isActive=false` toute la journée, flamme tronquée. Fix : `DateTime(d.year, d.month, d.day - 1)`. Même défaut secondaire dans `monthly_notification_service.dart:~437`. **À corriger avant le 26/10.** Vérifié.
- **Auto-freeze client gaspillé** (`flow_service.dart:156-186`) : appelé si `lastRead == hier` ; la RPC `use_streak_freeze` ne vérifie pas que « hier » n'a pas été lu (seul le cron le fait).
- **Sessions fantômes** : `insertPastSession` (`reading_session_service.dart:868-893`) INSERT puis UPDATE sans compensation → session ouverte qui bloque « J'ai lu »/démarrage ; `startSession` peut aussi créer un doublon si l'INSERT aboutit malgré le timeout de 10 s (pas d'id idempotent).
- **File offline** (`offline_session_queue.dart:193,277,288-327`) : lectures/écritures de snapshot sans verrou → une fin de session mise en file pendant `syncAll` peut disparaître ou être dupliquée.
- **Déconnexion ne purge pas l'état local** : `FeedCache`, clés `offline_pending_*` (non filtrées par user), cookies/WorkManager Kindle, widget iOS, `SessionPauseService`. Appareil partagé ou test multi-comptes : feed et sessions de l'ancien compte, import Kindle de A dans B.
- **Défis** (`challenge_service.dart`) : `read_book` `completed: true` inconditionnel dès la 1re session (l.231-240) ; `read_daily` +1 par session et non par jour (l.252-261). Vérifié.
- **Compteur de membres de club toujours 1** (`groups_service.dart:96-117`, `(… as List).length` sur `group_members(count)`). Vérifié.
- **Bibliothèque limitée à 100 livres** (`user_books_page.dart:67`, `books_service.dart:360` `clamp(1,100)`, pas de loadMore) ; pagination 1000 lignes oubliée dans `flow_service:212`, `statistics_service:502`, `reading_session_service:981`.
- **Modération du pseudo jamais détectée** quand un ancien pseudo existe (`display_name_moderation.dart:18-28`) : l'Edge Function remet l'ancien pseudo → le trigger repasse en `pending` puis `approved` → l'app affiche « Nom mis à jour » alors que le pseudo a été annulé.
- **`is_too_fast` toujours faux dans l'écran de résumé** (posé après `endSession` par `check_and_award_secret_badges`) → bannière jamais affichée, confettis possibles sur session exclue.
- **`ensureFreshSession()` sans timeout** (`jwt_retry.dart:25`), exécuté avant les timeouts du fallback offline et attendu dans `_onAppResumed` : écran figé en réseau dégradé.
- Mineurs : abandon d'un « J'ai lu » en erreur ; objectifs désactivés puis INSERT non atomique (`goals_service.dart:60-139`) ; sync Kindle arrière-plan qui recrée des livres supprimés ; pause non nettoyée sans Live Activity (`reading_session_service.dart:248`) ; FCM `_tokenRegistered` posé avant succès + `clearToken` fragile ; PostHog reçoit l'e-mail en clair sans opt-out (`auth_gate.dart:79`).

## D. Flutter — UI

1. **Abandon de session** (`active_reading_session_page.dart:248-262`) : échec du DELETE avalé, pauses/Live Activity déjà effacées, navigation comme si tout allait bien.
2. **Couvertures en placeholder jusqu'au redémarrage** après un timeout réseau (`cached_book_cover.dart:425,505`) : l'échec est mis en cache négatif.
3. **Onboarding bloqué sans issue** (`step_manual_add.dart:36-77`, `onboarding_page.dart:303-366`) : « Suivant » désactivé sans livre, `_search/_addBook` avalent les erreurs ; `profiles.update` sans try/catch ; double tap sur « Lire » → 2 pages empilées.
4. **Achat Premium sans retour d'erreur** (`upgrade_page.dart:117-133`, `subscription_service.dart:172`) : paiement en attente / erreur store → spinner qui s'arrête, rien d'affiché.
5. **Profil d'ami** (`friend_profile_page.dart:276-356`) : demande reçue présentée comme envoyée (« Annuler » ne supprime rien, pas de « Accepter »).
6. **Prix et plan en dur** dans `manage_subscription_page.dart:79-95` (39,99 €/an) : faux pour USD/GBP/promo — risque store.
7. **~150 chaînes françaises en dur** dans ~50 fichiers + ~55 `'Erreur: $e'` bruts (liste détaillée disponible), contraire à CLAUDE.md. Les 3 `.arb` sont cohérents (1383 clés chacun).
8. Réglages de club : comparaison contre `widget.group` jamais rafraîchi ; flux Realtime recréé à chaque rebuild de `feed_header.dart:337` ; pagination d'historique qui s'arrête sur erreur réseau (`getSessionsPaginated` renvoie `[]`) ; `setState` sans `mounted` (`user_books_page:1346`, `start_reading_session_page_unified:235`, `group_*`, `active_reading_session_page:66`) ; 26 `TextRecognizer` natifs jamais fermés ; `friend_book_detail_page` sans `ConstrainedContent` ; `retrieveLostData` absent (Android) ; feuille de capture de passage fermable par swipe ; confettis figés (`reading_session_summary_page:867`) ; bannières empilées qui additionnent les SafeArea (`main_navigation:891`) ; textes FR en dur dans `badges_service.dart:103` et `community_badge_unlock_card.dart:59` (visibles EN/ES depuis la carte d'amis).
9. Déjà connus et toujours présents : `width: double.infinity` de `group_list_detail_page.dart:261`, listeners audio empilés, `currentUser!` dans `queueStartSession`, `DEV_FORCE_PREMIUM` sans garde `kReleaseMode`, `_initializeAndNavigate()` sans `catchError`.

## Non couvert
`kindle_webview_service.dart` (script JS et parseurs), `lexday_sync_service`, `ai_service`, `contacts_service`, `annotation_service`, `lexday-web/`, `kindle_extension/`, `remotion/`, tests. Aucune exécution : `flutter analyze` et les tests restent à lancer sur le Mac.
