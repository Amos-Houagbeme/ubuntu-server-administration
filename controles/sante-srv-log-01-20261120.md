# Contrôle de santé : srv-log-01

- Date : 2026-11-20 07:53:17 UTC
- Utilisateur : kim

## Résumé

- ✅ Interface avec une IP 192.168.50.x
- ❌ UFW actif
- ✅ SSH : mot de passe désactivé (valeur effective)
- ✅ Heure synchronisée (NTPSynchronized=yes)
- ✅ rsyslog actif
- ✅ Aucune unité systemd en échec
- ✅ fstab valide (findmnt --verify)
- ✅ Disque / sous 90 %
- ✅ rsyslog écoute sur le port 514
- ✅ Dossier /var/log/remote présent

## Système

```
$ hostnamectl
 Static hostname: srv-log-01
       Icon name: computer-vm
         Chassis: vm 🖴
  Virtualization: kvm
Operating System: Ubuntu 24.04.3 LTS
          Kernel: Linux 6.8.0-71-generic
    Architecture: x86-64
 Hardware Vendor: QEMU
  Hardware Model: Standard PC _Q35 + ICH9, 2009_
Firmware Version: 1.16.3-debian-1.16.3-2
   Firmware Date: Tue 2014-04-01
    Firmware Age: 12y 7month 2w 6d
```

```
$ uptime
 07:53:17 up 24 min,  1 user,  load average: 0,00, 0,00, 0,00
```


## Réseau

```
$ ip -br a
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp1s0           UP             192.168.50.20/24 fe80::5054:ff:fe2d:4027/64 
```

```
$ ip route
default via 192.168.50.1 dev enp1s0 proto static 
192.168.50.0/24 dev enp1s0 proto kernel scope link src 192.168.50.20 
```

```
$ ss -tulnp
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess                                               
udp   UNCONN 0      0            0.0.0.0:514       0.0.0.0:*    users:(("rsyslogd",pid=653,fd=5))                    
udp   UNCONN 0      0         127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=477,fd=16))            
udp   UNCONN 0      0      127.0.0.53%lo:53        0.0.0.0:*    users:(("systemd-resolve",pid=477,fd=14))            
udp   UNCONN 0      0               [::]:514          [::]:*    users:(("rsyslogd",pid=653,fd=6))                    
tcp   LISTEN 0      4096         0.0.0.0:22        0.0.0.0:*    users:(("sshd",pid=838,fd=3),("systemd",pid=1,fd=89))
tcp   LISTEN 0      4096   127.0.0.53%lo:53        0.0.0.0:*    users:(("systemd-resolve",pid=477,fd=15))            
tcp   LISTEN 0      4096      127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=477,fd=17))            
tcp   LISTEN 0      4096            [::]:22           [::]:*    users:(("sshd",pid=838,fd=4),("systemd",pid=1,fd=90))
```


## Pare-feu

```
$ ufw status verbose
Status: inactive
```


## SSH (valeurs effectives)

```
$ sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|pubkeyauthentication|port) '
port 22
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
```


## Heure

```
$ timedatectl
               Local time: ven. 2026-11-20 07:53:17 UTC
           Universal time: ven. 2026-11-20 07:53:17 UTC
                 RTC time: ven. 2026-11-20 07:53:17
                Time zone: Etc/UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```


## Services

```
$ systemctl --failed --no-pager
  UNIT LOAD ACTIVE SUB DESCRIPTION

0 loaded units listed.
```

```
$ systemctl is-active rsyslog nginx docker chrony chronyd 2>&1
active
inactive
inactive
inactive
inactive
```


## Stockage

```
$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda    253:0    0  25G  0 disk 
├─vda1 253:1    0   1M  0 part 
└─vda2 253:2    0  25G  0 part /
```

```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1,1M  391M   1% /run
/dev/vda2        25G  6,6G   17G  29% /
tmpfs           2,0G     0  2,0G   0% /dev/shm
tmpfs           5,0M     0  5,0M   0% /run/lock
tmpfs           392M   12K  392M   1% /run/user/1000
```

```
$ findmnt --verify

0 parse errors, 0 errors, 1 warning
none
   [W] non-bind mount source /swap.img is a directory or regular file
```


## Réception rsyslog

```
$ ls -lR /var/log/remote | head -30
/var/log/remote:
total 152
drwxr-x--- 2 syslog adm   4096 oct.  25 19:17 srv-web-01
-rw-r--r-- 1 syslog adm 150521 oct.  25 19:15 srv-web-01.log

/var/log/remote/srv-web-01:
total 220
-rw-r--r-- 1 syslog syslog   9035 nov.  20 07:48 ssh.log
-rw-r--r-- 1 syslog syslog 205998 nov.  20 07:53 system.log
```

