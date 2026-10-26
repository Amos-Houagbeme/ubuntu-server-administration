#!/usr/bin/env bash
#
# verifier-sauvegarde.sh
# Vérifie une sauvegarde du lab Linux et enregistre une preuve texte par contrôle :
#
#   1. sha256sum -c   -> sha256-check.txt
#   2. gzip -tv       -> gzip-test.txt
#   3. restauration dans /var/tmp/restore-test, puis comparaison de TOUS les fichiers
#      de l'archive avec le système actif (contenu, droits, propriétaire)
#                     -> restore-test.txt
#   4. politique de rétention, testée sur une COPIE du script de sauvegarde et un
#      répertoire jetable contenant des archives factices
#                     -> retention-test.txt
#
# Aucune sauvegarde réelle et aucun fichier actif n'est modifié ni supprimé : les
# seules écritures se font dans le dossier de preuves et dans /var/tmp (nettoyé).
#
# Usage : sudo bash verifier-sauvegarde.sh [archive.tar.gz]
#   Sans argument, l'archive la plus récente de BACKUP_DIR est contrôlée.
#   Variables facultatives : BACKUP_DIR, BACKUP_SCRIPT, EVIDENCE_DIR

set -Eeuo pipefail

# --- Paramètres ---------------------------------------------------------------
BACKUP_DIR="${BACKUP_DIR:-/var/backups/lab-linux}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-/usr/local/sbin/backup-lab-linux}"
RESTORE_DIR="/var/tmp/restore-test"
TEMOIN="var/www/lab-site/public/index.html"   # fichier témoin, chemin relatif à /
KEEP=7                                        # archives conservées par le script
HOST_SHORT="$(hostname -s)"
OWNER="${SUDO_USER:-root}"

TMP_PATHS=()          # éléments temporaires à supprimer à la sortie
ECHEC_ETAPE=0         # passe à 1 si un contrôle de l'étape en cours échoue
declare -A RESULTATS=()

# --- Vérifications préalables -------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "ERREUR : exécute ce script avec sudo." >&2
    exit 1
fi

OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)" || {
    echo "ERREUR : utilisateur introuvable : ${OWNER}" >&2
    exit 1
}
OWNER_GROUP="$(id -gn "$OWNER")"
EVIDENCE_DIR="${EVIDENCE_DIR:-${OWNER_HOME}/lab-evidence/backup}"

if [[ $# -ge 1 ]]; then
    ARCHIVE="$(readlink -f -- "$1")"
else
    # Les noms (JJ-MM-AAAA) ne se trient pas par date : on se fie à l'heure de modification.
    ARCHIVE="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${HOST_SHORT}_*.tar.gz" \
        -printf '%T@ %p\n' | sort -nr | sed -n '1p' | cut -d ' ' -f 2-)"
fi

if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
    echo "ERREUR : aucune archive trouvée (${BACKUP_DIR})." >&2
    exit 1
fi
if [[ ! -f "${ARCHIVE}.sha256" ]]; then
    echo "ERREUR : somme de contrôle introuvable : ${ARCHIVE}.sha256" >&2
    exit 1
fi

# Le dossier de preuves appartient à l'utilisateur qui a lancé sudo, pas à root.
runuser -u "$OWNER" -- mkdir -p -- "$EVIDENCE_DIR" || {
    echo "ERREUR : impossible de créer ${EVIDENCE_DIR}." >&2
    exit 1
}

# --- Fonctions communes -------------------------------------------------------
nettoyer() {
    local chemin
    for chemin in "${TMP_PATHS[@]}"; do
        case "$chemin" in
            /var/tmp/?*) rm -rf --one-file-system -- "$chemin" ;;
        esac
    done
}
trap nettoyer EXIT

en_tete() {   # $1 = titre ; $2 = "archive" pour afficher l'archive contrôlée
    echo "=================================================================="
    echo "$1"
    echo "=================================================================="
    echo "Date    : $(date '+%d/%m/%Y %H:%M:%S %Z')"
    echo "Serveur : ${HOST_SHORT}"
    if [[ "${2:-}" == "archive" ]]; then
        echo "Archive : ${ARCHIVE}"
        echo "Taille  : $(stat -c '%s' -- "$ARCHIVE") octets, modifiée le" \
            "$(stat -c '%y' -- "$ARCHIVE" | cut -d. -f1)"
    fi
    echo
}

fin_etape() {   # $1 = 0 si succès ; affiche le résultat et le renvoie
    echo
    if [[ "$1" -eq 0 ]]; then
        echo "RÉSULTAT : SUCCÈS"
    else
        echo "RÉSULTAT : ÉCHEC"
    fi
    return "$1"
}

controle() {   # $1 = libellé ; $2 = 0 si le contrôle est réussi
    if [[ "$2" -eq 0 ]]; then
        echo "  [OK]     $1"
    else
        echo "  [ÉCHEC]  $1"
        ECHEC_ETAPE=1
    fi
}

lancer_etape() {   # $1 = fichier de preuve ; $2 = fonction de l'étape
    local fichier="$1" fonction="$2" rc=0
    ECHEC_ETAPE=0
    "$fonction" > "${EVIDENCE_DIR}/${fichier}" 2>&1 || rc=$?
    cat -- "${EVIDENCE_DIR}/${fichier}"
    echo
    if [[ "$rc" -eq 0 ]]; then
        RESULTATS["$fichier"]="SUCCÈS"
    else
        RESULTATS["$fichier"]="ÉCHEC"
    fi
}

liste_dossier() {   # archives et sommes d'un répertoire, de la plus ancienne à la plus récente
    find "$1" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.sha256' \) \
        -printf '%TY-%Tm-%Td %TH:%TM  %f\n' | sort
}

# Compare un fichier restauré avec son équivalent actif. Renvoie 0 s'ils sont identiques.
comparer_membre() {
    local membre="$1"
    local actif="/${membre}"
    local restaure="${RESTORE_DIR}/${membre}"
    local cible_r cible_a meta_r meta_a

    if [[ -L "$restaure" ]]; then
        cible_r="$(readlink -- "$restaure")"
        cible_a="$(readlink -- "$actif" 2>/dev/null || true)"
        if [[ "$cible_r" == "$cible_a" ]]; then
            echo "  [OK]         lien      ${membre} -> ${cible_r}"
            return 0
        fi
        echo "  [DIFFÉRENT]  lien      ${membre} (restauré -> ${cible_r}, actif -> ${cible_a:-absent})"
        return 1
    fi

    if [[ ! -e "$actif" ]]; then
        echo "  [ABSENT]     ${membre} (n'existe plus sur le système actif)"
        return 1
    fi
    if ! cmp -s -- "$restaure" "$actif"; then
        echo "  [DIFFÉRENT]  contenu   ${membre}"
        return 1
    fi
    meta_r="$(stat -c '%a %U:%G' -- "$restaure")"
    meta_a="$(stat -c '%a %U:%G' -- "$actif")"
    if [[ "$meta_r" != "$meta_a" ]]; then
        echo "  [DIFFÉRENT]  droits    ${membre} (restauré : ${meta_r}, actif : ${meta_a})"
        return 1
    fi
    echo "  [OK]         ${meta_r}  ${membre}"
    return 0
}

# --- Étape 1 : somme SHA-256 --------------------------------------------------
etape_sha256() {
    en_tete "Contrôle d'intégrité SHA-256 de l'archive" archive
    local rc=0
    echo "\$ sha256sum -c ${ARCHIVE}.sha256"
    sha256sum -c -- "${ARCHIVE}.sha256" 2>&1 || rc=$?
    echo "Code retour : ${rc}"
    fin_etape "$rc"
}

# --- Étape 2 : flux gzip ------------------------------------------------------
etape_gzip() {
    en_tete "Test d'intégrité du flux gzip" archive
    local rc=0
    echo "\$ gzip -tv ${ARCHIVE}"
    gzip -tv -- "$ARCHIVE" 2>&1 || rc=$?
    echo "Code retour : ${rc}"
    fin_etape "$rc"
}

# --- Étape 3 : restauration + comparaison ------------------------------------
etape_restauration() {
    en_tete "Test de restauration dans un répertoire isolé" archive
    local rc=0 total=0 identiques=0 membre

    echo "Répertoire de test : ${RESTORE_DIR} (supprimé à la fin du test)"
    echo
    echo "--- 1. Contenu de l'archive ---"
    echo "\$ tar -tzf ${ARCHIVE}"
    if ! tar -tzf "$ARCHIVE"; then
        fin_etape 1
        return
    fi

    echo
    echo "--- 2. Extraction ---"
    case "$RESTORE_DIR" in
        /var/tmp/?*) ;;
        *) echo "ERREUR : répertoire de test refusé : ${RESTORE_DIR}"; fin_etape 1; return ;;
    esac
    TMP_PATHS+=("$RESTORE_DIR")
    rm -rf --one-file-system -- "$RESTORE_DIR"
    install -d -m 700 -- "$RESTORE_DIR"
    echo "\$ tar -xzpf ${ARCHIVE} -C ${RESTORE_DIR}"
    if ! tar -xzpf "$ARCHIVE" -C "$RESTORE_DIR"; then
        fin_etape 1
        return
    fi
    echo "Extraction terminée."

    echo
    echo "--- 3. Fichier témoin : /${TEMOIN} ---"
    echo "\$ stat -c '%n  %s octets  droits=%a  %U:%G' <restauré> <actif>"
    stat -c '%n  %s octets  droits=%a  %U:%G' -- "${RESTORE_DIR}/${TEMOIN}" "/${TEMOIN}" || rc=1
    echo "\$ diff -u ${RESTORE_DIR}/${TEMOIN} /${TEMOIN}"
    if diff -u -- "${RESTORE_DIR}/${TEMOIN}" "/${TEMOIN}"; then
        echo "(aucune différence)"
    else
        rc=1
    fi

    echo
    echo "--- 4. Comparaison de tous les fichiers de l'archive avec le système actif ---"
    echo "(contenu, droits, propriétaire:groupe ; pour un lien symbolique, sa cible)"
    while IFS= read -r membre; do
        if [[ -d "${RESTORE_DIR}/${membre}" && ! -L "${RESTORE_DIR}/${membre}" ]]; then
            continue   # les répertoires ne sont pas comptés
        fi
        total=$((total + 1))
        if comparer_membre "$membre"; then
            identiques=$((identiques + 1))
        fi
    done < <(tar -tzf "$ARCHIVE")

    echo
    echo "Fichiers comparés  : ${total}"
    echo "Identiques         : ${identiques}"
    echo "Différents/absents : $((total - identiques))"
    if [[ "$total" -eq 0 || "$identiques" -ne "$total" ]]; then
        rc=1
        echo
        echo "Si ces fichiers ont changé depuis la création de l'archive, relance la"
        echo "sauvegarde (sudo ${BACKUP_SCRIPT}) puis ce script."
    fi
    echo
    echo "Portée : ce test couvre les fichiers sauvegardés (contenu, droits, propriétaires)."
    echo "Il ne prouve pas la restauration complète du serveur : la clé privée TLS, par"
    echo "exemple, n'est volontairement pas dans l'archive."

    rm -rf --one-file-system -- "$RESTORE_DIR"
    fin_etape "$rc"
}

# --- Étape 4 : rétention ------------------------------------------------------
etape_retention() {
    en_tete "Test de la politique de rétention (${KEEP} archives conservées)"
    local n_faux=$((KEEP + 2)) n_suppr=3
    local i k c jours nom nouvelle nb_arch nb_sha test_dir copie rc_script=0
    local -a noms=()

    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
        echo "ERREUR : script de sauvegarde introuvable : ${BACKUP_SCRIPT}"
        fin_etape 1
        return
    fi
    if ! grep -q "ARCHIVES\[@\]:${KEEP}" "$BACKUP_SCRIPT"; then
        echo "ATTENTION : KEEP=${KEEP} ne correspond pas à la rétention lue dans le script ;"
        echo "            adapte la variable KEEP en tête de verifier-sauvegarde.sh."
        echo
    fi

    test_dir="$(mktemp -d /var/tmp/retention-test.XXXXXX)"
    copie="$(mktemp /var/tmp/backup-copie.XXXXXX)"
    TMP_PATHS+=("$test_dir" "$copie")
    chmod 700 "$test_dir"

    # Copie du script réellement installé, avec BACKUP_DIR redirigé vers le répertoire jetable.
    sed -E "s|^BACKUP_DIR=.*\$|BACKUP_DIR=\"${test_dir}\"|" "$BACKUP_SCRIPT" > "$copie"
    if ! grep -qF "BACKUP_DIR=\"${test_dir}\"" "$copie" || grep -qF "$BACKUP_DIR" "$copie"; then
        echo "ERREUR : impossible d'isoler la copie du script (BACKUP_DIR introuvable ou chemin"
        echo "         réel encore présent). Test annulé pour protéger les vraies sauvegardes."
        fin_etape 1
        return
    fi

    # Archives factices, de la plus ancienne (i = 1) à la plus récente (i = n_faux).
    for ((i = 1; i <= n_faux; i++)); do
        jours=$((n_faux + 1 - i))
        nom="${HOST_SHORT}_$(date -d "${jours} days ago" '+%d-%m-%Y__%H-%M-%S').tar.gz"
        : > "${test_dir}/${nom}"
        echo "0000000000000000000000000000000000000000000000000000000000000000  ${test_dir}/${nom}" \
            > "${test_dir}/${nom}.sha256"
        touch -d "${jours} days ago" -- "${test_dir}/${nom}" "${test_dir}/${nom}.sha256"
        noms+=("$nom")
    done

    echo "Répertoire jetable : ${test_dir}"
    echo "Archives factices  : ${n_faux} (de 1 à ${n_faux} jours), plus 1 vraie sauvegarde"
    echo "                     créée par la copie du script."
    echo "Résultat attendu   : ${KEEP} archives conservées, ${n_suppr} supprimées avec leur somme SHA-256."
    echo
    echo "--- AVANT ---"
    liste_dossier "$test_dir"
    echo
    echo "--- Exécution de la copie du script de sauvegarde (BACKUP_DIR isolé) ---"
    bash "$copie" 2>&1 || rc_script=$?
    echo "Code retour : ${rc_script}"
    echo "Journal du script :"
    if [[ -f "${test_dir}/backup.log" ]]; then
        sed 's/^/    /' "${test_dir}/backup.log"
    else
        echo "    (journal absent)"
    fi
    echo
    echo "--- APRÈS ---"
    liste_dossier "$test_dir"
    echo
    echo "--- Contrôles ---"

    nb_arch="$(find "$test_dir" -maxdepth 1 -type f -name '*.tar.gz' | wc -l)"
    nb_sha="$(find "$test_dir" -maxdepth 1 -type f -name '*.tar.gz.sha256' | wc -l)"
    controle "La copie du script s'est terminée sans erreur (code ${rc_script})" "$rc_script"
    controle "${KEEP} archives conservées (trouvé : ${nb_arch})" "$((nb_arch != KEEP))"
    controle "${KEEP} sommes SHA-256 conservées, aucune orpheline (trouvé : ${nb_sha})" \
        "$((nb_sha != KEEP))"
    for ((k = 0; k < n_faux; k++)); do
        nom="${noms[k]}"
        if ((k < n_suppr)); then
            if [[ ! -e "${test_dir}/${nom}" && ! -e "${test_dir}/${nom}.sha256" ]]; then c=0; else c=1; fi
            controle "Supprimée avec sa somme : ${nom}" "$c"
        else
            if [[ -f "${test_dir}/${nom}" && -f "${test_dir}/${nom}.sha256" ]]; then c=0; else c=1; fi
            controle "Conservée avec sa somme : ${nom}" "$c"
        fi
    done
    nouvelle="$(find "$test_dir" -maxdepth 1 -type f -name "${HOST_SHORT}_*.tar.gz" \
        -printf '%T@ %f\n' | sort -nr | sed -n '1p' | cut -d ' ' -f 2-)"
    if [[ -n "$nouvelle" && " ${noms[*]} " != *" ${nouvelle} "* && -f "${test_dir}/${nouvelle}.sha256" ]]; then
        c=0
    else
        c=1
    fi
    controle "La sauvegarde la plus récente (${nouvelle:-introuvable}) est conservée avec sa somme" "$c"

    echo
    echo "Les archives réelles de ${BACKUP_DIR} n'ont été ni lues ni modifiées : le test"
    echo "porte sur une copie du script installé (${BACKUP_SCRIPT}) et un répertoire jetable."
    fin_etape "$ECHEC_ETAPE"
}

# --- Exécution ----------------------------------------------------------------
lancer_etape "sha256-check.txt"   etape_sha256
lancer_etape "gzip-test.txt"      etape_gzip
lancer_etape "restore-test.txt"   etape_restauration
lancer_etape "retention-test.txt" etape_retention

chown "${OWNER}:${OWNER_GROUP}" "${EVIDENCE_DIR}"/{sha256-check,gzip-test,restore-test,retention-test}.txt
chmod 644 "${EVIDENCE_DIR}"/{sha256-check,gzip-test,restore-test,retention-test}.txt

echo "=================================================================="
echo "Synthèse"
echo "=================================================================="
global=0
for fichier in sha256-check.txt gzip-test.txt restore-test.txt retention-test.txt; do
    printf '  %-20s %s\n' "$fichier" "${RESULTATS[$fichier]}"
    [[ "${RESULTATS[$fichier]}" == "SUCCÈS" ]] || global=1
done
echo
echo "Preuves enregistrées dans : ${EVIDENCE_DIR}"
exit "$global"
