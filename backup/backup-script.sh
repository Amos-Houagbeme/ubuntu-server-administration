#!/usr/bin/env bash

# Arrêter le script en cas d'erreur.
set -Eeuo pipefail

# Répertoires et fichiers de sortie.
BACKUP_DIR="/var/backups/lab-linux"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Horodatage utilisé pour nommer l'archive.
TIMESTAMP="$(date +'%d-%m-%Y__%H-%M-%S')"
HOSTNAME_SHORT="$(hostname -s)"
ARCHIVE="${BACKUP_DIR}/${HOSTNAME_SHORT}_${TIMESTAMP}.tar.gz"

# Les données à sauvegarder, exprimées relativement à /.
BACKUP_PATHS=(
    "var/www/lab-site/public"
    "etc/nginx/sites-available/default"
    "etc/nginx/sites-available/lab-site-https"
    "etc/nginx/sites-enabled/default"
    "etc/nginx/sites-enabled/lab-site-https"
    "etc/netplan/01-lab-linux.yaml"
    "etc/ssh/sshd_config"
    "etc/ssh/sshd_config.d/00-security.conf"
    "home/dokja/.ssh/authorized_keys"
    "etc/ufw"
    "etc/default/ufw"
    "etc/ssl/certs/lab-site.crt"
    "home/dokja/scripts/backup.sh"
)

# Le script doit être exécuté avec les privilèges administrateur.
if [[ "$EUID" -ne 0 ]]; then
    echo "ERREUR : exécute ce script avec sudo." >&2
    exit 1
fi

# Protéger par défaut les nouveaux fichiers créés par le script.
umask 077

# Créer le répertoire de sauvegarde si nécessaire.
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Enregistrer les messages dans le journal.
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec >> "$LOG_FILE" 2>&1

echo "=========================================="
echo "Début de la sauvegarde : $(date '+%d/%m/%Y %H:%M:%S %Z')"
echo "Serveur : $HOSTNAME_SHORT"

# Vérifier que tous les chemins existent avant de commencer.
for path in "${BACKUP_PATHS[@]}"; do
    if [[ ! -e "/$path" ]]; then
        echo "ERREUR : chemin introuvable : /$path"
        exit 1
    fi
done

# Éviter d'écraser une archive existante.
if [[ -e "$ARCHIVE" ]]; then
    echo "ERREUR : cette archive existe déjà : $ARCHIVE"
    exit 1
fi

# Créer un fichier temporaire pour l'archive.
TMP_ARCHIVE="$(mktemp "${BACKUP_DIR}/.backup.XXXXXX")"

# Supprimer le fichier temporaire si le script échoue.
cleanup() {
    if [[ -n "${TMP_ARCHIVE:-}" && -f "$TMP_ARCHIVE" ]]; then
        rm -f -- "$TMP_ARCHIVE"
    fi
}
trap cleanup EXIT

# Créer l'archive en conservant les chemins relatifs à /.
if ! tar -czf "$TMP_ARCHIVE" -C / "${BACKUP_PATHS[@]}"; then
    echo "ERREUR : création de l'archive impossible."
    exit 1
fi

# Vérifier l'intégrité du flux gzip.
if ! gzip -t "$TMP_ARCHIVE"; then
    echo "ERREUR : archive gzip invalide."
    exit 1
fi

# Vérifier que tar peut lire le contenu de l'archive.
if ! tar -tzf "$TMP_ARCHIVE" > /dev/null; then
    echo "ERREUR : impossible de lire le contenu de l'archive."
    exit 1
fi

# Publier l'archive une fois les vérifications réussies.
mv -- "$TMP_ARCHIVE" "$ARCHIVE"
TMP_ARCHIVE=""

chmod 600 "$ARCHIVE"

# Calculer une somme de contrôle pour détecter une corruption ultérieure.
sha256sum "$ARCHIVE" > "${ARCHIVE}.sha256"
chmod 600 "${ARCHIVE}.sha256"

echo "Archive créée : $ARCHIVE"
echo "Taille : $(du -h "$ARCHIVE" | awk '{print $1}')"
echo "SHA-256 : $(cut -d ' ' -f 1 "${ARCHIVE}.sha256")"

# Conserver les 7 archives les plus récentes.
mapfile -t ARCHIVES < <(
    find "$BACKUP_DIR" -maxdepth 1 -type f \
        -name "${HOSTNAME_SHORT}_*.tar.gz" \
        -printf '%T@ %p\n' |
    sort -nr |
    cut -d ' ' -f 2-
)

if (( ${#ARCHIVES[@]} > 7 )); then
    for OLD_ARCHIVE in "${ARCHIVES[@]:7}"; do
        if rm -f -- "$OLD_ARCHIVE" "${OLD_ARCHIVE}.sha256"; then
            echo "Ancienne sauvegarde supprimée : $OLD_ARCHIVE"
        else
            echo "ERREUR : suppression impossible : $OLD_ARCHIVE"
        fi
    done
fi

echo "Résultat : SUCCÈS"
echo "Fin de la sauvegarde : $(date '+%d/%m/%Y %H:%M:%S %Z')"
