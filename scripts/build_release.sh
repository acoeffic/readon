#!/usr/bin/env bash
#
# build_release.sh
# ----------------
# Build l'AAB de release LexDay avec :
#   - signature via android/key.properties
#   - secrets injectés depuis env.json (Dart + manifest Android)
#
# Usage : bash scripts/build_release.sh
#
set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- Pré-vérifications ----------
if [[ ! -f "android/key.properties" ]]; then
  echo -e "${RED}Erreur:${NC} android/key.properties manquant."
  echo "       Lance d'abord : bash scripts/setup_keystore.sh"
  exit 1
fi

if [[ ! -f "env.json" ]]; then
  echo -e "${RED}Erreur:${NC} env.json manquant à la racine du projet."
  echo "       Copie env.example.json vers env.json et remplis les valeurs."
  exit 1
fi

if [[ ! -f "android/app/google-services.json" ]]; then
  echo -e "${RED}Erreur:${NC} android/app/google-services.json manquant."
  echo "       Télécharge-le depuis Firebase Console (projet readon-fc5d9)."
  exit 1
fi

# ---------- Affichage de la version qu'on s'apprête à builder ----------
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo -e "${BOLD}>>> Build LexDay version $VERSION${NC}"
echo

# ---------- Build ----------
flutter clean
flutter build appbundle --release --dart-define-from-file=env.json

# ---------- Récap ----------
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$AAB_PATH" ]]; then
  SIZE=$(du -h "$AAB_PATH" | cut -f1)
  echo
  echo -e "${BOLD}${GREEN}========================================${NC}"
  echo -e "${BOLD}${GREEN}  AAB build avec succès${NC}"
  echo -e "${BOLD}${GREEN}========================================${NC}"
  echo
  echo -e "${BOLD}Fichier :${NC} $PROJECT_ROOT/$AAB_PATH"
  echo -e "${BOLD}Taille :${NC}  $SIZE"
  echo -e "${BOLD}Version :${NC} $VERSION"
  echo
  echo -e "${YELLOW}Prochaine étape : upload sur Play Console${NC}"
  echo "  https://play.google.com/console"
else
  echo -e "${RED}Erreur:${NC} le build a échoué (AAB introuvable)"
  exit 1
fi
