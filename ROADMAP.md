# Feuille de route

Une étape n'est présentée comme terminée que lorsqu'elle a été réalisée et vérifiée, avec une preuve liée dans le dépôt. L'état actuel est résumé dans le [README](README.md).

## 1. Journaux centralisés (`srv-log-01`) : réception validée

Documentation : [08](docs/08-journaux-centralises.md).

Réalisé :

- émission des journaux de `srv-web-01` vers `srv-log-01` en UDP/514 ([`rsyslog-emission.txt`](journaux/rsyslog-emission.txt)) ;
- écoute de `rsyslogd` sur UDP/514 et rangement par machine émettrice ([`rsyslog-ecoute.txt`](journaux/rsyslog-ecoute.txt)) ;
- message de test retrouvé sur `srv-log-01` ([`reception-test.txt`](journaux/reception-test.txt)) ;
- contrôle de santé des deux machines après la migration de l'hôte ([`sante-srv-web-01-20261120.md`](controles/sante-srv-web-01-20261120.md), [`sante-srv-log-01-20261120.md`](controles/sante-srv-log-01-20261120.md)).

Restant à faire :

- restreindre le trafic entrant de `srv-log-01` au seul serveur autorisé (`srv-web-01`) avec UFW : reporté à la phase de durcissement, avec une mesure avant et après ([`nmap-avant-durcissement.txt`](controles/nmap-avant-durcissement.txt)) ;
- verser comme preuve le fichier de règles de classement de `srv-log-01` ;
- supprimer ou archiver `/var/log/remote/srv-web-01.log`, reste d'un essai antérieur.

## 2. Utilisateurs, groupes et permissions : validé

Documentation : [09](docs/09-utilisateurs-permissions.md).

Réalisé :

- groupes `webadmins` et `logadmins`, comptes de test `webuser`, `loguser` et `globaluser` ([`comptes-et-groupes.txt`](permissions/comptes-et-groupes.txt)) ;
- répertoire partagé `/srv/web-partage` : propriétaire `root`, groupe `webadmins`, mode `2770`, ACL et ACL par défaut ([`dossier-acl.txt`](permissions/dossier-acl.txt), [`fichier-acl.txt`](permissions/fichier-acl.txt)) ;
- effet du setgid ([`setgid-avant-apres.txt`](permissions/setgid-avant-apres.txt)) ;
- matrice de 28 contrôles, refus compris ([`test-matrice-acl.md`](permissions/test-matrice-acl.md)) ;
- sticky bit testé, non retenu ([`sticky-bit-test.txt`](permissions/sticky-bit-test.txt)).

Restant à faire :

- configurer et documenter des privilèges `sudo` par rôle.

## 3. Stockage et exploitation : prévu

Ordre retenu :

1. **Synchronisation horaire avec `chrony`** : heure commune aux deux machines, pour que leurs journaux soient comparables ; preuve attendue : `chronyc tracking` sur chaque machine.
2. **Volumes logiques avec LVM** sur `srv-log-01` : volume dédié à `/var/log/remote`, agrandi sans arrêt (un disque virtuel supplémentaire est nécessaire) ; preuves attendues : `lsblk`, `vgs`, `lvs` et `df -h` avant, après et après redémarrage. Tester `sudo mount -a` avant tout redémarrage qui suit une modification de `/etc/fstab`.
3. **Rotation des journaux avec `logrotate`** sur `/var/log/remote/*/*.log`, avec une commande `postrotate` pour rsyslog.
4. **Sauvegarde hors machine** : copie des sauvegardes de `srv-web-01` vers `srv-log-01` avec SSH et `rsync`, avec une clé dédiée et restreinte ; preuve attendue : restauration réussie depuis la copie distante.
5. **Documentation d'incidents** : deux à trois pannes provoquées, avec symptôme, diagnostic, cause, correction et prévention.
6. **Finalisation** : schéma d'architecture, preuves rangées, dépôt à jour.

## 4. Durcissement : prévu

- UFW sur `srv-log-01` : SSH et UDP/514 depuis `srv-web-01` seulement ; mesure avant et après avec `nmap`, y compris l'UDP.
- Fail2ban, en-têtes de sécurité Nginx, vérification de la configuration TLS avec `testssl.sh`.
- AppArmor ou Lynis.
- Revue des groupes du compte d'administration (`dokja` appartient notamment à `lxd`).

Let's Encrypt n'est pas réalisable sans domaine public.

## 5. Améliorations identifiées

- **SSH** : limiter le débit des nouvelles connexions (`sudo ufw limit OpenSSH`), ou restreindre la règle à un réseau d'administration ; ajouter une preuve négative (une connexion par mot de passe doit échouer avec `Permission denied (publickey)`). Voir [03](docs/03-ssh.md).
- **Sauvegarde** : ajouter à l'archive le script installé (`/usr/local/sbin/backup-lab-linux`) et la crontab de `root` ; prévoir une notification en cas d'échec et une surveillance de l'espace disque ; définir où conserver la clé privée TLS, hors dépôt. Rattraper les exécutions manquées quand les machines sont éteintes à 02:00 UTC (`anacron` ou minuteur systemd persistant). Voir [07](docs/07-sauvegarde.md).
- **Journaux** : passer à TCP avec TLS (port 6514) dans un laboratoire ultérieur. Voir [08](docs/08-journaux-centralises.md).
- **HTTPS** : le certificat autosigné expire le 20 octobre 2027 ; son renouvellement est manuel. Voir [06](docs/06-https-tls.md).
