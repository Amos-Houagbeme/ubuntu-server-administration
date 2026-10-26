# Feuille de route

Une étape n'est présentée comme terminée que lorsqu'elle a été réalisée et vérifiée, avec une preuve liée dans le dépôt. L'état actuel est résumé dans le [README](README.md).

## 1. Journaux centralisés (`srv-log-01`) : en cours

Machine : `srv-log-01`, 192.168.50.20/24, Ubuntu Server, réseau `lab-linux`. Transport retenu : Syslog UDP/514 (TCP/6514 avec TLS est réservé à un laboratoire ultérieur).

Réalisé (preuves à ajouter au dépôt) :

- installation d'Ubuntu Server et configuration de l'adresse IPv4 statique ;
- installation et vérification initiale du service `rsyslog` ;
- modification de la configuration pour préparer l'écoute UDP sur le port 514 ;
- validation de la syntaxe avec `rsyslogd -N1`.

Restant à faire :

- redémarrer le service et confirmer l'écoute effective sur UDP/514 ;
- restreindre le trafic entrant au seul serveur autorisé (`srv-web-01`) ;
- configurer `srv-web-01` pour transmettre ses journaux ;
- envoyer un message de test et confirmer sa réception ;
- organiser les journaux par machine et vérifier leur conservation.

## 2. Sauvegarde hors machine : prévu

Transfert des sauvegardes de `srv-web-01` vers un autre serveur du réseau, avec SSH et `rsync`, afin de couvrir la perte du serveur. La destination envisagée est `srv-log-01`.

## 3. Utilisateurs, groupes et permissions : prévu

À aborder après la validation de la centralisation des journaux :

- création et modification des comptes locaux ;
- création des groupes `webadmins` et `logadmins`, et affectation des utilisateurs selon leurs rôles ;
- configuration des privilèges `sudo` ;
- permissions avec `chmod`, `chown` et `chgrp` ;
- ACL avec `getfacl` et `setfacl` ;
- répertoire partagé `/srv/web-partage` : propriétaire `root`, groupe `webadmins`, permissions `2770`.

Les comptes individuels à créer et leurs privilèges précis seront documentés avant leur mise en place. Les utilisateurs déjà présents sur les serveurs ne doivent pas être confondus avec les comptes de l'exercice.

## 4. Stockage et exploitation : prévu

- étude des partitions et des systèmes de fichiers ;
- montage persistant avec `/etc/fstab` ;
- volumes logiques avec LVM ;
- rotation des journaux avec `logrotate` ;
- synchronisation horaire avec `chrony` ;
- diagnostic de problèmes et documentation d'incidents.

## 5. Améliorations identifiées

- **SSH** : limiter le débit des nouvelles connexions (`sudo ufw limit OpenSSH`), ou restreindre la règle à un réseau d'administration ; ajouter une preuve négative (une connexion par mot de passe doit échouer avec `Permission denied (publickey)`). Voir [03](docs/03-ssh.md).
- **Sauvegarde** : ajouter à l'archive le script installé (`/usr/local/sbin/backup-lab-linux`) et la crontab de `root` ; prévoir une notification en cas d'échec et une surveillance de l'espace disque ; définir où conserver la clé privée TLS, hors dépôt. Voir [07](docs/07-sauvegarde.md).
- **HTTPS** : le certificat autosigné expire le 20 octobre 2027 ; son renouvellement est manuel. Voir [06](docs/06-https-tls.md).
