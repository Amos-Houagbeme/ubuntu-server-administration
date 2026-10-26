#!/usr/bin/env bash
#
# verifier-depot.sh
# Contrôles à lancer avant de publier le dépôt :
#
#   1. liens relatifs des documents Markdown
#   2. numéro de lab résiduel (« Lab 3 », « Lab 4 »...)
#   3. voix impersonnelle dans les documents (pas de « nous », « notre »...)
#   4. secrets et archives (clés privées, *.key, *.pem, *.tar.gz)
#   5. cases cochées [x] sans preuve liée
#   6. fichiers de preuve que aucun document ne référence
#   7. cohérence entre la page servie (https/page.html) et la sauvegarde testée
#   8. cohérence entre la configuration Nginx collectée et la configuration effective
#   9. fraîcheur de la capture HTTPS
#
# Usage : bash scripts/verifier-depot.sh [racine_du_depot]
# Code retour : 0 si aucune erreur (des avertissements sont possibles), 1 sinon.

set -Eeuo pipefail
export LC_ALL=C.UTF-8

RACINE="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$RACINE"

ERREURS=0
AVERTISSEMENTS=0

erreur()  { echo "  [ERREUR]        $*"; ERREURS=$((ERREURS + 1)); }
alerte()  { echo "  [AVERTISSEMENT] $*"; AVERTISSEMENTS=$((AVERTISSEMENTS + 1)); }
section() { echo; echo "== $* =="; }

DOCS=(README.md ROADMAP.md docs/*.md)

# --- 1. Liens relatifs --------------------------------------------------------
section "1. Liens relatifs des documents Markdown"
nb_liens=0
for doc in "${DOCS[@]}"; do
    dossier="$(dirname "$doc")"
    while IFS= read -r cible; do
        nb_liens=$((nb_liens + 1))
        if [[ ! -e "${dossier}/${cible}" ]]; then
            erreur "${doc} : lien cassé -> ${cible}"
        fi
    done < <(grep -oE '\]\([^)#[:space:]]+' "$doc" | sed 's/^](//' | grep -vE '^(https?:|mailto:)' || true)
done
echo "  ${nb_liens} lien(s) vérifié(s)"

# --- 2. Numéro de lab ---------------------------------------------------------
section "2. Numéro de lab résiduel"
while IFS= read -r ligne; do
    erreur "${ligne}"
done < <(grep -rnE 'Lab [0-9]+' --include='*.md' --include='*.html' . || true)

# --- 3. Voix impersonnelle ----------------------------------------------------
section "3. Voix impersonnelle (README, ROADMAP, docs)"
while IFS= read -r ligne; do
    erreur "${ligne}"
done < <(grep -nEiw 'nous|notre|nos|séance' "${DOCS[@]}" || true)

# --- 4. Secrets et archives ---------------------------------------------------
section "4. Secrets et archives"
while IFS= read -r fichier; do
    erreur "fichier à ne pas publier : ${fichier}"
done < <(find . -path ./.git -prune -o -type f \
    \( -name '*.key' -o -name '*.pem' -o -name '*.tar.gz' -o -name 'id_*' \) ! -name '*.pub' -print)
while IFS= read -r fichier; do
    erreur "clé privée détectée dans : ${fichier}"
done < <(grep -rIl 'PRIVATE KEY' . --exclude-dir=.git --exclude=verifier-depot.sh || true)
if [[ ! -f .gitignore ]]; then
    alerte ".gitignore absent"
fi

# --- 5. Cases cochées sans preuve --------------------------------------------
section "5. Cases cochées sans preuve liée"
while IFS= read -r ligne; do
    erreur "${ligne}"
done < <(grep -nE '\[x\]' "${DOCS[@]}" | grep -vE '\]\(' || true)

# --- 6. Preuves non référencées ----------------------------------------------
section "6. Preuves non référencées par un document"
while IFS= read -r fichier; do
    if ! grep -qF "$(basename "$fichier")" "${DOCS[@]}"; then
        alerte "${fichier}"
    fi
done < <(find infrastructure reseau ssh ufw nginx https backup -type f | sort)

# --- 7. Page servie et sauvegarde testée --------------------------------------
section "7. Page servie (https/page.html) et sauvegarde testée"
if [[ -f https/page.html && -f backup/restore-test.txt ]]; then
    taille_page="$(stat -c '%s' https/page.html)"
    taille_sauvegarde="$(grep -m1 -E 'public/index\.html  [0-9]+ octets' backup/restore-test.txt \
        | sed -E 's/.*index\.html  ([0-9]+) octets.*/\1/' || true)"
    if [[ -z "$taille_sauvegarde" ]]; then
        alerte "taille d'index.html introuvable dans backup/restore-test.txt"
    elif [[ "$taille_page" != "$taille_sauvegarde" ]]; then
        erreur "https/page.html (${taille_page} octets) diffère de l'index.html sauvegardé et testé (${taille_sauvegarde} octets) : recopier la page depuis le serveur, puis relancer la sauvegarde et sa vérification"
    else
        echo "  page.html : ${taille_page} octets, identique à l'index.html testé"
    fi
else
    alerte "https/page.html ou backup/restore-test.txt absent"
fi

# --- 8. Configuration Nginx ---------------------------------------------------
section "8. Configuration Nginx collectée et configuration effective"
if [[ -f nginx/nginx-effective.txt && -f nginx/default.conf ]]; then
    if grep -q 'return 301' nginx/nginx-effective.txt && ! grep -qE '^[[:space:]]*return 301' nginx/default.conf; then
        erreur "nginx/default.conf ne contient pas la redirection 301 relevée dans nginx/nginx-effective.txt : recopier /etc/nginx/sites-available/default"
    else
        echo "  redirection 301 cohérente entre nginx-effective.txt et default.conf"
    fi
else
    alerte "nginx/nginx-effective.txt ou nginx/default.conf absent"
fi

# --- 9. Capture HTTPS ---------------------------------------------------------
section "9. Fraîcheur de la capture HTTPS"
if [[ -f https/https-capture.png && -f https/page.html ]]; then
    if [[ https/https-capture.png -ot https/page.html ]]; then
        alerte "https/https-capture.png est plus ancienne que https/page.html : elle montre peut-être une ancienne version de la page"
    else
        echo "  capture postérieure à la page"
    fi
fi

# --- Synthèse -----------------------------------------------------------------
echo
echo "Résultat : ${ERREURS} erreur(s), ${AVERTISSEMENTS} avertissement(s)"
if [[ "$ERREURS" -gt 0 ]]; then
    exit 1
fi
