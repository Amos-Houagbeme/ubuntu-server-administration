# 02 — Réseau

## 1. Objectif

Décrire le réseau virtuel du laboratoire et la configuration réseau statique de `srv-web-01`.

## 2. Réseau virtuel

| Paramètre | Valeur |
|---|---|
| Nom | lab-linux |
| Mode | NAT |
| Sous-réseau | 192.168.50.0/24 |
| Passerelle | 192.168.50.1 |
| DHCP | Désactivé |
| Serveurs | srv-web-01 (192.168.50.10), srv-log-01 (192.168.50.20) |

En mode NAT, les machines du laboratoire peuvent joindre l'extérieur par l'intermédiaire de l'hôte, mais ne sont pas directement joignables depuis les réseaux extérieurs à l'hôte. L'hôte joint les machines virtuelles par la passerelle 192.168.50.1.

## 3. Configuration de `srv-web-01`

| Paramètre | Valeur |
|---|---|
| Interface | enp1s0 |
| Adresse IPv4 | 192.168.50.10/24 |
| Route par défaut | 192.168.50.1 |
| Résolveurs DNS | 8.8.8.8, 1.1.1.1 |
| Fichier Netplan | `01-lab-linux.yaml` |

L'adressage est statique : `dhcp4` est désactivé dans le fichier Netplan.

## 4. Vérifications réalisées

```bash
ip -br address
ip route
```

- L'interface `enp1s0` est active.
- L'adresse IPv4 correspond au plan d'adressage.
- La route par défaut pointe vers la passerelle du laboratoire.
- Le réseau 192.168.50.0/24 est directement accessible par `enp1s0`.

## 5. Preuves associées

- [`01-lab-linux.yaml`](../reseau/01-lab-linux.yaml) : configuration Netplan.
- [`ip-address.txt`](../reseau/ip-address.txt) : adresses des interfaces.
- [`ip-route.txt`](../reseau/ip-route.txt) : table de routage.

## 6. Limites et améliorations possibles

- Seule la configuration de `srv-web-01` est documentée ici ; celle de `srv-log-01` sera ajoutée avec l'étape correspondante ([feuille de route](../ROADMAP.md)).
- L'interface ne porte pas d'adresse IPv6 globale, seulement l'adresse link-local.
- La définition du réseau virtuel (`virsh net-dumpxml lab-linux`) n'est pas encore versée comme preuve.

## 7. Conclusion

`srv-web-01` est adressé en IPv4 statique dans le réseau NAT `lab-linux`, avec une route par défaut vers la passerelle du laboratoire.
