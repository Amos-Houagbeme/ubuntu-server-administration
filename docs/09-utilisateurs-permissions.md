# 09 — Utilisateurs, groupes, permissions et ACL

## 1. Objectif

Mettre en place sur `srv-web-01` un répertoire partagé dont l'accès dépend du rôle de chacun, puis prouver, compte par compte, ce qui est autorisé et ce qui est refusé.

| Rôle | Groupe | Droits voulus sur `/srv/web-partage` |
|---|---|---|
| Administrateurs web | `webadmins` | lecture et écriture |
| Administrateurs des journaux | `logadmins` | lecture seule |
| Tous les autres | aucun | aucun accès |

Les droits doivent aussi s'appliquer aux fichiers créés plus tard, sans dépendre de l'`umask` de leur créateur.

## 2. Environnement

| Élément | Valeur |
|---|---|
| Machine | `srv-web-01` |
| Compte d'administration | `dokja` (sudo) : ne sert pas à tester les droits |
| Comptes de test | `webuser`, `loguser`, `globaluser` |
| Répertoire | `/srv/web-partage`, propriétaire `root`, groupe `webadmins`, mode `2770` |

Les comptes de test n'ont pas de mot de passe utilisable : ils sont employés avec `sudo -u <compte>`, jamais pour une connexion. L'état final des comptes est dans [`comptes-et-groupes.txt`](../permissions/comptes-et-groupes.txt).

## 3. Principes appliqués

**Des groupes plutôt que des comptes individuels.** Les droits sont attribués à un rôle. Quand une personne arrive ou part, seule son appartenance à un groupe change, et aucun droit n'est à rechercher fichier par fichier. En entreprise, c'est le principe du contrôle d'accès par rôles ; les groupes Active Directory reçoivent de la même façon les droits NTFS sous Windows.

**Un compte témoin sans groupe.** `globaluser` prouve que « les autres » sont réellement exclus : un refus attendu et obtenu est une preuve, au même titre qu'un accès réussi.

**Le bit setgid sur le répertoire.** Sans lui, un fichier créé prend le groupe principal de son créateur (`webuser`) et les autres membres de `webadmins` ne peuvent plus le modifier par les droits de groupe. Avec lui, les nouveaux fichiers et sous-dossiers héritent du groupe du répertoire. Il n'agit pas sur les fichiers déjà présents ([`setgid-avant-apres.txt`](../permissions/setgid-avant-apres.txt)).

**Des ACL plutôt que les seuls droits classiques.** Les droits classiques n'offrent qu'un propriétaire, un seul groupe et « les autres ». Donner deux groupes des droits différents (`webadmins` en lecture et écriture, `logadmins` en lecture seule) tout en fermant l'accès aux autres exige des ACL. C'est une application du principe du moindre privilège.

**Des ACL par défaut.** Les ACL posées sur le répertoire ne concernent que lui. Les lignes `default:` sont copiées sur tout ce qui y est créé ensuite, sinon les droits fonctionnent le jour de la configuration et se dégradent dès les nouveaux fichiers.

**Le masque.** Le masque ACL plafonne les droits effectifs de tous les groupes nommés. Le « x » de `logadmins` sur un fichier n'est pas effectif (`#effective:r--`), car la création d'un fichier ne demande pas le droit d'exécution. Sur un dossier, le « x » reste nécessaire pour y entrer. `getfacl` affiche les droits effectifs ; `ls -l` affiche le masque à la place des droits du groupe dès qu'une ACL existe.

## 4. Configuration obtenue

- Le répertoire est en `drwxrws---+` : propriétaire `root`, groupe `webadmins`, setgid actif, aucun droit pour « les autres ».
- Les ACL du répertoire donnent `rwx` à `webadmins` et `r-x` à `logadmins`, avec les mêmes entrées en `default:` ([`dossier-acl.txt`](../permissions/dossier-acl.txt)).
- Un fichier et un sous-dossier créés par `webuser` reçoivent ces droits à leur création ([`fichier-acl.txt`](../permissions/fichier-acl.txt)).

L'entrée explicite `group:webadmins:rwx` a été ajoutée : sans elle, les droits de `webadmins` reposeraient sur la ligne `group::`, qui désigne le groupe propriétaire du fichier et suit un changement de groupe sans avertissement.

## 5. Vérifications réalisées

Le script [`test-acl.sh`](../scripts/test-acl.sh) exécute chaque action en tant que chaque compte, compare le résultat à la politique voulue et consigne les messages du système. Résultat du 22 novembre 2026 : **28 contrôles conformes sur 28**, refus compris ([`test-matrice-acl.md`](../permissions/test-matrice-acl.md)).

| Action | `webuser` | `loguser` | `globaluser` |
|---|---|---|---|
| Lister le répertoire | autorisé | autorisé | refusé |
| Lire un fichier | autorisé | autorisé | refusé |
| Modifier un fichier | autorisé | refusé | refusé |
| Créer un fichier ou un sous-dossier | autorisé | refusé | refusé |
| Supprimer un fichier d'un autre propriétaire | autorisé | refusé | refusé |

Neuf contrôles d'héritage complètent la matrice : groupe, ACL et setgid d'un fichier et d'un sous-dossier créés après la configuration, et exclusion des « autres » à chaque niveau.

Règles de lecture :

- **Lire** demande `r` sur le fichier et `x` sur chaque répertoire traversé.
- **Modifier** un fichier demande `w` sur le fichier.
- **Créer ou supprimer** une entrée demande `w` (et `x`) sur le répertoire qui la contient, pas sur le fichier.

## 6. Erreurs rencontrées

| Symptôme | Cause | Correction et prévention |
|---|---|---|
| `touch fichier` refusé alors que les droits étaient corrects | chemin relatif : le fichier était créé dans le répertoire personnel de `dokja` | utiliser le chemin complet ; vérifier `pwd` quand un test échoue de façon inattendue |
| `sudo -u webuser echo ... \| tee -a fichier` refusé | avec un tube, `sudo -u` ne s'applique qu'à la première commande ; `tee` s'exécutait sous `dokja` | placer `sudo -u` devant la commande qui ouvre le fichier : `... \| sudo -u webuser tee -a fichier` |
| `chmod +t` sur un fichier : le « T » s'affiche mais la suppression reste possible | le sticky bit n'a d'effet que sur un répertoire | le poser sur le répertoire, puis refaire le test |
| Renommage de compte incomplet (`usermod -l`) | le groupe principal et le répertoire personnel gardent l'ancien nom | compte vide : supprimé et recréé ; pour un compte utilisé, renommer aussi le groupe (`groupmod -n`) et déplacer le répertoire (`usermod -d ... -m`) |
| Le script de test se figeait au test de suppression par `loguser` | `rm` demandait une confirmation (fichier protégé en écriture), invisible car les erreurs du test sont capturées | `rm -f`, entrée standard fermée et délai maximal de 15 secondes par test |

## 7. Sticky bit : testé, non retenu

Le sticky bit, posé sur le répertoire, interdit de supprimer ou de renommer le fichier d'un autre propriétaire : `webuser` obtient `Operation not permitted` ([`sticky-bit-test.txt`](../permissions/sticky-bit-test.txt)). Il n'a pas été conservé : tous les membres de `webadmins` sont des administrateurs de confiance et disposent déjà de l'écriture sur les fichiers de chacun. Le sticky bit ne protège pas le contenu, qu'un membre peut toujours vider ou modifier. Le risque restant (suppression ou vidage par erreur) est couvert par la sauvegarde, avec la limite décrite dans [07](07-sauvegarde.md).

## 8. Preuves associées

- [`comptes-et-groupes.txt`](../permissions/comptes-et-groupes.txt) : groupes, appartenances et identifiants.
- [`dossier-acl.txt`](../permissions/dossier-acl.txt) : droits et ACL du répertoire.
- [`fichier-acl.txt`](../permissions/fichier-acl.txt) : ACL héritées par un fichier et un sous-dossier.
- [`setgid-avant-apres.txt`](../permissions/setgid-avant-apres.txt) : effet du setgid.
- [`test-matrice-acl.md`](../permissions/test-matrice-acl.md) : matrice de 28 contrôles.
- [`sticky-bit-test.txt`](../permissions/sticky-bit-test.txt) : test du sticky bit.

## 9. Limites et améliorations possibles

- Les tests utilisent `sudo -u` : ils reproduisent les droits d'un compte, pas une vraie session de connexion.
- Tout membre de `webadmins` peut supprimer, renommer ou vider les fichiers des autres (section 7).
- Les droits des fichiers déjà présents ne sont pas modifiés par les ACL par défaut : ils doivent être corrigés ou recréés.
- Cette mise en scène est simplifiée : en entreprise, `logadmins` consulterait les journaux sur le serveur de journaux plutôt que du contenu web. Le mécanisme (deux rôles, un répertoire partagé, héritage, refus du reste) est le même.
- Les privilèges `sudo` par rôle ne sont pas encore configurés ni documentés.

## 10. Conclusion

Le répertoire `/srv/web-partage` applique la politique voulue : `webadmins` lit et écrit, `logadmins` lit seulement, les autres n'ont aucun accès, y compris pour les fichiers et sous-dossiers créés ensuite. Les 28 contrôles de la matrice sont conformes.
