# 07 — Sauvegarde, vérification et restauration

## 1. Objectif

Automatiser les sauvegardes de la configuration et des fichiers importants du serveur web `srv-web-01`, puis prouver qu'elles sont intègres, restaurables et correctement renouvelées.

- Automatiser la création d'archives avec Bash.
- Protéger les archives contre les accès non autorisés.
- Vérifier leur intégrité avec des sommes de contrôle SHA-256.
- Conserver un journal des opérations.
- Limiter l'espace disque utilisé grâce à une politique de rétention.
- Programmer l'exécution quotidienne avec Cron.
- Vérifier les archives : intégrité, restauration, rétention.

## 2. Environnement

| Élément | Configuration |
|---|---|
| Serveur concerné | `srv-web-01` (192.168.50.10) |
| Système | Ubuntu Server 24.04.5 LTS |
| Langage d'automatisation | Bash |
| Script installé | `/usr/local/sbin/backup-lab-linux` |
| Répertoire des sauvegardes | `/var/backups/lab-linux` |
| Journal | `/var/backups/lab-linux/backup.log` |
| Planificateur | Cron, tous les jours à 02:00 UTC |

## 3. Fonctionnement du script

Le script exécute les opérations suivantes :

1. Initialiser le mode strict de Bash et une valeur `umask` restrictive.
2. Vérifier que chaque chemin à sauvegarder existe : l'absence d'un seul chemin interrompt la sauvegarde.
3. Créer l'archive `tar.gz` dans un fichier temporaire.
4. Vérifier l'archive avec `gzip -t` et `tar -tzf`.
5. Déplacer l'archive vers le répertoire de destination et appliquer des permissions restrictives.
6. Calculer l'empreinte SHA-256 et créer le fichier de somme de contrôle.
7. Consigner le résultat dans le journal.
8. Appliquer la politique de rétention.

Un mécanisme de nettoyage supprime le fichier temporaire en cas d'erreur. Le code installé est conservé dans [`backup-script.sh`](../backup/backup-script.sh).

## 4. Éléments sauvegardés

L'archive contient les chemins suivants (24 fichiers au 25 octobre 2026) :

- le site web : `/var/www/lab-site/public` ;
- les configurations Nginx `default` et `lab-site-https`, avec leurs liens dans `sites-enabled` ;
- la configuration Netplan `01-lab-linux.yaml` ;
- la configuration du serveur SSH : `sshd_config` et `sshd_config.d/00-security.conf` ;
- les clés publiques autorisées de l'utilisateur `dokja` ;
- la configuration UFW : `/etc/ufw` et `/etc/default/ufw` ;
- le certificat public HTTPS `lab-site.crt` ;
- la copie de travail du script, `/home/dokja/scripts/backup.sh`.

La clé privée TLS (`/etc/ssl/private/lab-site.key`) n'est volontairement pas incluse : la gestion des secrets est traitée séparément des sauvegardes de configuration.

## 5. Sécurisation des sauvegardes

| Élément | Permissions |
|---|---|
| Script installé | `750`, propriétaire `root` |
| Répertoire des sauvegardes | `700` |
| Archives, sommes de contrôle, journal | `600` |

## 6. Planification avec Cron

La sauvegarde est programmée dans la crontab de `root` :

```cron
0 2 * * * /usr/local/sbin/backup-lab-linux
```

Le serveur étant configuré en UTC, l'exécution correspond à 03:00 au Bénin (UTC+1).

Le journal contient une exécution automatique datée du 22 octobre 2026 à 02:00:01 UTC, avec le résultat `SUCCÈS`. Les archives manuelles des 21 octobre (08:47, 22:43, 23:46) figurent dans le même journal.

## 7. Politique de rétention

Le script conserve les sept archives les plus récentes, selon leur date de modification, et supprime les plus anciennes avec leur fichier de somme de contrôle. Les sauvegardes manuelles comptent dans ces sept archives : plusieurs exécutions manuelles dans la même journée consomment des emplacements.

## 8. Vérification des sauvegardes

Les contrôles sont rejoués par [`verifier-sauvegarde.sh`](../scripts/verifier-sauvegarde.sh), à lancer sur `srv-web-01` avec `sudo`. Le script ne modifie ni les sauvegardes réelles ni les fichiers actifs ; il écrit une sortie texte par contrôle.

| Contrôle | Méthode | Résultat au 25 octobre 2026 | Preuve |
|---|---|---|---|
| Intégrité SHA-256 | `sha256sum -c` sur la dernière archive | OK | [`sha256-check.txt`](../backup/sha256-check.txt) |
| Flux gzip | `gzip -tv` | OK | [`gzip-test.txt`](../backup/gzip-test.txt) |
| Restauration | Extraction dans `/var/tmp/restore-test`, puis comparaison avec les fichiers actifs | 24 fichiers sur 24 identiques : contenu, droits, propriétaires | [`restore-test.txt`](../backup/restore-test.txt) |
| Rétention | Copie du script sur un répertoire jetable : 9 archives factices et 1 sauvegarde réelle | 7 archives conservées, 3 supprimées avec leur somme | [`retention-test.txt`](../backup/retention-test.txt) |

Le test de rétention utilise une copie du script installé dont seule la variable `BACKUP_DIR` est redirigée vers un répertoire temporaire : les archives réelles ne sont ni lues ni modifiées.

Le fichier témoin de la restauration est `index.html` : son contenu, ses droits et son propriétaire sont comparés à ceux du fichier actif, puis tous les autres fichiers de l'archive sont comparés de la même façon. Si un fichier actif a changé depuis la création de l'archive, il est signalé : il faut alors relancer la sauvegarde avant la vérification.

## 9. Preuves associées

- [`backup-script.sh`](../backup/backup-script.sh) : script installé.
- [`backup-crontab.txt`](../backup/backup-crontab.txt) : planification.
- [`backup-log.txt`](../backup/backup-log.txt) : journal des opérations.
- [`backup-list.txt`](../backup/backup-list.txt) : archives et sommes présentes au 22 octobre 2026.
- [`sha256-check.txt`](../backup/sha256-check.txt), [`gzip-test.txt`](../backup/gzip-test.txt), [`restore-test.txt`](../backup/restore-test.txt), [`retention-test.txt`](../backup/retention-test.txt) : vérifications de la section 8.

## 10. Limites et améliorations possibles

- Les sauvegardes sont stockées sur le serveur qu'elles protègent : elles ne couvrent pas la perte du serveur ou de son disque. Une copie vers un autre serveur ([feuille de route](../ROADMAP.md)) est prévue.
- L'archive contient la copie de travail du script, mais ni le script installé (`/usr/local/sbin/backup-lab-linux`) ni la crontab de `root`.
- La liste des chemins est stricte : renommer ou supprimer un fichier sauvegardé (par exemple un site Nginx) fait échouer la sauvegarde tant que la liste n'est pas mise à jour.
- Le test de restauration couvre les fichiers sauvegardés ; il ne prouve pas la restauration complète des services.
- La clé privée TLS n'est pas sauvegardée : sa procédure de récupération reste à définir.
- Aucune notification n'est envoyée en cas d'échec, et l'espace disque n'est pas surveillé.

## 11. Conclusion

Les sauvegardes sont automatisées, journalisées, protégées par des permissions restrictives et contrôlées par SHA-256. L'exécution automatique a été observée, et la restauration comme la rétention sont prouvées par des sorties conservées dans le dépôt. La copie hors machine reste à mettre en place.
