# Carnet de commandes — Administration système Linux

> **Objet :** carnet technique pour comprendre, reconstruire et diagnostiquer ce lab. Ce document rassemble les commandes utilisées dans `srv-web-01`, les modèles de configuration et les contrôles associés.
>
> **État du projet :** les sections réseau, SSH, UFW, Nginx et HTTPS décrivent cette configuration actuelle, d'après les étapes réalisées. Les commandes de diagnostic ou variantes sont signalées comme telles. Une commande documentée n'est pas automatiquement une preuve d'exécution : les preuves sont conservées séparément dans `~/lab-evidence/`.

## 0. Contexte du lab et conventions

### Infrastructure connue

| Élément | Valeur |
|---|---|
| Machine hôte | Ubuntu, utilisateur `stone` |
| Serveur web | `srv-web-01` |
| Utilisateur distant | `dokja` |
| Adresse IPv4 du serveur | `192.168.50.10/24` |
| Interface du serveur | `enp1s0` |
| Réseau libvirt | `lab-linux` |
| Sous-réseau | `192.168.50.0/24` |
| Passerelle du lab | `192.168.50.1` |
| Racine web Nginx | `/var/www/lab-site/public` |
| Configuration HTTPS | `/etc/nginx/sites-available/lab-site-https` |
| Certificat autosigné | `/etc/ssl/certs/lab-site.crt` |
| Clé privée TLS | `/etc/ssl/private/lab-site.key` |

### Où exécuter les commandes ?

- **[HÔTE]** : terminal de l'ordinateur physique, généralement `stone@HP`.
- **[SERVEUR]** : session distante dans `srv-web-01`, généralement `dokja@srv-web-01`.
- `sudo` exécute une commande avec des privilèges administrateur. Utiliser `sudo` ne signifie pas qu'il faut également l'utiliser pour les commandes de transfert depuis l'hôte : cela peut changer le compte dont SSH lit la configuration.

### Règles de prudence

1. Lire une configuration avant de la modifier.
2. Faire une copie avant modification.
3. Tester la syntaxe avant de recharger un service.
4. Garder la session SSH actuelle ouverte jusqu'à validation d'une nouvelle connexion après un changement réseau ou SSH.
5. Ne jamais ajouter une clé privée SSH/TLS, un mot de passe ou un jeton secret à Git.
6. Les exemples avec des DNS, noms de domaines ou chemins différents doivent être adaptés à la configuration réelle.

---

## 1. Identifier le serveur et diagnostiquer le réseau

### 1.1 Informations du système [SERVEUR]

```bash
hostnamectl
hostname
uname -a
lsb_release -a
```

- `hostnamectl` : nom d'hôte, système et virtualisation.
- `hostname` : nom courant de la machine.
- `uname -a` : noyau et architecture.
- `lsb_release -a` : informations de la distribution (si la commande est installée).

Pour conserver une preuve sans les identifiants uniques `Machine ID` et `Boot ID` :

```bash
hostnamectl | sed -E '/Machine ID:|Boot ID:/d' > ~/hostnamectl.txt
```

Ne publiez pas le `Machine ID` ou le `Boot ID` sans nécessité.

### 1.2 Interfaces, adresses et routes [SERVEUR]

```bash
ip -br address
ip address show enp1s0
ip route
ip route get 192.168.50.1
```

Pour tester le réseau local, la passerelle et Internet :

```bash
ping -c 4 192.168.50.1
ping -c 4 8.8.8.8
getent hosts ubuntu.com
```

Un échec de `ping` ne prouve pas toujours que la machine est inaccessible : ICMP peut être filtré. Il faut aussi regarder les routes, la résolution DNS et le service concerné.

### 1.3 Enregistrer des sorties utiles

```bash
mkdir -p ~/lab-evidence/infrastructure ~/lab-evidence/reseau
hostnamectl | sed -E '/Machine ID:|Boot ID:/d' > ~/lab-evidence/infrastructure/hostnamectl.txt
ip -br address > ~/lab-evidence/reseau/ip-address.txt
ip route > ~/lab-evidence/reseau/ip-route.txt
```

Ces fichiers sont des relevés d'état au moment de leur création, pas des configurations applicables.

---

## 2. Netplan : configuration IP statique

### 2.1 Examiner les fichiers existants [SERVEUR]

```bash
ls -l /etc/netplan/
sudo cat /etc/netplan/01-lab-linux.yaml
sudo netplan get
```

Le nom du fichier ci-dessus est celui utilisé dans ce lab. Si `ls` montre un nom différent, employer le nom réel.

### 2.2 Squelette Netplan pour `srv-web-01`

> Modèle à comparer au fichier réel. **Ne le remplacez pas aveuglément** : conservez notamment les DNS qui fonctionnent sur votre machine. Le DNS ne doit pas être inventé pour la documentation.

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      addresses:
        - 192.168.50.10/24
      routes:
        - to: default
          via: 192.168.50.1
      nameservers:
        addresses:
          - <DNS_ACTUEL_1>
          - <DNS_ACTUEL_2>
```

Les lignes `<DNS_ACTUEL_1>` et `<DNS_ACTUEL_2>` sont des marqueurs explicatifs, **pas des valeurs YAML à appliquer**. Remplacez-les par les adresses DNS réellement configurées avant d'utiliser le fichier.

- `version: 2` : format Netplan.
- `enp1s0` : interface à configurer.
- `dhcp4: false` : IPv4 configurée manuellement.
- `addresses` : adresse et préfixe du serveur.
- `routes` : route par défaut via la passerelle du lab.
- `nameservers` : résolveurs DNS utilisés par le serveur.

### 2.3 Permissions, validation et application [SERVEUR]

Avant d'éditer, sauvegarder le fichier :

```bash
sudo cp -a /etc/netplan/01-lab-linux.yaml /etc/netplan/01-lab-linux.yaml.bak
```

Éditer :

```bash
sudo nano /etc/netplan/01-lab-linux.yaml
```

Netplan attend des permissions restrictives pour les fichiers YAML :

```bash
sudo chown root:root /etc/netplan/01-lab-linux.yaml
sudo chmod 600 /etc/netplan/01-lab-linux.yaml
```

Valider et appliquer :

```bash
sudo netplan generate
sudo netplan apply
```

Puis contrôler :

```bash
ip -br address
ip route
getent hosts ubuntu.com
```

**Prudence :** une modification réseau appliquée à distance peut interrompre SSH. Vérifier le YAML et garder un accès console VM disponible. `netplan try` peut être utilisé pour tester une configuration avec retour arrière automatique, si adapté à la situation.

### 2.4 Collecter le fichier de configuration sur l'hôte

Depuis l'hôte, l'alias SSH doit être configuré pour `stone`. Si le fichier distant est lisible seulement par root, préparer une copie temporaire :

```bash
# [SERVEUR]
sudo cp /etc/netplan/01-lab-linux.yaml /home/dokja/01-lab-linux.yaml
sudo chown dokja:dokja /home/dokja/01-lab-linux.yaml
```

Puis depuis l'hôte :

```bash
# [HÔTE]
mkdir -p ~/lab-evidence/reseau
scp srv-web-01:/home/dokja/01-lab-linux.yaml ~/lab-evidence/reseau/
```

Après un transfert réussi, supprimer la copie temporaire :

```bash
# [HÔTE] : établir la connexion, puis exécuter côté serveur
ssh srv-web-01
sudo rm /home/dokja/01-lab-linux.yaml
exit
```

---

## 3. SSH : installation, clés, alias et durcissement

### 3.1 Vérifier l'installation et le service [SERVEUR]

```bash
sudo apt update
sudo apt install openssh-server
sudo systemctl status ssh --no-pager
sudo systemctl enable --now ssh
sudo ss -ltnp | grep ':22'
```

`enable --now` active le démarrage automatique et démarre le service immédiatement. Dans ce lab, SSH a été installé et démarré avant le durcissement.

### 3.2 Comprendre la paire de clés [HÔTE]

La clé privée reste sur l'hôte ; la clé publique peut être copiée sur le serveur.

Vérifier les clés existantes sans afficher la clé privée :

```bash
ls -l ~/.ssh/
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

Si aucune clé n'existe et qu'une nouvelle clé est nécessaire, exemple de génération :

```bash
ssh-keygen -t ed25519 -C "lab-linux"
```

Cette commande est une **variante de création**, pas une étape à répéter si la clé actuelle fonctionne. Ne jamais afficher ou transférer le contenu de `~/.ssh/id_ed25519`.

### 3.3 Copier la clé publique sur le serveur [HÔTE]

Commande utilisée dans ce lab :

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub dokja@192.168.50.10
```

Elle ajoute la clé publique au fichier `~dokja/.ssh/authorized_keys` du serveur. Le mot de passe peut être demandé pendant cette opération pour autoriser l'installation initiale.

### 3.4 Tester la clé sans authentification par mot de passe [HÔTE]

```bash
ssh -o PreferredAuthentications=publickey \
    -o PasswordAuthentication=no \
    dokja@192.168.50.10
```

Le test doit ouvrir une session sans demander le mot de passe du compte distant. Ce test a réussi dans ce lab.

### 3.5 Configurer l'alias SSH [HÔTE]

Fichier : `~/.ssh/config` (celui de l'utilisateur `stone`, pas `/root/.ssh/config`).

```sshconfig
Host srv-web-01
    HostName 192.168.50.10
    User dokja
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Créer/éditer et protéger le fichier :

```bash
nano ~/.ssh/config
chmod 600 ~/.ssh/config
```

Connexion :

```bash
ssh srv-web-01
```

Attention : lancer `sudo scp` ou `sudo ssh` peut faire utiliser la configuration SSH de root au lieu de celle de `stone`, et donc faire échouer l'alias.

### 3.6 Configuration de sécurité côté serveur [SERVEUR]

Fichier créé dans le lab : `/etc/ssh/sshd_config.d/00-security.conf`.

Contenu :

```sshconfig
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

Créer/éditer le fichier :

```bash
sudo nano /etc/ssh/sshd_config.d/00-security.conf
```

Vérifier la configuration avant application :

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
```

Résultat effectif attendu pour cette configuration :

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

Puis appliquer et vérifier :

```bash
sudo systemctl reload ssh
sudo systemctl status ssh --no-pager
```

Garder la session existante ouverte, puis ouvrir **un nouveau terminal hôte** et tester `ssh srv-web-01`. Ne fermer l'ancienne session qu'après succès du nouveau test.

### 3.7 Collecter les preuves SSH

```bash
mkdir -p ~/lab-evidence/ssh
sudo sshd -t && echo 'Syntaxe SSH : OK' > ~/sshd-syntax.txt
sudo sshd -T | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin) ' > ~/sshd-effective.txt
```

Faire une copie du seul fichier de configuration, pas des clés privées :

```bash
sudo cp /etc/ssh/sshd_config.d/00-security.conf /home/dokja/00-security.conf
sudo chown dokja:dokja /home/dokja/00-security.conf
```

Depuis l'hôte :

```bash
scp srv-web-01:/home/dokja/00-security.conf ~/lab-evidence/ssh/
scp srv-web-01:/home/dokja/sshd-effective.txt ~/lab-evidence/ssh/
scp srv-web-01:/home/dokja/sshd-syntax.txt ~/lab-evidence/ssh/
```

---

## 4. UFW : règles de pare-feu actuelles

### 4.1 Examiner l'état et les règles [SERVEUR]

```bash
sudo ufw status
sudo ufw status verbose
sudo ufw status numbered
sudo ufw show added
sudo ufw app list
sudo ufw app info OpenSSH
```

Pour ce lab, le profil `OpenSSH` correspond à `22/tcp`.

### 4.2 Règles et politiques établies

```bash
sudo ufw allow OpenSSH
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Règles HTTP et HTTPS restreintes au sous-réseau du lab :

```bash
sudo ufw allow from 192.168.50.0/24 to any port 80 proto tcp
sudo ufw allow from 192.168.50.0/24 to any port 443 proto tcp
```

Activer UFW seulement après avoir vérifié que la règle SSH est bien présente :

```bash
sudo ufw enable
```

Réexaminer l'état :

```bash
sudo ufw status verbose
sudo ufw status numbered
```

État attendu dans ce lab :

- entrée refusée par défaut ;
- sortie autorisée par défaut ;
- TCP/22 autorisé par le profil OpenSSH ;
- TCP/80 et TCP/443 autorisés depuis `192.168.50.0/24` en IPv4.

La règle OpenSSH actuelle est plus large que les règles web : les connexions SSH sont autorisées depuis `Anywhere` pour IPv4 et IPv6. Ce choix est assumé (voir [03 — SSH](03-ssh.md), section 6).

### 4.3 Supprimer une règle avec prudence

```bash
sudo ufw status numbered
sudo ufw delete NUMERO
```

`NUMERO` doit être remplacé par le numéro affiché **au moment de la suppression**. Les numéros peuvent changer après ajout/suppression. Ne supprimez pas la règle SSH par erreur.

### 4.4 Fichiers de règles UFW

Les fichiers de bas niveau utiles à l'inspection sont :

```text
/etc/ufw/user.rules
/etc/ufw/user6.rules
/etc/default/ufw
```

Pour une documentation, privilégier aussi les sorties lisibles de `ufw status verbose` et `ufw status numbered`. Ne modifier les fichiers de règles manuellement que si l'on sait exactement pourquoi ; utiliser d'abord l'interface `ufw`.

---

## 5. Nginx : installation et racine web dédiée

### 5.1 Installer, démarrer et contrôler [SERVEUR]

```bash
sudo apt update
sudo apt install nginx
sudo systemctl enable --now nginx
sudo systemctl status nginx --no-pager
```

### 5.2 Tester localement

```bash
curl -I http://127.0.0.1/
```

Une réponse `HTTP/1.1 200 OK` indique que le serveur HTTP a traité la requête avec succès.

### 5.3 Examiner les directives utiles

```bash
grep -nE 'listen|server_name|root|index' /etc/nginx/sites-available/default
```

Dans ce lab, la racine web a été déplacée vers :

```text
/var/www/lab-site/public
```

Création du répertoire avec le propriétaire et les permissions prévus :

```bash
sudo install -d -o root -g root -m 755 /var/www/lab-site/public
```

Commande équivalente en plusieurs étapes :

```bash
sudo mkdir -p /var/www/lab-site/public
sudo chown root:root /var/www/lab-site/public
sudo chmod 755 /var/www/lab-site/public
```

Créer la page :

```bash
sudo nano /var/www/lab-site/public/index.html
sudo chown root:root /var/www/lab-site/public/index.html
sudo chmod 644 /var/www/lab-site/public/index.html
ls -l /var/www/lab-site/public/index.html
```

Sauvegarder et modifier la configuration HTTP :

```bash
sudo cp -a /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
sudo nano /etc/nginx/sites-available/default
```

La directive `root` du bloc HTTP a été définie sur :

```nginx
root /var/www/lab-site/public;
```

Tester puis recharger :

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx --no-pager
curl -I http://127.0.0.1/
```

Si `nginx -t` échoue, ne pas recharger : corriger l'erreur d'abord.

### 5.4 Collecter les configurations Nginx

Les configurations activées dans ce lab se trouvent dans :

```text
/etc/nginx/sites-available/default
/etc/nginx/sites-available/lab-site-https
```

Les liens actifs se trouvent dans `/etc/nginx/sites-enabled/`. Vérifier les cibles :

```bash
ls -l /etc/nginx/sites-available/
ls -l /etc/nginx/sites-enabled/
```

Un lien symbolique cassé peut faire échouer `sudo nginx -t`. Le nom du lien et celui du fichier cible doivent correspondre exactement.

---

## 6. OpenSSL, clé privée TLS et certificat autosigné

### 6.1 Vérifier OpenSSL [SERVEUR]

```bash
openssl version
```

Version observée dans ce lab : OpenSSL `3.0.13`.

### 6.2 Générer le certificat utilisé dans ce lab

```bash
sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/lab-site.key \
  -out /etc/ssl/certs/lab-site.crt \
  -subj "/CN=192.168.50.10" \
  -addext "subjectAltName=IP:192.168.50.10"
```

Rôle des options principales :

- `req -x509` : créer directement un certificat X.509 autosigné.
- `-nodes` : créer une clé privée non chiffrée par phrase secrète afin que Nginx puisse démarrer sans saisie interactive ; la protection dépend donc notamment des permissions système.
- `-days 365` : validité de 365 jours.
- `-newkey rsa:2048` : créer une nouvelle paire de clés RSA de 2048 bits.
- `-keyout` : chemin de la clé privée.
- `-out` : chemin du certificat public.
- `-subj` : sujet affiché dans le certificat.
- `-addext subjectAltName=IP:...` : inclure l'adresse IP comme identité alternative.

Les commandes `touch` préalables ne sont pas nécessaires : OpenSSL crée/écrit ces fichiers.

Permissions :

```bash
sudo chown root:root /etc/ssl/private/lab-site.key /etc/ssl/certs/lab-site.crt
sudo chmod 600 /etc/ssl/private/lab-site.key
sudo chmod 644 /etc/ssl/certs/lab-site.crt
sudo ls -l /etc/ssl/private/lab-site.key /etc/ssl/certs/lab-site.crt
```

**Ne jamais transférer `/etc/ssl/private/lab-site.key` vers l'hôte de documentation ou GitHub.** Le certificat `.crt` est public ; la clé `.key` est secrète.

### 6.3 Examiner le certificat sans afficher le bloc PEM

```bash
sudo openssl x509 \
  -in /etc/ssl/certs/lab-site.crt \
  -noout -subject -issuer -dates -ext subjectAltName
```

Dans ce lab, le SAN contenait `IP Address:192.168.50.10`. Sujet et émetteur sont identiques car il s'agit d'un certificat autosigné.

---

## 7. Configurer et tester HTTPS dans Nginx

### 7.1 Exemple de bloc HTTPS utilisé

Fichier : `/etc/nginx/sites-available/lab-site-https`.

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name 192.168.50.10;

    root /var/www/lab-site/public;
    index index.html index.htm;

    ssl_certificate /etc/ssl/certs/lab-site.crt;
    ssl_certificate_key /etc/ssl/private/lab-site.key;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Activer par lien symbolique :

```bash
sudo ln -s /etc/nginx/sites-available/lab-site-https /etc/nginx/sites-enabled/lab-site-https
```

Si un message indique que le lien existe déjà, inspecter d'abord les chemins plutôt que de répéter la commande sans vérifier.

Tester puis recharger :

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx --no-pager
```

### 7.2 Tester HTTPS depuis le serveur

```bash
curl -v --cacert /etc/ssl/certs/lab-site.crt \
  -o /dev/null \
  -w '\nCode HTTP : %{http_code}\nVérification TLS : %{ssl_verify_result}\n' \
  https://192.168.50.10/
```

Résultats attendus : code HTTP `200`, résultat de vérification TLS `0`, et un message de validation du certificat.

### 7.3 Tester HTTPS depuis l'hôte

Le certificat public doit d'abord être copié sur l'hôte. Depuis `stone@HP` :

```bash
mkdir -p ~/lab-evidence/https
scp srv-web-01:/etc/ssl/certs/lab-site.crt ~/lab-evidence/https/
```

Puis, toujours sur l'hôte :

```bash
curl -v --cacert ~/lab-evidence/https/lab-site.crt \
  -o /dev/null \
  -w '\nCode HTTP : %{http_code}\nVérification TLS : %{ssl_verify_result}\n' \
  https://192.168.50.10/
```

Ne pas ajouter `-k`/`--insecure` au test de preuve : cette option désactive la vérification du certificat.

Un navigateur peut afficher un avertissement avec un certificat autosigné. `curl --cacert ...` réussit parce qu'on lui fournit explicitement le certificat à utiliser pour la vérification ; cela ne le rend pas automatiquement fiable dans tous les navigateurs.

---

## 8. Transférer des preuves depuis le serveur vers l'hôte

L'alias `srv-web-01` est défini dans le fichier `~/.ssh/config` de l'utilisateur `stone`. Lancer `sudo scp` peut employer la configuration SSH de `root`, qui ne connaît pas nécessairement cet alias.

Pour copier un fichier système lisible seulement par root, effectuer une copie temporaire sur le serveur :

```bash
# [SERVEUR]
sudo cp /chemin/systeme/fichier /home/dokja/fichier
sudo chown dokja:dokja /home/dokja/fichier
```

Puis depuis l'hôte :

```bash
# [HÔTE]
scp srv-web-01:/home/dokja/fichier ~/lab-evidence/dossier/
```

Après vérification du transfert, supprimer la copie temporaire :

```bash
# [SERVEUR]
sudo rm /home/dokja/fichier
```

Exemple de collecte de plusieurs preuves déjà utilisées :

```bash
# [HÔTE]
find ~/lab-evidence -maxdepth 3 -type f -printf '%P\n' | sort
```

---

## 9. Documentation et captures d'écran

Les captures utiles doivent prouver un état ou un test significatif, plutôt que remplir le dépôt.

Pour la partie web, les preuves retenues incluent :

- capture du site HTTPS dans le navigateur (`https/site_https.png`) ;
- capture du test `curl` depuis le client (`https/curl-https.png`) ;
- configurations `nginx/default.conf` et `nginx/lab-site-https.conf` ;
- résultat du test `nginx -t` ;
- informations publiques du certificat ;
- réponse HTTP et résultat de vérification TLS.

Ne pas capturer ou publier des mots de passe, clés privées, jetons ou autres secrets.

---

## 10. Commandes de diagnostic rapides

### Services

```bash
sudo systemctl status ssh --no-pager
sudo systemctl status nginx --no-pager
sudo journalctl -u ssh --since today --no-pager
sudo journalctl -u nginx --since today --no-pager
```

### Configuration Nginx

```bash
sudo nginx -t
sudo nginx -T
```

`nginx -T` peut afficher toute la configuration incluse : relire le résultat et vérifier qu'aucune information sensible n'est révélée avant de la partager.

### Écoute des ports

```bash
sudo ss -ltnp
```

### HTTP/HTTPS

```bash
curl -I http://127.0.0.1/
curl -v --cacert /etc/ssl/certs/lab-site.crt https://192.168.50.10/
```

### Pare-feu

```bash
sudo ufw status verbose
sudo ufw status numbered
```

---

## 11. Commandes de collecte pour le dossier de preuves

Sur l'hôte :

```bash
mkdir -p ~/lab-evidence/{docs,infrastructure,reseau,ssh,ufw,nginx,https}
find ~/lab-evidence -maxdepth 3 -type f -printf '%P\n' | sort
```

Sur le serveur, exemples de sorties textuelles :

```bash
hostnamectl | sed -E '/Machine ID:|Boot ID:/d' > ~/hostnamectl.txt
ip -br address > ~/ip-address.txt
ip route > ~/ip-route.txt
sudo ufw status verbose > ~/ufw-status.txt
sudo ufw status numbered > ~/ufw-numbered.txt
sudo nginx -t > ~/nginx-test.txt 2>&1
sudo systemctl status nginx --no-pager > ~/nginx-status.txt 2>&1
```

Avant de transférer les fichiers, vérifier qu'ils existent et ne contiennent pas d'informations sensibles.

---

## 12. Restauration et vérification des sauvegardes

Cette section documente les contrôles réellement effectués sur l'archive de sauvegarde du serveur web. Les opérations de test ont été réalisées dans un répertoire temporaire : elles n'ont pas remplacé les fichiers actifs du système.

### 12.1. Repérer les sauvegardes disponibles

Afficher les archives et leurs sommes de contrôle :

```bash
sudo find /var/backups/lab-linux -maxdepth 1 -type f \
  \( -name '*.tar.gz' -o -name '*.sha256' \) -printf '%f\n'
```

Afficher les informations détaillées d'une archive :

```bash
sudo stat /var/backups/lab-linux/srv-web-01_22-10-2026__02-00-01.tar.gz
```

### 12.2. Vérifier l'intégrité de l'archive

La vérification de la somme SHA-256 a été effectuée avec succès. La commande utilisée est :

```bash
sudo sha256sum -c /var/backups/lab-linux/srv-web-01_22-10-2026__02-00-01.tar.gz.sha256
```

**Résultat observé :** `OK`.

Le contrôle confirme que l'archive correspond à la somme enregistrée dans le fichier `.sha256`.

Pour contrôler également le flux gzip :

```bash
sudo gzip -t /var/backups/lab-linux/srv-web-01_22-10-2026__02-00-01.tar.gz
```

Cette commande doit se terminer sans erreur.

### 12.3. Examiner le contenu avant restauration

Le contenu de l'archive a été listé sans extraire les fichiers :

```bash
sudo tar -tzf /var/backups/lab-linux/srv-web-01_22-10-2026__02-00-01.tar.gz
```

L'archive contenait notamment :
- la page `/var/www/lab-site/public/index.html` ;
- les configurations Nginx `default` et `lab-site-https`, ainsi que leurs liens activés ;
- le fichier Netplan `01-lab-linux.yaml` ;
- les configurations SSH et le fichier `authorized_keys` de `dokja` ;
- les fichiers de configuration UFW ;
- le certificat public `/etc/ssl/certs/lab-site.crt` ;
- le script de sauvegarde `backup.sh`.

**Limite connue :** la clé privée TLS `/etc/ssl/private/lab-site.key` n'est pas incluse dans cette archive.

### 12.4. Restaurer l'archive dans un répertoire de test

Un répertoire temporaire a été créé, puis l'archive extraite sans remplacer les fichiers actifs du système :

```bash
sudo install -d -m 700 /var/tmp/restore-test
sudo tar -xzf /var/backups/lab-linux/srv-web-01_22-10-2026__02-00-01.tar.gz \
  -C /var/tmp/restore-test
```

Le fichier extrait a ensuite été inspecté :

```bash
sudo stat /var/tmp/restore-test/var/www/lab-site/public/index.html
```

**Résultat observé :**
- fichier présent ;
- taille : `667` octets ;
- permissions : `0644` (`-rw-r--r--`) ;
- propriétaire et groupe de l'extraction : `root:root`.

Ces informations décrivent le fichier extrait pendant le test ; elles ne prouvent pas à elles seules que tous les propriétaires et toutes les permissions de l'ensemble du système seraient restaurés comme avant.

### 12.5. Comparer le fichier restauré avec le fichier actif

La commande suivante a été exécutée :

```bash
sudo diff -u \
  /var/tmp/restore-test/var/www/lab-site/public/index.html \
  /var/www/lab-site/public/index.html
```

**Résultat observé :** aucune sortie. Les deux fichiers `index.html` étaient identiques au moment de la comparaison.

### 12.6. Vérification automatisée

Les contrôles des sections 12.2 à 12.5 sont rejoués, et étendus à tous les fichiers de l'archive, par [`verifier-sauvegarde.sh`](../scripts/verifier-sauvegarde.sh) :

```bash
sudo bash verifier-sauvegarde.sh
```

Le script écrit une sortie texte par contrôle : [`sha256-check.txt`](../backup/sha256-check.txt), [`gzip-test.txt`](../backup/gzip-test.txt), [`restore-test.txt`](../backup/restore-test.txt) et [`retention-test.txt`](../backup/retention-test.txt). Voir [07 — Sauvegarde](07-sauvegarde.md), section 8.

### 12.7. Bilan et limites de la restauration

Les contrôles suivants sont confirmés :

- somme SHA-256 : `OK` ;
- flux gzip : `OK` ;
- extraction dans un répertoire de test ;
- comparaison de tous les fichiers de l'archive avec les fichiers actifs (contenu, droits, propriétaires) : 24 fichiers sur 24 identiques ;
- politique de rétention : 7 archives conservées, les plus anciennes supprimées avec leur somme.

Le test valide les fichiers sauvegardés ; il ne prouve pas une restauration complète du serveur ni de tous ses services.

La sauvegarde ne contient pas la clé privée TLS `/etc/ssl/private/lab-site.key`. Si cette clé est perdue, HTTPS ne pourra pas être rétabli à l'identique à partir de cette seule archive. Il faudra récupérer la clé depuis une sauvegarde sécurisée distincte ou générer une nouvelle clé et un nouveau certificat, puis vérifier la configuration Nginx.

Une restauration réelle doit être préparée avec prudence : vérifier l'archive, identifier les fichiers qui seront remplacés, conserver une copie de l'état actuel, restaurer les propriétaires et permissions nécessaires, puis tester les services concernés. Ne pas extraire directement cette archive à la racine `/` sans plan de restauration explicite.

## 13. Suivi : éléments réalisés et restants

Un élément n'est coché que lorsqu'une preuve est liée. Les éléments restants ne doivent pas être décrits comme terminés avant leur réalisation et leur vérification ; ils sont détaillés dans la [feuille de route](../ROADMAP.md).

### 13.1. Sauvegardes

- [x] Vérifier la somme SHA-256 de l'archive : [`sha256-check.txt`](../backup/sha256-check.txt).
- [x] Vérifier le flux gzip : [`gzip-test.txt`](../backup/gzip-test.txt).
- [x] Restaurer l'archive dans un répertoire de test et comparer tous les fichiers : [`restore-test.txt`](../backup/restore-test.txt).
- [x] Tester la politique de rétention sans toucher aux sauvegardes réelles : [`retention-test.txt`](../backup/retention-test.txt).
- [ ] Décider comment protéger et sauvegarder séparément la clé privée TLS, sans la publier dans le dépôt Git.

### 13.2. Services et infrastructure

- [x] Valider et documenter la redirection HTTP vers HTTPS : [`http-redirect.txt`](../nginx/http-redirect.txt).
- [ ] Compléter les captures pertinentes, notamment celles du réseau virtuel.
- [ ] Configurer et tester la collecte centralisée des journaux avec `rsyslog` sur `srv-log-01`.
- [ ] Mettre en place et tester le transfert de sauvegardes via SSH/rsync.
- [ ] Pratiquer et documenter LVM, `logrotate` et `chrony`.
- [ ] Simuler des incidents, consigner les symptômes, le diagnostic, la correction et les vérifications après correction.

### 13.3. Règle de mise à jour

Pour chaque nouvelle tâche :
1. exécuter les commandes sur la bonne machine ;
2. vérifier le résultat ;
3. enregistrer une preuve utile dans `~/lab-evidence/` ;
4. mettre à jour la section correspondante de ce document ;
5. distinguer les étapes réalisées, les modèles de configuration et les travaux encore prévus.
