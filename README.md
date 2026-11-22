# Administration système Linux

Laboratoire personnel d'administration de serveurs Ubuntu : accès SSH par clé, pare-feu, Nginx en HTTPS, sauvegardes automatisées et vérifiées, puis centralisation des journaux.

> [!NOTE]
> Ce laboratoire est réalisé dans un environnement virtualisé, à des fins pédagogiques. Chaque fonctionnalité est documentée selon son état réel : **validée** (preuve liée), **en cours** ou **prévue**.

## État du laboratoire

| Composant | État | Documentation | Preuves principales |
|---|---|---|---|
| Infrastructure et réseau | Validé | [01](docs/01-infrastructure.md), [02](docs/02-reseau.md) | [`hostnamectl.txt`](infrastructure/hostnamectl.txt), [`ip-route.txt`](reseau/ip-route.txt) |
| SSH par clé, durcissement | Validé | [03](docs/03-ssh.md) | [`sshd-effective.txt`](ssh/sshd-effective.txt) |
| Pare-feu UFW | Validé | [04](docs/04-ufw.md) | [`ufw-status.txt`](ufw/ufw-status.txt) |
| Nginx et redirection HTTP vers HTTPS | Validé | [05](docs/05-nginx.md) | [`nginx-effective.txt`](nginx/nginx-effective.txt), [`http-redirect.txt`](nginx/http-redirect.txt) |
| HTTPS (TLS 1.3, certificat autosigné) | Validé | [06](docs/06-https-tls.md) | [`curl-https-host.txt`](https/curl-https-host.txt), [`certificate-info.txt`](https/certificate-info.txt) |
| Sauvegarde Bash et cron | Validé | [07](docs/07-sauvegarde.md) | [`backup-log.txt`](backup/backup-log.txt) (exécution automatique du 22/10/2026 à 02:00:01 UTC) |
| Vérification et restauration des sauvegardes | Validé | [07](docs/07-sauvegarde.md) | [`restore-test.txt`](backup/restore-test.txt), [`retention-test.txt`](backup/retention-test.txt) |
| Journaux centralisés (`srv-log-01`) | Validé (réception) ; filtrage réseau prévu | [08](docs/08-journaux-centralises.md) | [`reception-test.txt`](journaux/reception-test.txt), [`rsyslog-emission.txt`](journaux/rsyslog-emission.txt), [`rsyslog-ecoute.txt`](journaux/rsyslog-ecoute.txt) |
| Utilisateurs, groupes, permissions, ACL | Validé | [09](docs/09-utilisateurs-permissions.md) | [`test-matrice-acl.md`](permissions/test-matrice-acl.md) (28 contrôles sur 28), [`dossier-acl.txt`](permissions/dossier-acl.txt) |
| Contrôles de santé des machines | Validé | [08](docs/08-journaux-centralises.md) | [`sante-srv-web-01-20261120.md`](controles/sante-srv-web-01-20261120.md), [`sante-srv-log-01-20261120.md`](controles/sante-srv-log-01-20261120.md) |
| Synchronisation horaire, LVM, `logrotate`, copie hors machine | Prévu | [ROADMAP](ROADMAP.md) | |
| Documentation d'incidents | Prévu | [ROADMAP](ROADMAP.md) | |

## Architecture

```mermaid
flowchart LR
    H["Hôte<br/>Debian 13<br/>KVM / libvirt"]
    subgraph NET["Réseau virtuel lab-linux : 192.168.50.0/24, NAT, DHCP désactivé"]
        W["srv-web-01<br/>192.168.50.10<br/>SSH, UFW, Nginx, sauvegardes"]
        L["srv-log-01<br/>192.168.50.20<br/>rsyslog (réception UDP/514)"]
    end
    H -->|"SSH par clé"| W
    H -->|"SSH"| L
    W -->|"Syslog UDP/514"| L
```

| Élément | Valeur |
|---|---|
| Hôte | Debian 13 (trixie) depuis novembre 2026 ; Ubuntu Desktop 24.04 LTS auparavant |
| Virtualisation | KVM/libvirt, virt-manager |
| Machines virtuelles | Ubuntu Server : `srv-web-01` 24.04.5 LTS, `srv-log-01` 24.04.3 LTS (relevés avec `hostnamectl`) |
| Réseau | `lab-linux`, 192.168.50.0/24, NAT, passerelle 192.168.50.1, DHCP désactivé |
| Adressage | IPv4 statique (Netplan) |

## Mode de travail

L'administration se fait en ligne de commande, par SSH depuis l'hôte (utilisateur `stone`) vers les machines virtuelles (utilisateur `dokja` sur `srv-web-01`, `kim` sur `srv-log-01`), comme dans un contexte professionnel. Dans le [carnet de commandes](docs/commandes.md), chaque commande indique la machine concernée (`[HÔTE]` ou `[SERVEUR]`).

Chaque fonctionnalité suit le même cycle : comprendre le service, préparer la configuration, l'appliquer sur la bonne machine, vérifier le résultat, tester depuis une autre machine lorsque c'est pertinent, conserver une preuve, puis documenter les limites et le reste à faire.

## Choix assumés et limites

- **SSH ouvert à toute source** (IPv4 et IPv6) : choix assumé pour pouvoir administrer depuis n'importe quel réseau. La protection repose sur l'authentification par clé uniquement : mot de passe, authentification interactive au clavier et connexion directe de `root` sont désactivés, ce que `sshd -T` confirme. Ces réglages ne couvrent pas une faille de `sshd` exploitable avant l'authentification ; dans un contexte réel, un VPN ou un bastion, avec une règle limitée au réseau d'administration, réduirait l'exposition. Détail : [03](docs/03-ssh.md).
- **Sauvegardes locales** : stockées sur le serveur qu'elles protègent, elles ne couvrent pas la perte du serveur. Une copie hors machine est prévue ([ROADMAP](ROADMAP.md)).
- **Sauvegarde et machines éteintes** : le planificateur Cron s'exécute à 02:00 UTC seulement si la machine virtuelle est allumée. Une exécution automatique a été observée (22/10/2026 à 02:00:01), mais le laboratoire n'est pas allumé en permanence : une nuit sans machine allumée produit aucune sauvegarde. Cron est conservé ; `anacron` ou un minuteur systemd persistant rattraperaient l'exécution manquée ([07](docs/07-sauvegarde.md)).
- **Portée de la restauration** : le test porte sur tous les fichiers de l'archive (24 au 25/10/2026 : contenu, droits, propriétaires), pas sur une restauration complète du serveur. La clé privée TLS est volontairement exclue de l'archive.
- **Certificat autosigné** : l'avertissement du navigateur est attendu ; la vérification TLS se fait avec `curl --cacert`.
- **Journaux** : le transport retenu est Syslog UDP/514, sans acquittement ni chiffrement. TCP/6514 avec TLS est réservé à un laboratoire ultérieur ([08](docs/08-journaux-centralises.md)).
- **Pare-feu de `srv-log-01`** : UFW n'y est pas encore activé (constat du 20/11/2026) ; le port 514/udp accepte donc toute source du réseau du laboratoire. L'activation, limitée à SSH et à `srv-web-01`, est prévue à la phase de durcissement, avec une mesure avant et après ([`nmap-avant-durcissement.txt`](controles/nmap-avant-durcissement.txt)).
- **Sticky bit** : testé sur `/srv/web-partage` puis non retenu ; un membre de `webadmins` peut supprimer ou vider les fichiers des autres, ce qui est accepté entre administrateurs de confiance ([09](docs/09-utilisateurs-permissions.md)).

## Compétences mises en pratique

- Administration Linux et systemd.
- Réseau IPv4 et diagnostic de connectivité ([02](docs/02-reseau.md)).
- SSH par clé et durcissement ([03](docs/03-ssh.md)).
- Pare-feu UFW ([04](docs/04-ufw.md)).
- Nginx et HTTPS ([05](docs/05-nginx.md), [06](docs/06-https-tls.md)).
- Bash, cron et automatisation ([07](docs/07-sauvegarde.md)).
- Sauvegarde, intégrité et restauration ([07](docs/07-sauvegarde.md)).
- Virtualisation avec KVM/libvirt ([01](docs/01-infrastructure.md)).
- Journalisation centralisée avec rsyslog ([08](docs/08-journaux-centralises.md)).
- Comptes, groupes, setgid, ACL et héritage des droits ([09](docs/09-utilisateurs-permissions.md)).
- Tests de contrôle d'accès par compte, refus compris ([09](docs/09-utilisateurs-permissions.md)).

## Structure du dépôt

```text
.
├── README.md
├── ROADMAP.md        Étapes en cours et prévues
├── docs/             Documentation par étape (01 à 09) et carnet de commandes
├── scripts/          Scripts de vérification (sauvegardes, dépôt, santé des machines, permissions)
├── infrastructure/   Preuves : système
├── reseau/           Preuves : adressage et routage
├── ssh/              Preuves : configuration SSH
├── ufw/              Preuves : règles du pare-feu
├── nginx/            Preuves : configuration Nginx
├── https/            Preuves : certificat et tests TLS
├── backup/           Preuves : script, cron, journaux et vérifications
├── journaux/         Preuves : émission, écoute et réception rsyslog
├── permissions/      Preuves : groupes, ACL, setgid, matrice de tests
└── controles/        Rapports de santé des machines et mesure réseau de départ
```

## Scripts

```bash
# Sur srv-web-01 : contrôle de la dernière sauvegarde (une sortie texte par contrôle)
sudo bash scripts/verifier-sauvegarde.sh

# Sur chaque machine virtuelle : état de santé, rapport Markdown dans le répertoire personnel
# (sur srv-web-01, un message de test est émis ; relancer sur srv-log-01 avec son étiquette)
sudo bash scripts/health-check.sh [ETIQUETTE]

# Sur srv-web-01 : matrice d'accès de /srv/web-partage, explications à l'écran (-q : silencieux)
sudo bash scripts/test-acl.sh

# Sur la machine qui prépare la publication : liens, secrets, cohérence des preuves
bash scripts/verifier-depot.sh
```

`health-check.sh` et `test-acl.sh` sont des outils de contrôle écrits avec l'aide de Claude (assistant IA) : ils vérifient la configuration, ils ne la réalisent pas. La configuration testée (groupes, ACL, rsyslog) est réalisée à la main.

## Sécurité du dépôt

Aucune clé privée, aucun mot de passe et aucune archive de sauvegarde ne sont versés dans le dépôt (`.gitignore` et `scripts/verifier-depot.sh`). `stone`, `dokja` et `kim` sont des noms d'utilisateur du laboratoire ; l'authentification repose sur des clés.

---

Projet pédagogique personnel : administration système Linux.
