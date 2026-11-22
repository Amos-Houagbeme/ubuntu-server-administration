# 08 — Journaux centralisés (rsyslog)

## 1. Objectif

Centraliser sur `srv-log-01` les journaux émis par `srv-web-01`, afin de les conserver sur une machine distincte du service qu'ils décrivent et de pouvoir les consulter au même endroit.

- Émettre les journaux de `srv-web-01` vers `srv-log-01` avec rsyslog.
- Recevoir ces messages sur UDP/514 et les ranger par machine émettrice.
- Prouver la réception avec un message de test identifiable.
- Contrôler l'état des deux machines après le changement d'hôte (passage à Debian 13 et réimportation des machines virtuelles, novembre 2026).

## 2. Environnement

| Élément | `srv-web-01` (émetteur) | `srv-log-01` (récepteur) |
|---|---|---|
| Adresse IPv4 | 192.168.50.10/24 | 192.168.50.20/24 |
| Interface | `enp1s0` | `enp1s0` |
| Système | Ubuntu Server 24.04.5 LTS | Ubuntu Server 24.04.3 LTS |
| Utilisateur d'administration | `dokja` | `kim` |
| Service | rsyslog | rsyslog |

Transport retenu : Syslog UDP/514. Répertoire de réception : `/var/log/remote`.

## 3. Configuration

**Émission (`srv-web-01`).** Le fichier `/etc/rsyslog.d/60-remote.conf` contient la règle `*.* @192.168.50.20:514` ([`rsyslog-emission.txt`](../journaux/rsyslog-emission.txt)). Le sélecteur `*.*` transmet tous les messages, quelle que soit leur origine ou leur gravité. Le `@` simple choisit UDP ; `@@` choisirait TCP.

**Réception (`srv-log-01`).** `rsyslogd` écoute en UDP sur le port 514, en IPv4 et en IPv6 ([`rsyslog-ecoute.txt`](../journaux/rsyslog-ecoute.txt)). Les messages sont rangés par machine émettrice : sous `/var/log/remote/srv-web-01/`, `ssh.log` reçoit les messages du service SSH et `system.log` le reste.

## 4. Vérifications réalisées

### 4.1. Contrôle de santé des deux machines

Le script [`health-check.sh`](../scripts/health-check.sh) a été exécuté sur chaque machine le 20 novembre 2026, après la migration de l'hôte. Il écrit un rapport avec un résumé et les sorties brutes : [`sante-srv-web-01-20261120.md`](../controles/sante-srv-web-01-20261120.md) et [`sante-srv-log-01-20261120.md`](../controles/sante-srv-log-01-20261120.md).

| Machine | Contrôles conformes | Écart |
|---|---|---|
| `srv-web-01` | 14 sur 14 | aucun |
| `srv-log-01` | 9 sur 10 | UFW inactif |

Les identifiants uniques de machine (Machine ID, Boot ID) ont été retirés des rapports publiés.

### 4.2. Test de réception

Un message portant une étiquette horodatée (`healthcheck-20261120075309`) est émis depuis `srv-web-01` à 07:53:09 UTC, puis recherché sur `srv-log-01` avec `grep -r` dans `/var/log/remote`. Il y figure dans `system.log`, horodaté à la seconde de l'émission ([`reception-test.txt`](../journaux/reception-test.txt)).

La même recherche, lancée par erreur sur `srv-web-01`, a été journalisée puis transmise à son tour : le flux fonctionne en continu, pas seulement pour le message de test.

## 5. Preuves associées

- [`rsyslog-emission.txt`](../journaux/rsyslog-emission.txt) : règle d'émission.
- [`rsyslog-ecoute.txt`](../journaux/rsyslog-ecoute.txt) : écoute UDP/514 et arborescence de réception.
- [`reception-test.txt`](../journaux/reception-test.txt) : test de réception.
- [`sante-srv-web-01-20261120.md`](../controles/sante-srv-web-01-20261120.md) et [`sante-srv-log-01-20261120.md`](../controles/sante-srv-log-01-20261120.md) : contrôles de santé.
- [`nmap-avant-durcissement.txt`](../controles/nmap-avant-durcissement.txt) : mesure de départ du filtrage réseau.

## 6. Limites et améliorations possibles

- **UDP** : pas d'acquittement ni de chiffrement. Un message perdu ne laisse aucune trace, et un message peut être lu en transit. TCP avec TLS (port 6514) est réservé à un laboratoire ultérieur.
- **Pas de pare-feu sur `srv-log-01`** (constat du 20 novembre 2026) : le port 514/udp accepte n'importe quelle source du réseau, donc un autre hôte pourrait écrire de fausses lignes dans les journaux ou saturer le disque. La mesure de départ ([`nmap-avant-durcissement.txt`](../controles/nmap-avant-durcissement.txt)) montre 99 ports TCP « fermés » (réponse de refus) sur `srv-log-01`, contre 97 ports « filtrés » sur `srv-web-01`. Ce scan ne couvre pas l'UDP. L'activation d'UFW, limitée à SSH et à UDP/514 depuis 192.168.50.10, est reportée à la phase de durcissement.
- **Usurpation** : l'UDP se falsifie, donc un filtrage par adresse source réduit le risque sans l'éliminer. Dans ce réseau virtuel isolé, le risque réel reste faible.
- **Fichier hérité** : `/var/log/remote/srv-web-01.log` (150 521 octets, 25 octobre 2026) est un reste d'un essai antérieur, lisible par tous. Il échappera au motif de rotation prévu (`/var/log/remote/*/*.log`) : à supprimer ou à archiver avant `logrotate`.
- **Règles de classement** : le fichier de règles de `srv-log-01` qui produit le rangement par machine n'est pas encore versé comme preuve.
- **Horloge** : chaque ligne porte l'heure de la machine émettrice. La synchronisation avec `chrony` est prévue ([feuille de route](../ROADMAP.md)).
- **Machines éteintes** : aucun journal n'est produit ni reçu entre deux sessions de travail.

## 7. Conclusion

La chaîne d'émission et de réception des journaux fonctionne : un message de test émis par `srv-web-01` est retrouvé sur `srv-log-01`, rangé sous le nom de sa machine d'origine. Le filtrage du port de réception, la rotation et la synchronisation horaire restent à réaliser.
