# 04 — Configuration et administration du pare-feu UFW

## 1. Objectif

Configurer UFW (Uncomplicated Firewall) sur `srv-web-01` afin de
contrôler les connexions réseau entrantes.

Le serveur héberge un site web avec Nginx. Il doit autoriser
l'administration distante par SSH ainsi que l'accès HTTP et HTTPS
depuis le réseau du laboratoire.

L'objectif est de limiter les accès réseau aux services nécessaires
au fonctionnement de l'infrastructure du laboratoire.

## 2. Environnement

| Paramètre | Valeur |
|---|---|
| Serveur | srv-web-01 |
| Adresse IPv4 | 192.168.50.10 |
| Réseau du laboratoire | 192.168.50.0/24 |
| Passerelle | 192.168.50.1 |
| Pare-feu | UFW |
| Politique entrante par défaut | deny |
| Politique sortante par défaut | allow |

## 3. Principes de fonctionnement

UFW est un outil de gestion du pare-feu sous Ubuntu.

Il permet de définir des règles qui autorisent ou refusent certaines
communications réseau, selon les adresses, les ports et les protocoles.

Dans cette configuration, les politiques suivantes sont appliquées :

- Le trafic entrant est refusé par défaut.
- Le trafic sortant est autorisé par défaut.
- Le trafic routé est désactivé par défaut dans la politique UFW.

Les règles spécifiques permettent ensuite d'autoriser les services
nécessaires.

Cette politique limite les connexions entrantes non autorisées,
mais elle ne garantit pas, à elle seule, la sécurité complète du serveur.

## 4. Installation et état du pare-feu

L'état du pare-feu a été vérifié avec :

```bash
sudo ufw status verbose
```

Pour examiner les règles avec leurs numéros :

```bash
sudo ufw status numbered
```

Le résultat obtenu indiquait :

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
```

Le pare-feu est actif et configuré pour démarrer automatiquement
avec le système.

La journalisation UFW est activée au niveau `low`.

## 5. Politiques par défaut

Les politiques ont été configurées avec les commandes suivantes :

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### Refuser les connexions entrantes par défaut

```bash
sudo ufw default deny incoming
```

Cette règle refuse les nouvelles communications entrantes qui ne
sont pas autorisées par une règle applicable.

### Autoriser les connexions sortantes par défaut

```bash
sudo ufw default allow outgoing
```

Cette règle autorise par défaut les communications initiées depuis
le serveur vers d'autres destinations.

Cela permet notamment au serveur de contacter les services nécessaires
à son fonctionnement, sous réserve des autres règles réseau en place.

## 6. Règles configurées

Les règles suivantes ont été relevées lors de la collecte des preuves.

| Service | Port | Source autorisée | Objectif |
|---|---:|---|---|
| SSH | TCP 22 | Toutes les sources (IPv4 et IPv6) | Administration distante |
| HTTP | TCP 80 | 192.168.50.0/24 | Accès au site web |
| HTTPS | TCP 443 | 192.168.50.0/24 | Accès sécurisé au site web |

Les règles SSH couvrent IPv4 et IPv6. Les règles HTTP et HTTPS
relevées sont limitées au sous-réseau IPv4 du laboratoire.

### Autoriser SSH

```bash
sudo ufw allow OpenSSH
```

Le profil OpenSSH correspond au port TCP 22 sur le serveur.

Cette règle permet l'administration distante. Elle n'impose pas de
restriction à une adresse source particulière. Ce choix est assumé et détaillé dans [03 — SSH](03-ssh.md), section 6.

### Autoriser HTTP depuis le réseau du laboratoire

```bash
sudo ufw allow from 192.168.50.0/24 to any port 80 proto tcp
```

Cette règle autorise les connexions TCP entrantes sur le port 80
lorsque leur adresse source appartient au réseau IPv4 du laboratoire.

Elle permet notamment à l'ordinateur hôte et aux machines du même
sous-réseau d'accéder au site web.

### Autoriser HTTPS depuis le réseau du laboratoire

```bash
sudo ufw allow from 192.168.50.0/24 to any port 443 proto tcp
```

Cette règle autorise les connexions TCP entrantes sur le port 443
depuis le réseau du laboratoire.

Elle permet d'accéder au site Nginx au moyen de HTTPS.

### Activer le pare-feu

```bash
sudo ufw enable
```

Avant l'activation, la règle SSH avait été ajoutée afin de limiter
le risque de perdre l'accès distant.

Après l'activation, une nouvelle connexion SSH a été établie
pour vérifier que l'administration distante fonctionnait toujours.

## 7. Pourquoi limiter HTTP et HTTPS au réseau du laboratoire ?

Le serveur possède l'adresse IPv4 `192.168.50.10/24`.

La règle :

```bash
sudo ufw allow from 192.168.50.0/24 to any port 80 proto tcp
```

permet d'accéder au port HTTP depuis ce sous-réseau, mais ne constitue
pas une autorisation générale pour toutes les sources IPv4.

Le même principe a été appliqué au port HTTPS.

Cette configuration convient à cet environnement de laboratoire,
dans lequel le site doit rester accessible depuis l'ordinateur hôte
et les machines autorisées du réseau virtuel.

Une adresse source autorisée ne garantit cependant pas que la machine
est digne de confiance. De même, une topologie ou un routage différent
peut modifier les chemins d'accès au serveur.

Le filtrage réseau doit donc être complété par la sécurisation des
services et une gestion correcte des permissions.

## 8. Vérifications réalisées

Plusieurs commandes ont été utilisées pour vérifier le fonctionnement
du pare-feu et des services autorisés.

### Examiner les règles et les politiques

```bash
sudo ufw status verbose
sudo ufw status numbered
sudo ufw show added
```

### Vérifier le profil SSH

```bash
sudo ufw app list
sudo ufw app info OpenSSH
```

Le profil OpenSSH indiquait le port TCP 22.

### Tester la connexion SSH

Depuis l'ordinateur hôte :

```bash
ssh srv-web-01
```

Une nouvelle connexion a réussi après l'activation d'UFW.

### Tester l'accès HTTP

Depuis l'ordinateur hôte :

```bash
curl -I http://192.168.50.10/
```

Une réponse HTTP 200 a d'abord été obtenue. Depuis la mise en place de la redirection ([05 — Nginx](05-nginx.md), section 10), la réponse est `301 Moved Permanently` vers HTTPS (preuve : [`http-redirect.txt`](../nginx/http-redirect.txt)).

### Tester l'accès HTTPS

Depuis le client, le certificat autosigné a été utilisé pour
effectuer la vérification TLS :

```bash
curl -v \
    --cacert ~/lab-evidence/https/lab-site.crt \
    -o /dev/null \
    -w '\nCode HTTP : %{http_code}\nVérification TLS : %{ssl_verify_result}\n' \
    https://192.168.50.10/
```

Le test doit être considéré comme réussi lorsqu'il retourne un code
HTTP 200 et un résultat de vérification TLS égal à 0.

Le chemin vers le certificat doit correspondre au fichier réellement
présent sur la machine qui exécute `curl`.

## 9. Preuves associées

Les résultats et fichiers de configuration collectés sont conservés
dans le dossier `../ufw/`.

- [`ufw-status.txt`](../ufw/ufw-status.txt) : état et politiques du pare-feu.
- [`ufw-numbered.txt`](../ufw/ufw-numbered.txt) : règles numérotées.
- [`ufw-default`](../ufw/ufw-default) : configuration générale d'UFW.
- [`ufw-user.rules`](../ufw/ufw-user.rules) : règles utilisateur IPv4.
- [`ufw-user6.rules`](../ufw/ufw-user6.rules) : règles utilisateur IPv6.
- [`ufw-status.png`](../ufw/ufw-status.png) : capture de `sudo ufw status verbose`.

Ces fichiers permettent d'examiner les résultats et la configuration
collectés sur le serveur.

## 10. Limites et améliorations possibles

### Accès SSH

SSH reste autorisé depuis toutes les sources, en IPv4 et en IPv6. Ce choix est assumé et compensé par l'authentification par clé uniquement ([03 — SSH](03-ssh.md), section 6).

Dans une infrastructure réelle, SSH serait généralement limité à un réseau d'administration, derrière un VPN ou un bastion.

### HTTPS et certificat autosigné

HTTPS chiffre les communications, mais le certificat autosigné
n'est pas automatiquement reconnu comme fiable par les navigateurs.

Le test `curl --cacert` permet de vérifier la connexion en utilisant
explicitement le certificat fourni.

### Limites du pare-feu

UFW contrôle les communications réseau correspondant à ses règles.
Il ne remplace pas les mises à jour, la sécurisation des services,
la gestion des permissions, les sauvegardes ou la surveillance.

## 11. Conclusion

UFW est actif sur `srv-web-01`.

SSH est autorisé pour l'administration distante, tandis que HTTP et
HTTPS sont limités au réseau IPv4 du laboratoire.

Les connexions SSH et les accès web ont été testés.

Cette configuration constitue une base de filtrage réseau adaptée
à cet environnement de laboratoire. Les renforcements possibles de
l'accès SSH sont décrits dans [03 — SSH](03-ssh.md), section 7.
