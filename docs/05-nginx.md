# 05 — Installation et configuration de Nginx

## 1. Objectif

Installer et configurer Nginx sur `srv-web-01` afin d'héberger une page web personnalisée et de permettre son accès depuis le réseau du laboratoire.

Cette partie du lab permet de pratiquer :

- l'installation et la gestion d'un service Linux avec `systemd` ;
- l'organisation des fichiers d'un site web ;
- la configuration d'un serveur HTTP ;
- la gestion des permissions Linux ;
- la validation d'une configuration avant son application ;
- les tests HTTP depuis le serveur et depuis un client distant ;
- la redirection HTTP vers HTTPS.

La configuration TLS et le certificat autosigné sont détaillés dans [`06-https-tls.md`](06-https-tls.md).

## 2. Environnement

| Paramètre | Valeur |
|---|---|
| Serveur | `srv-web-01` |
| Adresse IPv4 | `192.168.50.10` |
| Système | Ubuntu Server 24.04.5 LTS |
| Serveur web | Nginx |
| Port HTTP | TCP 80 |
| Port HTTPS | TCP 443 |
| Réseau autorisé pour HTTP/HTTPS | `192.168.50.0/24` |
| Racine web | `/var/www/lab-site/public` |
| Fichier principal | `index.html` |

## 3. Installation de Nginx

La liste des paquets a été actualisée :

```bash
sudo apt update
```

Nginx a ensuite été installé :

```bash
sudo apt install nginx
```

Le service a été examiné avec :

```bash
sudo systemctl status nginx --no-pager
```

Le résultat collecté indiquait `Active: active (running)`. L'indication `enabled` dans la ligne `Loaded` signifie que le service est configuré pour démarrer automatiquement au démarrage du système.

Preuve : [`nginx-status.txt`](../nginx/nginx-status.txt).

## 4. Vérifier et recharger la configuration

Avant toute modification de configuration, la commande suivante a été utilisée :

```bash
sudo nginx -t
```

Le test de syntaxe a réussi. Nginx peut ensuite relire sa configuration sans arrêt complet du service avec :

```bash
sudo systemctl reload nginx
```

Il faut recharger le service uniquement après un test de configuration réussi. La commande `nginx -t` vérifie la configuration, mais ne prouve pas à elle seule qu'un site est accessible : des tests HTTP restent nécessaires.

Preuve : [`nginx-test.txt`](../nginx/nginx-test.txt).

## 5. Configuration HTTP

La configuration du site par défaut est conservée dans :

```text
/etc/nginx/sites-available/default
```

Elle est activée par le lien symbolique :

```text
/etc/nginx/sites-enabled/default
```

Les configurations activées dans `sites-enabled` sont prises en compte par Nginx via la directive d'inclusion définie dans sa configuration principale.

Les directives principales du bloc HTTP comprennent :

```nginx
listen 80 default_server;
listen [::]:80 default_server;

server_name _;
return 301 https://192.168.50.10$request_uri;
```

- `listen 80 default_server;` configure l'écoute HTTP en IPv4 sur le port 80 et désigne ce bloc comme serveur par défaut pour l'écoute correspondante.
- `listen [::]:80 default_server;` configure une écoute HTTP IPv6.
- `server_name _;` est utilisé comme nom non conventionnel dans la configuration par défaut. La sélection effective d'un bloc serveur dépend aussi de l'adresse et du port d'écoute ainsi que des règles de sélection de Nginx.
- `return 301 https://192.168.50.10$request_uri;` répond à toute requête HTTP par une redirection permanente vers HTTPS (section 10).

Depuis la mise en place de la redirection (section 10), ce bloc ne sert plus la page : il répond aux requêtes HTTP par un `301` vers HTTPS. La page est servie par le bloc HTTPS ([`lab-site-https.conf`](../nginx/lab-site-https.conf)).

La copie de la configuration collectée est disponible dans [`default.conf`](../nginx/default.conf). Le relevé de la configuration effective (`nginx -T`, filtré sur `listen`, `server_name` et `return`) est conservé dans [`nginx-effective.txt`](../nginx/nginx-effective.txt).

## 6. Création d'une racine web dédiée

Au lieu de conserver le site du lab dans le répertoire par défaut `/var/www/html`, une racine web dédiée a été utilisée :

```text
/var/www/lab-site/public/
```

Le répertoire a été créé avec :

```bash
sudo install -d -o root -g root -m 755 /var/www/lab-site/public
```

Dans cette commande :

- `-d` demande à `install` de créer un répertoire ;
- `-o root` définit `root` comme propriétaire ;
- `-g root` définit `root` comme groupe propriétaire ;
- `-m 755` fixe les permissions du répertoire.

La sortie de `ls -ld /var/www/lab-site/public/` a confirmé le propriétaire `root`, le groupe `root` et les permissions `drwxr-xr-x`.

Le déplacement de la racine web améliore l'organisation et facilite la séparation du contenu du site. Le changement de chemin n'est toutefois pas, à lui seul, une mesure de sécurité suffisante : les permissions, la configuration de Nginx et les autres services restent importants.

## 7. Création de la page HTML et permissions

Le fichier principal de la page est :

```text
/var/www/lab-site/public/index.html
```

Il a été créé avec :

```bash
sudo nano /var/www/lab-site/public/index.html
```

La page présente le serveur, la version d'Ubuntu et les services utilisés dans le laboratoire. La copie du HTML récupérée pendant la collecte des preuves est disponible dans [`page.html`](../https/page.html).

Les permissions ont été fixées comme suit :

```bash
sudo chown root:root /var/www/lab-site/public/index.html
sudo chmod 644 /var/www/lab-site/public/index.html
```

Avec le mode `644`, `root` peut lire et modifier le fichier ; le groupe et les autres utilisateurs peuvent le lire, mais ne disposent pas du droit d'écriture. Nginx doit pouvoir lire les fichiers statiques, sans avoir besoin d'en être propriétaire ou de les modifier.

## 8. Vérifications HTTP

### 8.1. Test local sur le serveur

Depuis `srv-web-01`, la commande suivante a été exécutée :

```bash
curl -I http://127.0.0.1/
```

La réponse obtenue était notamment :

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
```

`127.0.0.1` est l'adresse de bouclage : ce test vérifie que le service HTTP répond localement sur le serveur.

### 8.2. Test depuis l'ordinateur hôte

Depuis l'ordinateur hôte, le test suivant a été effectué :

```bash
curl -I http://192.168.50.10/
```

L'accès HTTP depuis l'hôte a fonctionné une fois la règle UFW correspondante en place. Ce test vérifie le chemin réseau entre l'hôte et le serveur, pas uniquement le service local. Ce test a été réalisé avant la mise en place de la redirection (section 10) : il retourne désormais un `301`.

## 9. Relation entre Nginx et UFW

Nginx traite les requêtes HTTP et renvoie les fichiers du site. UFW filtre les communications réseau selon ses règles. Ces composants remplissent des rôles différents et doivent être vérifiés séparément.

La règle UFW utilisée pour HTTP est :

```bash
sudo ufw allow from 192.168.50.0/24 to any port 80 proto tcp
```

Elle autorise les connexions TCP entrantes vers le port 80 depuis le sous-réseau IPv4 `192.168.50.0/24`.

Pour HTTPS, la règle correspondante est :

```bash
sudo ufw allow from 192.168.50.0/24 to any port 443 proto tcp
```

Ces règles limitent les accès web au réseau du laboratoire. Elles ne signifient pas que les autres machines sont incapables d'atteindre le serveur par n'importe quel chemin possible : le résultat dépend notamment du routage, des règles UFW et de l'adresse source vue par le serveur.

Les preuves du pare-feu sont conservées dans le dossier [`../ufw/`](../ufw/).

## 10. Redirection HTTP vers HTTPS

Une redirection permanente a été configurée dans le bloc HTTP avec la directive :

```nginx
return 301 https://192.168.50.10$request_uri;
```

La directive utilise le code `301` (*Moved Permanently*) et redirige vers HTTPS en conservant le chemin et les paramètres de la requête via `$request_uri`. La destination HTTPS est fixée explicitement à l'adresse du serveur du lab.

Depuis l'ordinateur hôte, la commande suivante a été exécutée :

```bash
curl -I http://192.168.50.10/
```

La réponse observée était :

```text
HTTP/1.1 301 Moved Permanently
Location: https://192.168.50.10/
```

Le code `301` indique la redirection permanente ; l'en-tête `Location` fournit l'URL de destination. La première requête HTTP n'est pas chiffrée : c'est la connexion HTTPS qui protège les échanges suivants.

Preuve textuelle : [`http-redirect.txt`](../nginx/http-redirect.txt).

## 11. Configuration HTTPS et preuve de fonctionnement

Le bloc HTTPS est défini dans `/etc/nginx/sites-available/lab-site-https` et activé par le lien symbolique `/etc/nginx/sites-enabled/lab-site-https`.

Il utilise le certificat public et la clé privée situés respectivement dans :

```text
/etc/ssl/certs/lab-site.crt
/etc/ssl/private/lab-site.key
```

**La clé privée ne doit jamais être copiée dans le dépôt GitHub.** Les paramètres TLS, les caractéristiques du certificat et les tests détaillés sont documentés dans [`06-https-tls.md`](06-https-tls.md).

Le test HTTPS depuis l'ordinateur hôte a été effectué avec le certificat public explicitement fourni à `curl`. La connexion a réussi avec une réponse HTTP `200 OK` et une vérification TLS réussie. Le certificat autosigné n'est toutefois pas automatiquement considéré comme fiable par les navigateurs ; un avertissement a été affiché lors du test dans le navigateur.

Preuves :

- [`lab-site-https.conf`](../nginx/lab-site-https.conf) — configuration HTTPS ;
- [`certificate-info.txt`](../https/certificate-info.txt) — informations publiques du certificat ;
- [`curl-https-host.txt`](../https/curl-https-host.txt) — test HTTPS depuis l'hôte ;
- [`curl-https.png`](../https/curl-https.png) — capture du test `curl`, réalisé sur `srv-web-01` ;
- [`https-capture.png`](../https/https-capture.png) — capture du site dans le navigateur (`https://` dans la barre d'adresse).

## 12. Preuves associées

| Preuve | Ce qu'elle montre |
|---|---|
| [`default.conf`](../nginx/default.conf) | Configuration du bloc HTTP (redirection vers HTTPS) |
| [`lab-site-https.conf`](../nginx/lab-site-https.conf) | Configuration HTTPS collectée |
| [`nginx-effective.txt`](../nginx/nginx-effective.txt) | Configuration effective : quel fichier définit quel `listen`, `server_name` et `return` |
| [`nginx-status.txt`](../nginx/nginx-status.txt) | État du service Nginx au moment de la collecte |
| [`nginx-test.txt`](../nginx/nginx-test.txt) | Résultat du test de configuration |
| [`page.html`](../https/page.html) | Contenu HTML renvoyé par le serveur |
| [`http-redirect.txt`](../nginx/http-redirect.txt) | Résultat du test de redirection HTTP vers HTTPS |
| [`curl-https-host.txt`](../https/curl-https-host.txt) | Résultat du test HTTPS depuis l'hôte |
| [`https-capture.png`](../https/https-capture.png) | Capture du site dans le navigateur |
| [`curl-https.png`](../https/curl-https.png) | Capture de la vérification HTTPS avec `curl` |

Les preuves doivent correspondre aux fichiers réellement présents dans le dossier du projet. Avant publication, vérifier les chemins des liens et s'assurer qu'aucun secret n'a été ajouté par inadvertance.

## 13. Limites et améliorations possibles

- La redirection cible explicitement `https://192.168.50.10` et non le nom demandé (`$host`) : elle convient à une adresse IP privée unique.
- La page est statique ; seul le service web est couvert, pas une application.
- Les deux fichiers de site (`default` et `lab-site-https`) figurent dans la liste des chemins sauvegardés : renommer ou supprimer l'un d'eux fait échouer la sauvegarde tant que la liste n'est pas mise à jour ([07 — Sauvegarde](07-sauvegarde.md), section 10).

## 14. Conclusion

Nginx est installé sur `srv-web-01` et sert une page HTML personnalisée depuis `/var/www/lab-site/public`. Le service et sa configuration ont été vérifiés, l'accès HTTP a été testé, et la redirection HTTP vers HTTPS a renvoyé un code `301` avec l'URL HTTPS attendue. La connexion HTTPS a également été testée avec le certificat public explicitement fourni à `curl`.

La configuration web est ainsi documentée avec ses principaux fichiers et tests. HTTPS utilise un certificat autosigné adapté à l'adresse IP privée du lab ; cette solution convient aux exercices, mais la confiance du navigateur doit être traitée séparément pour un déploiement réel.
