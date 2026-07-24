# Tests e2e Maestro — LexDay / Readon

Tests end-to-end iOS pilotés par [Maestro](https://maestro.mobile.dev). Bundle ID : `fr.lexday.app`.

## Pré-requis

1. **Maestro CLI**
   ```bash
   curl -fsSL "https://get.maestro.mobile.dev" | bash
   export PATH="$HOME/.maestro/bin:$PATH"
   maestro -v
   ```

2. **Simulateur iOS 18.4** (déjà installé sur la machine de dev).
   ⚠️ **Pas iOS 26.x** : `google_mlkit_text_recognition` (OCR de pages) ne compile pas sur le runtime iOS 26.

3. **env.json** à la racine (variables d'env Flutter, déjà existant).

4. **maestro/.env** (jamais commité)
   ```bash
   cp maestro/.env.example maestro/.env
   # remplis TEST_EMAIL / TEST_PASSWORD / TEST_BOOK_QUERY avec un compte de test dédié
   ```

## Lancement

Script wrapper qui boot le simulateur, build l'app, l'installe, puis lance les flows :

```bash
./run.sh                                       # tous les flows
./run.sh maestro/flows/auth/login.yaml         # un seul flow
./run.sh --no-build                            # skip build (utile si déjà installé)
```

Variables d'env optionnelles :
- `SIMULATOR_NAME` (défaut : `iPhone 16 Pro`)
- `SIMULATOR_RUNTIME` (défaut : `iOS 18.4`)

## Arborescence

```
maestro/
├── flows/                          # un fichier par parcours testable
│   ├── auth/login.yaml             # email/password
│   ├── onboarding/onboarding.yaml  # 1re ouverture, chemin "Papier"
│   ├── reading/session_lecture.yaml
│   ├── social/feed.yaml
│   ├── clubs/club.yaml
│   └── premium/paywall.yaml        # display only — ne déclenche PAS l'achat
├── subflows/                       # réutilisables via runFlow
│   ├── login_subflow.yaml          # ${TEST_EMAIL}/${TEST_PASSWORD}
│   └── handle_system_dialogs.yaml  # autorisations push / contacts (optional: true)
└── .env.example                    # placeholders — JAMAIS de credentials réels
```

## Ajouter un flow

1. Crée le YAML sous `maestro/flows/<catégorie>/`.
2. Commence par :
   ```yaml
   appId: fr.lexday.app
   name: mon_flow
   ---
   - launchApp
   - runFlow: ../../subflows/handle_system_dialogs.yaml
   ```
3. Privilégie les **`id:`** (Semantics identifiers) avant le matching par texte.
   Liste des identifiers ajoutés au code :
   - `login_email_field`, `login_password_field`
   - `start_session_fab` (FAB liquid glass)
   - `book_search_field` (sheet "Ma bibliothèque")
   - `manual_page_input` (page "Démarrer")

4. Si un nouveau widget n'a pas de sélecteur stable : ajoute un
   `Semantics(identifier: 'snake_case')` autour, **sans toucher au design**.

5. Pour les tests qui exigent un compte connecté : `runFlow: ../../subflows/login_subflow.yaml`.

## Note sur les device physiques

Le simulateur est officiellement supporté par Maestro. Pour iOS device réel, il
faut le pont communautaire [`maestro-ios-device`](https://github.com/mobile-dev-inc/maestro/discussions/1981).
Team ID Apple pour le signing : `9WN55FN2D3`.

## Onboarding : limitation connue

`flows/onboarding/onboarding.yaml` **ne traverse pas** les vrais widgets
d'onboarding (step_welcome, step_reading_habit, etc.). Raison : la
`OnboardingPage` n'est routée que pour un compte signé dont
`profiles.onboarding_completed = false` côté Supabase. Depuis un `clearState`
seul, l'app va sur `LoginPage`. Le flow teste donc le chemin **1re ouverture →
mode invité → feed**, ce qui valide le launch, la gestion de la popup notif
iOS et le rendu du main nav.

Pour tester le vrai onboarding : créer un compte fixture côté Supabase avec
`onboarding_completed=false`, l'utiliser dans `login_subflow`, puis enchaîner
les taps sur "Commencer" / "Papier" / "Suivant" / "Passer cette étape".

## Paywall : limitation connue

`flows/premium/paywall.yaml` **n'achète rien**. RevenueCat est en
`CONFIGURATION_ERROR` tant que la 1re soumission App Store n'est pas passée.
Le flow s'arrête à l'affichage des prix de fallback ("/mois", "Annuel",
"Mensuel" doivent être visibles).

Si le paywall natif iOS 17+ (`SubscriptionStoreView`) est présenté à la place
de l'UI Flutter (`UpgradePage`), Maestro ne pourra pas interagir avec la sheet
native — c'est attendu. Forcer le fallback Flutter pour les tests si besoin.

## Debugging

- `maestro studio` : UI live pour explorer la hiérarchie accessibility en
  temps réel et tester des commandes.
- `maestro test --debug-output /tmp/maestro-debug <flow>` : génère screenshots
  et logs détaillés.
- Si un `tapOn` échoue, `maestro hierarchy` dump l'arbre courant.
