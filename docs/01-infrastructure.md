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

## 3. Services déployés

- SSH pour l'administration distante : [03 — SSH](03-ssh.md).
- UFW pour le filtrage réseau : [04 — UFW](04-ufw.md).
- Nginx pour l'hébergement du site : [05 — Nginx](05-nginx.md).
- TLS pour sécuriser les communications HTTPS : [06 — HTTPS et TLS](06-https-tls.md).
- Sauvegardes automatisées et vérifiées : [07 — Sauvegarde](07-sauvegarde.md).

## 4. Vérifications réalisées

Les caractéristiques du système ont été vérifiées avec `hostnamectl`. L'état du réseau a été vérifié avec `ip -br address` et `ip route` ([02 — Réseau](02-reseau.md)).

## 5. Preuves associées

- [`hostnamectl.txt`](../infrastructure/hostnamectl.txt) : caractéristiques du système. Les identifiants uniques (Machine ID, Boot ID) n'y figurent pas.
- [`ip-address.txt`](../reseau/ip-address.txt) et [`ip-route.txt`](../reseau/ip-route.txt) : adressage et routage.

## 6. Limites et améliorations possibles

Cette documentation décrit `srv-web-01`. Le second serveur, `srv-log-01`, est en cours de configuration : voir la [feuille de route](../ROADMAP.md).

## 7. Conclusion

`srv-web-01` est une machine virtuelle Ubuntu Server 24.04.5 LTS sur KVM, adressée en IPv4 statique dans le réseau privé du laboratoire.
