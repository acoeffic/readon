#!/usr/bin/env bash
#
# setup_keystore.sh
# ------------------
# Génère le keystore d'upload pour LexDay (Google Play App Signing).
#
# Ce script :
#   1. Crée ~/.android-keystores/ si nécessaire
#   2. Génère des mots de passe aléatoires forts (32 caractères)
#   3. Crée le keystore lexday.jks (alias: upload, validité 30 ans)
#   4. Écrit android/key.properties avec les credentials (gitignoré)
#   5. Affiche un résumé à sauvegarder dans votre password manager
#
# IMPORTANT — la clé d'upload doit être conservée précieusement.
# Avec Play App Signing, si elle est perdue, Google peut la réinitialiser
# (contrairement à la clé de signature finale qu'ils gardent).
#
# Usage : bash scripts/setup_keystore.sh
#

set -eu

# ---------- Couleurs pour la sortie ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}>>> setup_keystore.sh — démarrage${NC}"

# ---------- Détection du chemin du projet ----------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# ---------- Configuration ----------
KEYSTORE_DIR="$HOME/.android-keystores"
KEYSTORE_PATH="$KEYSTORE_DIR/lexday.jks"
KEY_ALIAS="upload"
VALIDITY_DAYS=10950  # ~30 ans (Google exige >= 2050)
DNAME="CN=LexDay, OU=Mobile, O=LexDay, L=Paris, S=Ile-de-France, C=FR"
KEY_PROPS_PATH="$PROJECT_ROOT/android/key.properties"

# ---------- Vérification keytool + JDK ----------
echo -e "${GREEN}>>> Vérification keytool + JDK...${NC}"
if ! command -v keytool >/dev/null 2>&1; then
  echo -e "${RED}Erreur:${NC} keytool introuvable. Installe un JDK :"
  echo "  brew install --cask temurin"
  exit 1
fi
echo -e "    keytool: $(command -v keytool)"

# Sur macOS, /usr/bin/keytool est un stub qui nécessite un vrai JDK.
# On vérifie qu'il est utilisable (sinon le binaire existe mais échoue avec
# "Unable to locate a Java Runtime").
if ! keytool -help >/dev/null 2>&1; then
  echo -e "${RED}Erreur:${NC} keytool est présent mais aucun JDK n'est installé."
  echo "  Installe-en un :"
  echo "    brew install --cask temurin"
  echo "  Puis relance ce script."
  exit 1
fi

# ---------- Vérification openssl ----------
if ! command -v openssl >/dev/null 2>&1; then
  echo -e "${RED}Erreur:${NC} openssl introuvable (devrait être installé par défaut sur macOS)."
  exit 1
fi

# ---------- Vérification keystore existant ----------
if [[ -f "$KEYSTORE_PATH" ]]; then
  echo -e "${YELLOW}!! Un keystore existe déjà à $KEYSTORE_PATH${NC}"
  read -r -p "Le remplacer ? (les anciens mots de passe seront perdus) [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Abandon."
    exit 0
  fi
  rm "$KEYSTORE_PATH"
fi

# ---------- Création du dossier ----------
mkdir -p "$KEYSTORE_DIR"
chmod 700 "$KEYSTORE_DIR"

# ---------- Génération des mots de passe ----------
# 32 caractères hex via openssl (128 bits d'entropie, pas de pipe SIGPIPE-prone,
# pas de caractères spéciaux qui posent problème dans les .properties)
gen_pass() {
  openssl rand -hex 16
}

echo -e "${GREEN}>>> Génération du mot de passe...${NC}"
# Les JDKs récents créent des keystores PKCS12 où store-pass et key-pass DOIVENT
# être identiques (le warning "Ignoring user-specified -keypass" l'indique).
# On utilise donc un seul mot de passe pour les deux.
STORE_PASS=$(gen_pass)
KEY_PASS="$STORE_PASS"

# ---------- Génération du keystore ----------
echo -e "${GREEN}>>> Génération du keystore...${NC}"
keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "$DNAME"

chmod 600 "$KEYSTORE_PATH"

# ---------- Écriture de key.properties ----------
echo -e "${GREEN}>>> Écriture de android/key.properties...${NC}"
cat > "$KEY_PROPS_PATH" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=$KEYSTORE_PATH
EOF

chmod 600 "$KEY_PROPS_PATH"

# ---------- Récapitulatif ----------
echo
echo -e "${BOLD}${GREEN}========================================${NC}"
echo -e "${BOLD}${GREEN}  Keystore généré avec succès${NC}"
echo -e "${BOLD}${GREEN}========================================${NC}"
echo
echo -e "${BOLD}Keystore :${NC}      $KEYSTORE_PATH"
echo -e "${BOLD}Alias :${NC}         $KEY_ALIAS"
echo -e "${BOLD}Validité :${NC}      $VALIDITY_DAYS jours (~$(($VALIDITY_DAYS / 365)) ans)"
echo -e "${BOLD}key.properties :${NC} $KEY_PROPS_PATH"
echo
echo -e "${YELLOW}${BOLD}!! À SAUVEGARDER DANS UN PASSWORD MANAGER !!${NC}"
echo
echo -e "${BOLD}Mot de passe :${NC} $STORE_PASS"
echo -e "${BOLD}(identique pour storePassword et keyPassword — keystore PKCS12)${NC}"
echo
echo -e "${YELLOW}Empreintes du certificat (utiles pour Firebase, Google Sign-In, etc.) :${NC}"
echo
# JVM en anglais : évite le bug `MissingFormatArgumentException %2$s` que les
# locales fr/it ont dans `printX509Cert` sur certains builds Temurin.
keytool -J-Duser.language=en -J-Duser.country=US -list -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -storepass "$STORE_PASS" \
  | grep -iE "SHA[-]?(1|256):" || true
echo
echo -e "${BOLD}Prochaine étape :${NC} flutter build appbundle --release"
echo
echo -e "${YELLOW}!! Une fois les mots de passe sauvegardés, efface l'historique du terminal :${NC}"
echo -e "    history -c && history -w   (zsh : history -p)"
