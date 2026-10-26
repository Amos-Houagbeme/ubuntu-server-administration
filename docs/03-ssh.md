# 03 — Administration et sécurisation SSH

## 1. Objectif

Configurer l'administration distante de `srv-web-01` au moyen de SSH,
puis mettre en place une authentification par clé et des restrictions
sur les méthodes d'authentification.

## 2. Environnement

| Paramètre | Valeur |
|---|---|
| Serveur | srv-web-01 |
| Adresse IPv4 | 192.168.50.10 |
| Utilisateur distant | dokja |
| Port SSH | TCP 22 |
| Méthode d'authentification | Clé publique SSH |

## 3. Authentification par clé

La clé publique de l'hôte a été installée sur le serveur avec
`ssh-copy-id`.

Une connexion a ensuite été testée depuis l'ordinateur hôte sans
autoriser l'authentification par mot de passe.

Commande de test :

```bash
ssh -o PreferredAuthentications=publickey \
    -o PasswordAuthentication=no dokja@192.168.50.10
```

Le test a abouti à une ouverture de session sur `srv-web-01`.

Une configuration cliente a également été mise en place dans
`~/.ssh/config` afin de permettre une connexion simplifiée :

```bash
ssh srv-web-01
```

## 4. Paramètres de sécurité du serveur

Le fichier `00-security.conf` contient les directives suivantes :

```sshconfig
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

Leur rôle :

- `PubkeyAuthentication yes` autorise l'authentification par clé publique.
- `PasswordAuthentication no` désactive l'authentification SSH par mot de passe.
- `KbdInteractiveAuthentication no` désactive l'authentification interactive au clavier.
- `PermitRootLogin no` interdit la connexion SSH directe en tant que root.

Ces paramètres ont été vérifiés avec `sshd -T`.

## 5. Preuves associées

- [`00-security.conf`](../ssh/00-security.conf) : directives de durcissement.
- [`sshd-effective.txt`](../ssh/sshd-effective.txt) : configuration effective relevée avec `sshd -T`.
- [`sshd-syntax.txt`](../ssh/sshd-syntax.txt) : résultat du contrôle de syntaxe.

La syntaxe de la configuration a été vérifiée avec `sshd -t`. Une nouvelle connexion SSH a réussi après l'application de la configuration.

Aucune clé privée SSH ne doit être copiée dans ce dépôt. Seuls les fichiers de configuration et les résultats de vérification nécessaires sont conservés.

## 6. Décision sur l'exposition de SSH

La règle UFW autorise SSH depuis toutes les sources, en IPv4 et en IPv6 ([04 — UFW](04-ufw.md), section 6).

Ce choix est assumé : l'administration doit rester possible depuis n'importe quel réseau. Il est compensé par :

- l'authentification par clé publique uniquement ;
- la désactivation du mot de passe et de l'authentification interactive au clavier ;
- l'interdiction de la connexion directe de `root`.

Ces réglages protègent contre le devinage de mots de passe. Ils ne protègent pas contre une faille de `sshd` exploitable avant l'authentification.

## 7. Limites et améliorations possibles

- Limiter le débit des nouvelles connexions avec `sudo ufw limit OpenSSH` : même accès, rafales limitées.
- Dans un contexte réel, passer par un VPN ou un bastion et limiter la règle au réseau d'administration.
- Ajouter une preuve négative : une tentative de connexion par mot de passe doit échouer avec `Permission denied (publickey)`.

## 8. Conclusion

SSH est administré par clé depuis l'hôte, sans mot de passe ni connexion directe de `root`. Les paramètres effectifs ont été relevés avec `sshd -T`.
