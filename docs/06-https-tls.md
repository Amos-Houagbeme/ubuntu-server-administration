# 06 — Configuration HTTPS et TLS

## 1. Objectif

Activer HTTPS sur le serveur `srv-web-01` afin de protéger les
communications entre les clients et Nginx.

Ce travail permet de pratiquer :

- la génération d'une clé privée et d'un certificat ;
- l'utilisation d'OpenSSL ;
- la configuration TLS dans Nginx ;
- la gestion des permissions des fichiers cryptographiques ;
- le filtrage du trafic HTTPS avec UFW ;
- la vérification d'une connexion TLS avec curl.

Le certificat utilisé dans ce laboratoire est autosigné. Il sert à
apprendre et à tester HTTPS dans un environnement privé.

## 2. Environnement

| Paramètre | Valeur |
|---|---|
| Serveur | srv-web-01 |
| Adresse IPv4 | 192.168.50.10 |
| Serveur web | Nginx |
| Port HTTPS | TCP 443 |
| Réseau autorisé | 192.168.50.0/24 |
| Outil cryptographique | OpenSSL |
| Version TLS constatée | TLS 1.3 |
| Type de certificat | Autosigné |

## 3. Pourquoi HTTPS ?

HTTP ne chiffre pas les données au niveau du protocole HTTP.

HTTPS utilise TLS pour protéger la confidentialité et l'intégrité
des communications et permettre l'authentification du serveur au
moyen d'un certificat correctement vérifié.

Dans ce laboratoire, la page HTML est publique et ne contient
pas de données confidentielles. HTTPS reste néanmoins utile pour
apprendre à configurer un service web sécurisé.

HTTPS ne garantit pas, à lui seul, la sécurité de l'application.
La configuration du serveur, les permissions, les mises à jour et
le contrôle des accès restent importants.

## 4. Certificat autosigné

Un certificat autosigné est signé à l'aide de la clé privée qui lui
est associée, plutôt que par une autorité de certification distincte.

Il peut être utilisé pour tester TLS dans un environnement de
laboratoire. En revanche, les navigateurs ne lui accordent pas
automatiquement leur confiance.

Le navigateur a affiché un avertissement de sécurité lors de l'accès
à ce site. Après avoir continué, la page HTTPS s'est affichée.

Cet avertissement concerne la confiance accordée au certificat.
Il ne signifie pas nécessairement que la connexion TLS a échoué.

Pour un site destiné au public, un certificat adapté et reconnu par
les clients est généralement préférable.

## 5. Génération du certificat

OpenSSL a été utilisé pour créer une clé RSA et un certificat
autosigné.

Commande exécutée :

```bash
sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/lab-site.key \
  -out /etc/ssl/certs/lab-site.crt \
  -subj "/CN=192.168.50.10" \
  -addext "subjectAltName=IP:192.168.50.10"
```

### Rôle des principales options

- `req` : utilise les fonctions de gestion des demandes de certificats.
- `-x509` : produit directement un certificat autosigné.
- `-nodes` : n'ajoute pas de chiffrement par phrase secrète au fichier
  de clé privée, afin que Nginx puisse démarrer sans saisie manuelle.
- `-days 365` : fixe la durée de validité demandée à 365 jours.
- `-newkey rsa:2048` : génère une nouvelle clé RSA de 2048 bits.
- `-keyout` : indique le fichier de sortie de la clé privée.
- `-out` : indique le fichier de sortie du certificat.
- `-subj` : renseigne le sujet du certificat.
- `-addext` : ajoute une extension au certificat.

Le champ Subject Alternative Name (SAN) contient l'adresse IP
`192.168.50.10`. Cette information est importante lorsque le client
accède au serveur directement par son adresse IP.

## 6. Fichiers et permissions

Les fichiers utilisés sont :

| Fichier | Contenu | Permissions appliquées |
|---|---|---|
| `/etc/ssl/private/lab-site.key` | Clé privée | 600 |
| `/etc/ssl/certs/lab-site.crt` | Certificat public | 644 |

Les permissions ont été définies avec :

```bash
sudo chmod 600 /etc/ssl/private/lab-site.key
sudo chmod 644 /etc/ssl/certs/lab-site.crt
```

La clé privée appartient à `root` et ses permissions empêchent les
autres utilisateurs de la lire directement.

Le certificat public peut être lu par les autres utilisateurs.

La clé privée ne doit jamais être ajoutée au dépôt GitHub ou partagée
dans une capture d'écran.

## 7. Vérification du certificat

Pour examiner le certificat :

```bash
sudo openssl x509 \
  -in /etc/ssl/certs/lab-site.crt \
  -noout -subject -issuer -dates -ext subjectAltName
```

Les informations constatées étaient :

```text
subject=CN = 192.168.50.10
issuer=CN = 192.168.50.10
notBefore=Oct 20 09:27:50 2026 GMT
notAfter=Oct 20 09:27:50 2027 GMT
X509v3 Subject Alternative Name:
    IP Address:192.168.50.10
```

Le sujet et l'émetteur correspondent, ce qui est cohérent avec
un certificat autosigné.

Le SAN contient l'adresse IP utilisée pour accéder au site.

La période de validité va du 20 octobre 2026 au 20 octobre 2027,
selon les dates affichées par OpenSSL.

## 8. Configuration HTTPS dans Nginx

Le fichier utilisé est :

```text
/etc/nginx/sites-available/lab-site-https
```

Il est activé par un lien symbolique dans :

```text
/etc/nginx/sites-enabled/lab-site-https
```

La configuration comprend les directives suivantes :

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

### Explication des directives

- `listen 443 ssl` configure l'écoute HTTPS en IPv4.
- `listen [::]:443 ssl` configure l'écoute HTTPS en IPv6.
- `server_name` désigne l'identité utilisée pour sélectionner ce bloc
  serveur.
- `root` indique le répertoire des fichiers du site.
- `index` indique les fichiers d'index recherchés.
- `ssl_certificate` indique le certificat public.
- `ssl_certificate_key` indique la clé privée associée.
- `try_files` recherche le fichier demandé et renvoie une erreur 404
  si le contenu demandé n'existe pas.

La configuration a été testée avec `nginx -t` avant son application.

## 9. Règle UFW pour HTTPS

Les connexions HTTPS sont autorisées depuis le réseau du lab :

```bash
sudo ufw allow from 192.168.50.0/24 to any port 443 proto tcp
```

La règle autorise les connexions TCP entrantes vers le port 443
depuis le sous-réseau IPv4 `192.168.50.0/24`.

Elle est complémentaire à la configuration TLS : UFW contrôle
l'accès réseau, tandis que Nginx et TLS assurent le traitement
des requêtes et la protection des communications.

## 10. Test HTTPS avec curl

La connexion a été vérifiée avec `curl` et le certificat public fourni explicitement, depuis `srv-web-01` ([`curl-https.png`](../https/curl-https.png)) puis depuis l'hôte ([`curl-https-host.txt`](../https/curl-https-host.txt)) :

```bash
curl -v \
  --cacert /etc/ssl/certs/lab-site.crt \
  https://192.168.50.10/
```

Lors du test, la sortie contenait notamment :

```text
SSL connection using TLSv1.3
subject: CN=192.168.50.10
subjectAltName: host "192.168.50.10" matched cert's IP address!
issuer: CN=192.168.50.10
SSL certificate verify ok.
< HTTP/1.1 200 OK
```

Le test a confirmé que :

1. La connexion TCP vers le port 443 a réussi.
2. La négociation TLS a réussi.
3. L'adresse IP correspond au champ SAN du certificat.
4. La vérification du certificat a réussi avec le certificat fourni.
5. Nginx a renvoyé la page HTML avec un code HTTP 200.

Le code `200` confirme que la requête a été traitée avec succès.

L'option `--cacert` permet à curl d'utiliser explicitement le certificat
indiqué pour la vérification. Cela ne signifie pas que tous les
navigateurs font automatiquement confiance à ce certificat.

## 11. Preuves associées

Les fichiers suivants ont été collectés :

- [`certificate-info.txt`](../https/certificate-info.txt) :
  informations publiques du certificat.
- [`test-result.txt`](../https/test-result.txt) :
  résultat d'un test HTTPS enregistré.
- [`response-headers.txt`](../https/response-headers.txt) :
  en-têtes de la réponse HTTP.
- [`page.html`](../https/page.html) :
  page renvoyée par le serveur.
- [`curl-https.png`](../https/curl-https.png) :
  capture du test curl, réalisé sur `srv-web-01`.
- [`curl-https-host.txt`](../https/curl-https-host.txt) :
  test HTTPS depuis l'hôte.
- [`https-capture.png`](../https/https-capture.png) :
  capture du site dans le navigateur (`https://` dans la barre d'adresse).
- [`lab-site.crt`](../https/lab-site.crt) :
  certificat public.
- [`lab-site-https.conf`](../nginx/lab-site-https.conf) :
  configuration HTTPS de Nginx.

Ces fichiers permettent de comparer la configuration prévue et les
résultats observés pendant les tests.

## 12. Redirection HTTP vers HTTPS

La redirection est configurée et vérifiée : le bloc HTTP répond par `301 Moved Permanently` vers `https://192.168.50.10/` ([05 — Nginx](05-nginx.md), section 10).

Preuves : [`http-redirect.txt`](../nginx/http-redirect.txt) (réponse observée) et [`nginx-effective.txt`](../nginx/nginx-effective.txt) (configuration effective).

## 13. Limites et améliorations possibles

Le certificat est autosigné et n'est donc pas automatiquement
reconnu comme fiable par les navigateurs.

La configuration permet d'apprendre TLS dans cet environnement
privé. Pour un déploiement public, il faudrait notamment choisir un
nom de domaine adapté et obtenir un certificat reconnu par les clients.

HTTPS ne remplace ni le filtrage réseau, ni les mises à jour,
ni la protection des fichiers, ni la sécurisation de l'application.

La clé privée doit rester protégée et ne doit pas être publiée.

Le certificat expire le 20 octobre 2027 ; son renouvellement est manuel.

La clé privée n'est pas chiffrée par une phrase secrète (option `-nodes`) : seules ses permissions la protègent sur le serveur. Elle n'est pas incluse dans les sauvegardes ([07 — Sauvegarde](07-sauvegarde.md)).

## 14. Conclusion

HTTPS fonctionne sur `srv-web-01` avec TLS 1.3 et un certificat
autosigné comportant l'adresse IP `192.168.50.10`.

La connexion a été vérifiée avec curl et la page personnalisée a été
affichée dans le navigateur.

La configuration, les informations publiques du certificat et les
résultats des tests sont conservés pour la documentation du lab.
