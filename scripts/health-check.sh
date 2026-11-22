#!/usr/bin/env bash
# Outil de contrôle écrit avec l'aide de Claude (assistant IA) : il vérifie la configuration, il ne la réalise pas.
# health-check.sh : contrôle d'état d'une VM de lab, rapport en Markdown.
# Usage : sudo bash health-check.sh [TAG]
#   - sur srv-web-01 : envoie un message logger de test et affiche son TAG
#   - sur srv-log-01 : relancer avec ce TAG pour vérifier la réception
# Le rapport est écrit dans le home de l'utilisateur qui a lancé sudo.

set -u

if [ "$(id -u)" -ne 0 ]; then
  echo "Lance le script avec sudo." >&2
  exit 1
fi

HOST=$(hostname)
OWNER=${SUDO_USER:-root}
OUTDIR=$(getent passwd "$OWNER" | cut -d: -f6)
OUT="$OUTDIR/health-${HOST}-$(date +%Y%m%d-%H%M).md"
TAG_IN="${1:-}"
BODY=$(mktemp)
SUMMARY=$(mktemp)
trap 'rm -f "$BODY" "$SUMMARY"' EXIT

IS_WEB=0; IS_LOG=0
case "$HOST" in *web*) IS_WEB=1 ;; esac
case "$HOST" in *log*) IS_LOG=1 ;; esac

# check "libellé" commande : ajoute une ligne OK/KO au résumé
check() {
  local label="$1"; shift
  if bash -c "$*" >/dev/null 2>&1; then
    echo "- ✅ $label" >> "$SUMMARY"
  else
    echo "- ❌ $label" >> "$SUMMARY"
  fi
}

# section "titre" : titre dans le corps
section() { printf '\n## %s\n\n' "$1" >> "$BODY"; }

# show "commande" : sortie brute dans un bloc de code
show() {
  printf '```\n$ %s\n' "$1" >> "$BODY"
  bash -c "$1" >> "$BODY" 2>&1
  printf '```\n\n' >> "$BODY"
}

# ---------- Contrôles (résumé) ----------
check "Interface avec une IP 192.168.50.x" "ip -4 -br a | grep -q '192\.168\.50\.'"
check "UFW actif" "ufw status | grep -q 'Status: active'"
check "SSH : mot de passe désactivé (valeur effective)" "sshd -T | grep -qi '^passwordauthentication no'"
check "Heure synchronisée (NTPSynchronized=yes)" "timedatectl show -p NTPSynchronized --value | grep -q yes"
check "rsyslog actif" "systemctl is-active --quiet rsyslog"
check "Aucune unité systemd en échec" "[ \"\$(systemctl --failed --no-legend | wc -l)\" -eq 0 ]"
check "fstab valide (findmnt --verify)" "findmnt --verify"
check "Disque / sous 90 %" "[ \"\$(df --output=pcent / | tail -1 | tr -dc 0-9)\" -lt 90 ]"

if [ "$IS_WEB" -eq 1 ]; then
  check "nginx actif" "systemctl is-active --quiet nginx"
  check "Configuration nginx valide (nginx -t)" "nginx -t"
  check "HTTPS répond (localhost:443)" "curl -ks -o /dev/null https://localhost"
  check "Port 80 redirige en 301" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://localhost)\" = 301 ]"
  check "rsyslog : envoi distant configuré" "grep -rEqs '^[^#]*@@?[0-9a-zA-Z]' /etc/rsyslog.conf /etc/rsyslog.d/"
  check "Cron de sauvegarde présent" "{ crontab -l -u '$OWNER'; crontab -l -u root; cat /etc/cron.d/* 2>/dev/null; } 2>/dev/null | grep -qi backup"
fi

if [ "$IS_LOG" -eq 1 ]; then
  check "rsyslog écoute sur le port 514" "ss -tuln | grep -q ':514 '"
  check "Dossier /var/log/remote présent" "[ -d /var/log/remote ]"
  if [ -n "$TAG_IN" ]; then
    check "Message de test '$TAG_IN' reçu" "grep -rqs -- '$TAG_IN' /var/log/remote"
  fi
fi

# ---------- Détails (corps) ----------
section "Système"
show "hostnamectl"
show "uptime"

section "Réseau"
show "ip -br a"
show "ip route"
show "ss -tulnp"

section "Pare-feu"
show "ufw status verbose"

section "SSH (valeurs effectives)"
show "sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|pubkeyauthentication|port) '"

section "Heure"
show "timedatectl"

section "Services"
show "systemctl --failed --no-pager"
show "systemctl is-active rsyslog nginx docker chrony chronyd 2>&1"

section "Stockage"
show "lsblk"
show "df -h"
show "findmnt --verify"

if [ "$IS_WEB" -eq 1 ]; then
  section "Nginx"
  show "nginx -t"
  show "curl -ksI https://localhost | head -5"
  show "curl -sI http://localhost | head -3"
  section "Sauvegarde"
  show "{ crontab -l -u '$OWNER'; crontab -l -u root; } 2>&1 | grep -v '^#'"
  show "ls -lt /var/backups /srv/backups $OUTDIR/backups 2>/dev/null | head -15"
  section "Envoi rsyslog"
  show "grep -rEs '^[^#]*@@?[0-9a-zA-Z]' /etc/rsyslog.conf /etc/rsyslog.d/"
fi

if [ "$IS_LOG" -eq 1 ]; then
  section "Réception rsyslog"
  show "ls -lR /var/log/remote | head -30"
  if [ -n "$TAG_IN" ]; then
    show "grep -rs -- '$TAG_IN' /var/log/remote | head -5"
  fi
fi

# ---------- Message de test (web uniquement) ----------
NEWTAG=""
if [ "$IS_WEB" -eq 1 ]; then
  NEWTAG="healthcheck-$(date +%Y%m%d%H%M%S)"
  logger -t healthcheck "$NEWTAG"
  section "Message de test envoyé"
  printf 'TAG : `%s`\nÀ vérifier sur srv-log-01 avec : `sudo bash health-check.sh %s`\n' "$NEWTAG" "$NEWTAG" >> "$BODY"
fi

# ---------- Assemblage ----------
{
  echo "# Contrôle de santé : $HOST"
  echo
  echo "- Date : $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- Utilisateur : $OWNER"
  echo
  echo "## Résumé"
  echo
  cat "$SUMMARY"
  cat "$BODY"
} > "$OUT"
chown "$OWNER":"$OWNER" "$OUT" 2>/dev/null

echo "Rapport : $OUT"
grep -c '❌' "$SUMMARY" | sed 's/^/Échecs : /'
[ -n "$NEWTAG" ] && echo "TAG de test : $NEWTAG"
exit 0
