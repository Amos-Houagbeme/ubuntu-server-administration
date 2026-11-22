#!/usr/bin/env bash
# Outil de contrôle écrit avec l'aide de Claude (assistant IA) : il vérifie la configuration, il ne la réalise pas.
# test-acl.sh : teste la matrice d'accès de /srv/web-partage, en mode verbeux par défaut.
# Usage : sudo bash test-acl.sh        (explique chaque test à l'écran + rapport .md)
#         sudo bash test-acl.sh -q     (silencieux : rapport .md seulement)
# Les fichiers de test (préfixe _tst_) sont supprimés à la fin.
# Aucun test ne modifie la configuration (groupes, ACL, droits du dossier).

set -u

if [ "$(id -u)" -ne 0 ]; then
  echo "Lance le script avec sudo." >&2
  exit 1
fi

VERBOSE=1
[ "${1:-}" = "-q" ] && VERBOSE=0

if [ -t 1 ]; then
  B=$'\e[1m'; N=$'\e[0m'; D=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'
else
  B=""; N=""; D=""; R=""; G=""
fi

DIR=/srv/web-partage
WEB=webuser
LOG=loguser
GLOB=globaluser
OWNER=${SUDO_USER:-root}
OUTDIR=$(getent passwd "$OWNER" | cut -d: -f6)
OUT="$OUTDIR/test-acl-$(hostname)-$(date +%Y%m%d-%H%M).md"
P="_tst_$$"
ROWS=$(mktemp)
CHECKS=$(mktemp)
PASS=0
FAIL=0

cleanup() {
  rm -rf -- "$DIR"/${P}_* 2>/dev/null
  rm -f "$ROWS" "$CHECKS"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

say() { [ "$VERBOSE" -eq 1 ] && printf '%s\n' "$*"; return 0; }

intro() { # titre, explication
  say ""
  say "${B}══ $1 ══${N}"
  say "${D}$2${N}"
}

# run_test "action" utilisateur attendu(autorisé|refusé) "pourquoi" 'script sh' args...
run_test() {
  local action="$1" user="$2" expect="$3" why="$4" script="$5"; shift 5
  local err rc got res
  err=$(timeout 15 sudo -u "$user" sh -c "$script" _ "$@" 2>&1 >/dev/null </dev/null)
  rc=$?
  if [ "$rc" -eq 0 ]; then got="autorisé"; elif [ "$rc" -eq 124 ]; then got="bloqué (timeout)"; err="la commande attendait une saisie"; else got="refusé"; fi
  if [ "$got" = "$expect" ]; then res="✅"; PASS=$((PASS+1)); else res="❌"; FAIL=$((FAIL+1)); fi
  err=$(printf '%s' "$err" | head -1 | tr '|' '/' | cut -c1-70)
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$action" "$user" "$expect" "$got" "$res" "$why" "$err" >> "$ROWS"

  say "  ${B}$user${N}"
  say "    commande  : sudo -u $user sh -c '$script' _ $*"
  say "    pourquoi  : $why"
  if [ "$res" = "✅" ]; then
    say "    attendu   : $expect   obtenu : $got   ${G}✅ conforme${N}"
  else
    say "    attendu   : $expect   obtenu : $got   ${R}❌ ÉCART avec la politique voulue${N}"
  fi
  [ -n "$err" ] && say "    message   : $err"
}

# check "description" "pourquoi" commande (exécutée en root)
check() {
  local desc="$1" why="$2"; shift 2
  local res
  if bash -c "$*" >/dev/null 2>&1; then
    res="✅"; PASS=$((PASS+1))
  else
    res="❌"; FAIL=$((FAIL+1))
  fi
  echo "- $res $desc : $why" >> "$CHECKS"
  say "  $res $desc"
  say "    pourquoi : $why"
}

# --- Pré-vérifications ---
[ -d "$DIR" ] || { echo "Dossier $DIR introuvable." >&2; exit 1; }
for u in $WEB $LOG $GLOB; do
  id "$u" >/dev/null 2>&1 || { echo "Utilisateur $u introuvable." >&2; exit 1; }
done

STICKY=0
case "$(stat -c %A "$DIR")" in *t|*T) STICKY=1 ;; esac

say "${B}Test de la matrice d'accès sur $DIR${N}"
say "Principe : chaque action est exécutée EN TANT QUE l'utilisateur testé (sudo -u),"
say "puis on compare le résultat réel (autorisé / refusé) à la politique voulue :"
say "  - webadmins ($WEB)  : lit et écrit"
say "  - logadmins ($LOG)  : lit seulement"
say "  - les autres ($GLOB) : aucun accès"
say "Sticky bit sur le dossier : $([ "$STICKY" -eq 1 ] && echo oui || echo non)"
say "Un 'refusé' attendu qui est bien refusé compte comme ✅ : un refus est une preuve."

# --- Préparation ---
F="$DIR/${P}_fichier"
say ""
say "${B}Préparation${N} : $WEB crée un fichier de test contenant du texte."
if ! sudo -u "$WEB" sh -c 'echo contenu > "$1"' _ "$F" 2>/dev/null; then
  echo "$WEB ne peut pas créer de fichier dans $DIR : la configuration est cassée, arrêt." >&2
  exit 1
fi
say "  ✅ fichier créé : $F"

# --- 1. Lister ---
intro "1. Lister le contenu du dossier" \
"Lister demande r (lire le dossier) ET x (le traverser) sur le dossier. Ce sont les ACL du dossier qui décident."
run_test "Lister le dossier" $WEB  autorisé "ACL group:webadmins:rwx : r et x présents" 'ls "$1" >/dev/null' "$DIR"
run_test "Lister le dossier" $LOG  autorisé "ACL group:logadmins:r-x : r et x présents" 'ls "$1" >/dev/null' "$DIR"
run_test "Lister le dossier" $GLOB refusé   "catégorie 'autres' : other::---, ni r ni x" 'ls "$1" >/dev/null' "$DIR"
if [ "$OWNER" != "root" ]; then
  run_test "Lister (compte admin, sans sudo)" "$OWNER" refusé "$OWNER n'est dans aucun des deux groupes : il tombe dans 'autres'" 'ls "$1" >/dev/null' "$DIR"
fi

# --- 2. Lire ---
intro "2. Lire un fichier" \
"Une fois devant le fichier, le noyau regarde les droits DU FICHIER (ses ACL). Il faut aussi pouvoir traverser le dossier."
run_test "Lire un fichier" $WEB  autorisé "droit effectif rw- via l'ACL webadmins" 'grep -q contenu "$1"' "$F"
run_test "Lire un fichier" $LOG  autorisé "droit effectif r-- via l'ACL logadmins (le x est coupé par le masque)" 'grep -q contenu "$1"' "$F"
run_test "Lire un fichier" $GLOB refusé   "ne peut même pas atteindre le fichier : le dossier lui est fermé" 'grep -q contenu "$1"' "$F"

# --- 3. Écrire ---
intro "3. Écrire dans un fichier existant" \
"Modifier un fichier demande w sur le FICHIER. C'est ce qui sépare webadmins (rw-) de logadmins (r--)."
run_test "Ajouter du texte" $WEB  autorisé "w effectif via l'ACL webadmins" 'echo ajout >> "$1"' "$F"
run_test "Ajouter du texte" $LOG  refusé   "logadmins n'a que r sur le fichier (effective r--)" 'echo ajout >> "$1"' "$F"
run_test "Ajouter du texte" $GLOB refusé   "dossier fermé, fichier inatteignable" 'echo ajout >> "$1"' "$F"

# --- 4. Créer un fichier ---
intro "4. Créer un nouveau fichier" \
"Créer une entrée demande w sur le DOSSIER (pas sur un fichier : il n'existe pas encore)."
run_test "Créer un fichier" $WEB  autorisé "webadmins a rwx sur le dossier, donc w" 'touch "$1"' "$DIR/${P}_new_$WEB"
run_test "Créer un fichier" $LOG  refusé   "logadmins a r-x sur le dossier : pas de w" 'touch "$1"' "$DIR/${P}_new_$LOG"
run_test "Créer un fichier" $GLOB refusé   "other::--- sur le dossier" 'touch "$1"' "$DIR/${P}_new_$GLOB"

# --- 5. Créer un sous-dossier ---
intro "5. Créer un sous-dossier" \
"Même règle que pour un fichier : w sur le dossier parent. Le sous-dossier créé par $WEB sert ensuite à tester l'héritage."
run_test "Créer un sous-dossier" $WEB  autorisé "w sur le dossier parent via webadmins" 'mkdir "$1"' "$DIR/${P}_dir_$WEB"
run_test "Créer un sous-dossier" $LOG  refusé   "pas de w sur le dossier parent" 'mkdir "$1"' "$DIR/${P}_dir_$LOG"
run_test "Créer un sous-dossier" $GLOB refusé   "other::--- sur le dossier parent" 'mkdir "$1"' "$DIR/${P}_dir_$GLOB"

# --- 6. Supprimer ---
intro "6. Supprimer un fichier créé par root" \
"Supprimer dépend des droits du DOSSIER (w + x), pas du fichier. Avec le sticky bit, seul le propriétaire du fichier ou du dossier peut supprimer."
if [ "$STICKY" -eq 1 ]; then
  EXP_WEB_DEL="refusé"; WHY_WEB_DEL="sticky bit actif : $WEB n'est ni propriétaire du fichier (root) ni du dossier"
else
  EXP_WEB_DEL="autorisé"; WHY_WEB_DEL="w+x sur le dossier via webadmins, pas de sticky bit : tout membre peut supprimer"
fi
touch "$DIR/${P}_del_$WEB";  run_test "Supprimer un fichier (propriétaire root)" $WEB  "$EXP_WEB_DEL" "$WHY_WEB_DEL" 'rm -f "$1"' "$DIR/${P}_del_$WEB"
touch "$DIR/${P}_del_$LOG";  run_test "Supprimer un fichier (propriétaire root)" $LOG  refusé "pas de w sur le dossier (r-x seulement)" 'rm -f "$1"' "$DIR/${P}_del_$LOG"
touch "$DIR/${P}_del_$GLOB"; run_test "Supprimer un fichier (propriétaire root)" $GLOB refusé "dossier fermé" 'rm -f "$1"' "$DIR/${P}_del_$GLOB"

# --- 7. Héritage ---
intro "7. Héritage (vérifié en root, sans dépendre de l'umask)" \
"Les ACL par défaut (default:) et le setgid servent à ce que les NOUVEAUX fichiers et dossiers reçoivent les bons droits automatiquement."
SD="$DIR/${P}_dir_$WEB"
check "Fichier créé par $WEB : groupe = webadmins" "le setgid fait hériter du groupe du dossier, pas du groupe privé de $WEB" "[ \"\$(stat -c %G '$F')\" = webadmins ]"
check "Fichier créé par $WEB : ACL webadmins:rwx" "l'ACL par défaut du dossier a été copiée sur le fichier" "getfacl -p '$F' | grep -q '^group:webadmins:rwx'"
check "Fichier créé par $WEB : ACL logadmins:r-x" "idem pour logadmins (le droit effectif sera r-- à cause du masque)" "getfacl -p '$F' | grep -q '^group:logadmins:r-x'"
check "Fichier créé par $WEB : other::---" "les autres n'ont rien, même sans compter sur l'umask" "getfacl -p '$F' | grep -q '^other::---'"
check "Sous-dossier : setgid hérité" "le s dans les droits du groupe doit se transmettre aux sous-dossiers" "[[ \"\$(stat -c %A '$SD')\" == ??????s* ]]"
check "Sous-dossier : groupe = webadmins" "conséquence du setgid" "[ \"\$(stat -c %G '$SD')\" = webadmins ]"
check "Sous-dossier : ACL par défaut transmise" "default:group:logadmins:r-x doit se retrouver, pour que l'héritage continue au niveau suivant" "getfacl -p '$SD' | grep -q '^default:group:logadmins:r-x'"
check "Sous-dossier : other::---" "les autres restent exclus à tous les niveaux" "getfacl -p '$SD' | grep -q '^other::---'"
check "Dossier racine : other::--- et default:other::---" "la règle 'autres exclus' existe pour le dossier ET pour ce qui sera créé" "getfacl -p '$DIR' | grep -q '^other::---' && getfacl -p '$DIR' | grep -q '^default:other::---'"

# --- Assemblage du rapport ---
{
  echo "# Test de la matrice d'accès : $DIR"
  echo
  echo "- Hôte : $(hostname)"
  echo "- Date : $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- Sticky bit sur le dossier : $([ "$STICKY" -eq 1 ] && echo oui || echo non)"
  echo "- Résultat : $PASS conformes, $FAIL non conformes"
  echo
  echo "## Matrice (attendu = politique voulue, obtenu = résultat réel)"
  echo
  echo "| Action | Utilisateur | Attendu | Obtenu | Résultat | Pourquoi | Message système |"
  echo "|---|---|---|---|---|---|---|"
  cat "$ROWS"
  echo
  echo "## Héritage et configuration"
  echo
  cat "$CHECKS"
  echo
  echo "## Configuration du dossier"
  echo
  echo '```'
  echo "\$ ls -ld $DIR"
  ls -ld "$DIR"
  echo
  echo "\$ getfacl -p $DIR"
  getfacl -p "$DIR" 2>&1
  echo '```'
  echo
  echo "## Groupes"
  echo
  echo '```'
  getent group webadmins logadmins
  for u in $WEB $LOG $GLOB; do id "$u"; done
  echo '```'
} > "$OUT"
chown "$OWNER":"$OWNER" "$OUT" 2>/dev/null

say ""
say "${B}══ Bilan ══${N}"
say "  ✅ = la configuration respecte la politique voulue (un refus attendu et obtenu est un ✅)."
say "  ❌ = écart : soit la config est fausse, soit la politique du script ne correspond pas à ton choix."
echo "Conformes : $PASS, non conformes : $FAIL"
echo "Rapport : $OUT"
exit 0
