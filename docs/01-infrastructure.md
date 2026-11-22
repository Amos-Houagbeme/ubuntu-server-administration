# 01 — Infrastructure

## 1. Objectif

Mettre en place une infrastructure Linux virtuelle afin de pratiquer l'administration système, le réseau, la sécurisation des services, les sauvegardes et le diagnostic d'incidents.

## 2. Machine documentée : `srv-web-01`

| Paramètre | Valeur |
|---|---|
| Nom d'hôte | srv-web-01 |
| Système | Ubuntu Server 24.04.5 LTS |
| Virtualisation | KVM/QEMU, piloté par libvirt (virt-manager) |
| Architecture | x86-64 |
| Adresse IPv4 | 192.168.50.10/24 |
| Interface réseau | enp1s0 |
| Rôle | Serveur web et administration |

## 3. Machine documentée : `srv-log-01`

| Paramètre | Valeur |
|---|---|
| Nom d'hôte | srv-log-01 |
| Système | Ubuntu Server 24.04.3 LTS |
| Virtualisation | KVM/QEMU, piloté par libvirt (virt-manager) |
| Adresse IPv4 | 192.168.50.20/24 |
| Interface réseau | enp1s0 |
| Utilisateur d'administration | kim |
| Rôle | Serveur de journaux (rsyslog) |

Relevé dans [`sante-srv-log-01-20261120.md`](../controles/sante-srv-log-01-20261120.md).

## 4. Services déployés

- SSH pour l'administration distante : [03 — SSH](03-ssh.md).
- UFW pour le filtrage réseau : [04 — UFW](04-ufw.md).
- Nginx pour l'hébergement du site : [05 — Nginx](05-nginx.md).
- TLS pour sécuriser les communications HTTPS : [06 — HTTPS et TLS](06-https-tls.md).
- Sauvegardes automatisées et vérifiées : [07 — Sauvegarde](07-sauvegarde.md).
- Journaux centralisés : [08 — Journaux centralisés](08-journaux-centralises.md).
- Comptes, groupes et ACL : [09 — Utilisateurs et permissions](09-utilisateurs-permissions.md).

## 5. Vérifications réalisées

Les caractéristiques du système ont été vérifiées avec `hostnamectl`. L'état du réseau a été vérifié avec `ip -br address` et `ip route` ([02 — Réseau](02-reseau.md)).

## 6. Preuves associées

- [`hostnamectl.txt`](../infrastructure/hostnamectl.txt) : caractéristiques du système. Les identifiants uniques (Machine ID, Boot ID) n'y figurent pas.
- [`ip-address.txt`](../reseau/ip-address.txt) et [`ip-route.txt`](../reseau/ip-route.txt) : adressage et routage.

## 7. Limites et améliorations possibles

Le serveur `srv-log-01` n'a pas encore de pare-feu activé : voir [08](08-journaux-centralises.md) et la [feuille de route](../ROADMAP.md).

## 8. Conclusion

`srv-web-01` (Ubuntu Server 24.04.5 LTS) et `srv-log-01` (Ubuntu Server 24.04.3 LTS) sont des machines virtuelles sur KVM, adressées en IPv4 statique dans le réseau privé du laboratoire.
