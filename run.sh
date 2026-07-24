#!/usr/bin/env bash
# run.sh — Lance les tests Maestro sur un simulateur iOS 18.4.
# Usage :
#   ./run.sh                                  # run tous les flows
#   ./run.sh maestro/flows/auth/login.yaml    # run un seul flow
#   ./run.sh --no-build                       # skip build/install, run direct
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Maestro est installé dans ~/.maestro/bin par le script officiel.
export PATH="$HOME/.maestro/bin:$PATH"

# iOS 18.4 — GoogleMLKit (utilisé pour l'OCR de pages) ne compile pas sur iOS 26.
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16 Pro}"
SIMULATOR_RUNTIME="${SIMULATOR_RUNTIME:-iOS 18.4}"
BUNDLE_ID="fr.lexday.app"
APP_PATH="build/ios/iphonesimulator/Runner.app"

NO_BUILD=0
TARGET="maestro/flows"
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    *) TARGET="$arg" ;;
  esac
done

if ! command -v maestro >/dev/null 2>&1; then
  echo "❌ maestro introuvable. Installe via : curl -fsSL \"https://get.maestro.mobile.dev\" | bash" >&2
  exit 1
fi

# Trouve l'UDID du simulateur cible (premier match nom + runtime).
echo "🔎 Cherche un simulateur \"${SIMULATOR_NAME}\" sous ${SIMULATOR_RUNTIME}…"
UDID=$(xcrun simctl list devices available --json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
runtime_key = next((k for k in data['devices'] if '$SIMULATOR_RUNTIME'.replace(' ', '-').replace('.', '-') in k or '$SIMULATOR_RUNTIME' in k), None)
if not runtime_key:
    sys.exit('Runtime \"$SIMULATOR_RUNTIME\" introuvable.')
for d in data['devices'][runtime_key]:
    if d['name'] == '$SIMULATOR_NAME':
        print(d['udid'])
        sys.exit(0)
sys.exit('Simulateur \"$SIMULATOR_NAME\" introuvable sur $SIMULATOR_RUNTIME.')
")

echo "✅ Simulateur : $UDID"

# Boot si nécessaire.
state=$(xcrun simctl list devices --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime in data['devices'].values():
    for d in runtime:
        if d['udid'] == '$UDID':
            print(d['state'])
            sys.exit(0)
")
if [ "$state" != "Booted" ]; then
  echo "🚀 Boot du simulateur…"
  xcrun simctl boot "$UDID"
  open -a Simulator
  # Le simulateur prend 5–15s à finir de boot.
  xcrun simctl bootstatus "$UDID" -b
fi

# Build + install
if [ "$NO_BUILD" -eq 0 ]; then
  if [ ! -f env.json ]; then
    echo "❌ env.json manquant (variables d'env Flutter). Voir .env.example pour Maestro." >&2
    exit 1
  fi
  echo "🔨 Build iOS simulator (debug)…"
  flutter build ios --simulator --debug --dart-define-from-file=env.json
  echo "📦 Install sur ${UDID}…"
  xcrun simctl install "$UDID" "$APP_PATH"
fi

# Vérifie .env Maestro
if [ ! -f maestro/.env ]; then
  echo "⚠️  maestro/.env manquant — copie depuis .env.example et remplis tes credentials."
  cp maestro/.env.example maestro/.env
fi

# Run. Maestro CLI ne supporte pas --env-file → on construit --env KEY=VAL
# pour chaque ligne non vide / non commentaire de maestro/.env.
ENV_ARGS=()
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  ENV_ARGS+=(--env "$line")
done < maestro/.env

echo "🎬 maestro test $TARGET"
maestro test "$TARGET" "${ENV_ARGS[@]}"
