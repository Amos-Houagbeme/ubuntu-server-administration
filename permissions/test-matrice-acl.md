# Test de la matrice d'accès : /srv/web-partage

- Hôte : srv-web-01
- Date : 2026-11-22 12:10:07 UTC
- Sticky bit sur le dossier : non
- Résultat : 28 conformes, 0 non conformes

## Matrice (attendu = politique voulue, obtenu = résultat réel)

| Action | Utilisateur | Attendu | Obtenu | Résultat | Pourquoi | Message système |
|---|---|---|---|---|---|---|
| Lister le dossier | webuser | autorisé | autorisé | ✅ | ACL group:webadmins:rwx : r et x présents |  |
| Lister le dossier | loguser | autorisé | autorisé | ✅ | ACL group:logadmins:r-x : r et x présents |  |
| Lister le dossier | globaluser | refusé | refusé | ✅ | catégorie 'autres' : other::---, ni r ni x | ls: cannot open directory '/srv/web-partage': Permission denied |
| Lister (compte admin, sans sudo) | dokja | refusé | refusé | ✅ | dokja n'est dans aucun des deux groupes : il tombe dans 'autres' | ls: cannot open directory '/srv/web-partage': Permission denied |
| Lire un fichier | webuser | autorisé | autorisé | ✅ | droit effectif rw- via l'ACL webadmins |  |
| Lire un fichier | loguser | autorisé | autorisé | ✅ | droit effectif r-- via l'ACL logadmins (le x est coupé par le masque) |  |
| Lire un fichier | globaluser | refusé | refusé | ✅ | ne peut même pas atteindre le fichier : le dossier lui est fermé | grep: /srv/web-partage/_tst_25573_fichier: Permission denied |
| Ajouter du texte | webuser | autorisé | autorisé | ✅ | w effectif via l'ACL webadmins |  |
| Ajouter du texte | loguser | refusé | refusé | ✅ | logadmins n'a que r sur le fichier (effective r--) | _: 1: cannot create /srv/web-partage/_tst_25573_fichier: Permission de |
| Ajouter du texte | globaluser | refusé | refusé | ✅ | dossier fermé, fichier inatteignable | _: 1: cannot create /srv/web-partage/_tst_25573_fichier: Permission de |
| Créer un fichier | webuser | autorisé | autorisé | ✅ | webadmins a rwx sur le dossier, donc w |  |
| Créer un fichier | loguser | refusé | refusé | ✅ | logadmins a r-x sur le dossier : pas de w | touch: cannot touch '/srv/web-partage/_tst_25573_new_loguser': Permiss |
| Créer un fichier | globaluser | refusé | refusé | ✅ | other::--- sur le dossier | touch: cannot touch '/srv/web-partage/_tst_25573_new_globaluser': Perm |
| Créer un sous-dossier | webuser | autorisé | autorisé | ✅ | w sur le dossier parent via webadmins |  |
| Créer un sous-dossier | loguser | refusé | refusé | ✅ | pas de w sur le dossier parent | mkdir: cannot create directory ‘/srv/web-partage/_tst_25573_dir_logu |
| Créer un sous-dossier | globaluser | refusé | refusé | ✅ | other::--- sur le dossier parent | mkdir: cannot create directory ‘/srv/web-partage/_tst_25573_dir_glob |
| Supprimer un fichier (propriétaire root) | webuser | autorisé | autorisé | ✅ | w+x sur le dossier via webadmins, pas de sticky bit : tout membre peut supprimer |  |
| Supprimer un fichier (propriétaire root) | loguser | refusé | refusé | ✅ | pas de w sur le dossier (r-x seulement) | rm: cannot remove '/srv/web-partage/_tst_25573_del_loguser': Permissio |
| Supprimer un fichier (propriétaire root) | globaluser | refusé | refusé | ✅ | dossier fermé | rm: cannot remove '/srv/web-partage/_tst_25573_del_globaluser': Permis |

## Héritage et configuration

- ✅ Fichier créé par webuser : groupe = webadmins : le setgid fait hériter du groupe du dossier, pas du groupe privé de webuser
- ✅ Fichier créé par webuser : ACL webadmins:rwx : l'ACL par défaut du dossier a été copiée sur le fichier
- ✅ Fichier créé par webuser : ACL logadmins:r-x : idem pour logadmins (le droit effectif sera r-- à cause du masque)
- ✅ Fichier créé par webuser : other::--- : les autres n'ont rien, même sans compter sur l'umask
- ✅ Sous-dossier : setgid hérité : le s dans les droits du groupe doit se transmettre aux sous-dossiers
- ✅ Sous-dossier : groupe = webadmins : conséquence du setgid
- ✅ Sous-dossier : ACL par défaut transmise : default:group:logadmins:r-x doit se retrouver, pour que l'héritage continue au niveau suivant
- ✅ Sous-dossier : other::--- : les autres restent exclus à tous les niveaux
- ✅ Dossier racine : other::--- et default:other::--- : la règle 'autres exclus' existe pour le dossier ET pour ce qui sera créé

## Configuration du dossier

```
$ ls -ld /srv/web-partage
drwxrws---+ 4 root webadmins 4096 nov.  22 12:10 /srv/web-partage

$ getfacl -p /srv/web-partage
# file: /srv/web-partage
# owner: root
# group: webadmins
# flags: -s-
user::rwx
group::rwx
group:webadmins:rwx
group:logadmins:r-x
mask::rwx
other::---
default:user::rwx
default:group::rwx
default:group:webadmins:rwx
default:group:logadmins:r-x
default:mask::rwx
default:other::---

```

## Groupes

```
webadmins:x:1001:webuser
logadmins:x:1002:loguser
uid=1004(webuser) gid=1006(webuser) groups=1006(webuser),1001(webadmins)
uid=1002(loguser) gid=1004(loguser) groups=1004(loguser),1002(logadmins)
uid=1003(globaluser) gid=1005(globaluser) groups=1005(globaluser)
```
