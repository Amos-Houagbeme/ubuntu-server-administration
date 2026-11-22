# Contrôle de santé : srv-web-01

- Date : 2026-11-20 07:53:09 UTC
- Utilisateur : dokja

## Résumé

- ✅ Interface avec une IP 192.168.50.x
- ✅ UFW actif
- ✅ SSH : mot de passe désactivé (valeur effective)
- ✅ Heure synchronisée (NTPSynchronized=yes)
- ✅ rsyslog actif
- ✅ Aucune unité systemd en échec
- ✅ fstab valide (findmnt --verify)
- ✅ Disque / sous 90 %
- ✅ nginx actif
- ✅ Configuration nginx valide (nginx -t)
- ✅ HTTPS répond (localhost:443)
- ✅ Port 80 redirige en 301
- ✅ rsyslog : envoi distant configuré
- ✅ Cron de sauvegarde présent

## Système

```
$ hostnamectl
 Static hostname: srv-web-01
       Icon name: computer-vm
         Chassis: vm 🖴
  Virtualization: kvm
Operating System: Ubuntu 24.04.5 LTS
          Kernel: Linux 6.8.0-147-generic
    Architecture: x86-64
 Hardware Vendor: QEMU
  Hardware Model: Standard PC _Q35 + ICH9, 2009_
Firmware Version: 1.16.3-debian-1.16.3-2
   Firmware Date: Tue 2014-04-01
    Firmware Age: 12y 7month 2w 6d
```

```
$ uptime
 07:53:09 up 23 min,  1 user,  load average: 0,00, 0,00, 0,00
```


## Réseau

```
$ ip -br a
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp1s0           UP             192.168.50.10/24 fe80::5054:ff:fe43:986c/64 
```

```
$ ip route
default via 192.168.50.1 dev enp1s0 proto static 
192.168.50.0/24 dev enp1s0 proto kernel scope link src 192.168.50.10 
```

```
$ ss -tulnp
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess                                                                      
udp   UNCONN 0      0            0.0.0.0:42835      0.0.0.0:*    users:(("rsyslogd",pid=706,fd=7))                                           
udp   UNCONN 0      0         127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=517,fd=16))                                   
udp   UNCONN 0      0      127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=517,fd=14))                                   
tcp   LISTEN 0      511          0.0.0.0:80         0.0.0.0:*    users:(("nginx",pid=877,fd=5),("nginx",pid=876,fd=5),("nginx",pid=875,fd=5))
tcp   LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=869,fd=3),("systemd",pid=1,fd=85))                       
tcp   LISTEN 0      4096      127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=517,fd=17))                                   
tcp   LISTEN 0      511          0.0.0.0:443        0.0.0.0:*    users:(("nginx",pid=877,fd=7),("nginx",pid=876,fd=7),("nginx",pid=875,fd=7))
tcp   LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=517,fd=15))                                   
tcp   LISTEN 0      511             [::]:80            [::]:*    users:(("nginx",pid=877,fd=6),("nginx",pid=876,fd=6),("nginx",pid=875,fd=6))
tcp   LISTEN 0      4096            [::]:22            [::]:*    users:(("sshd",pid=869,fd=4),("systemd",pid=1,fd=86))                       
tcp   LISTEN 0      511             [::]:443           [::]:*    users:(("nginx",pid=877,fd=8),("nginx",pid=876,fd=8),("nginx",pid=875,fd=8))
```


## Pare-feu

```
$ ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp (OpenSSH)           ALLOW IN    Anywhere                  
80/tcp                     ALLOW IN    192.168.50.0/24           
443/tcp                    ALLOW IN    192.168.50.0/24           
22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)             

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
               Local time: ven. 2026-11-20 07:53:09 UTC
           Universal time: ven. 2026-11-20 07:53:09 UTC
                 RTC time: ven. 2026-11-20 07:53:09
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
active
inactive
inactive
inactive
```


## Stockage

```
$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda    253:0    0  30G  0 disk 
├─vda1 253:1    0   1M  0 part 
└─vda2 253:2    0  30G  0 part /
```

```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1,1M  391M   1% /run
/dev/vda2        30G  7,8G   21G  28% /
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


## Nginx

```
$ nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

```
$ curl -ksI https://localhost | head -5
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 20 Nov 2026 07:53:09 GMT
Content-Type: text/html
Content-Length: 663
```

```
$ curl -sI http://localhost | head -3
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 20 Nov 2026 07:53:09 GMT
```


## Sauvegarde

```
$ { crontab -l -u 'dokja'; crontab -l -u root; } 2>&1 | grep -v '^#'
no crontab for dokja
0 2 * * * /usr/local/sbin/backup-lab-linux
```

```
$ ls -lt /var/backups /srv/backups /home/dokja/backups 2>/dev/null | head -15
/var/backups:
total 1764
-rw-r--r-- 1 root root      0 nov.  18 13:41 dpkg.arch.0
drwx------ 2 root root   4096 oct.  26 16:41 lab-linux
-rw-r--r-- 1 root root 715272 oct.  26 09:44 dpkg.status.0
-rw-r--r-- 1 root root     32 oct.  26 09:13 dpkg.arch.1.gz
-rw-r--r-- 1 root root 180366 oct.  25 06:56 dpkg.status.1.gz
-rw-r--r-- 1 root root  40960 oct.  24 14:05 alternatives.tar.0
-rw-r--r-- 1 root root     32 oct.  24 14:05 dpkg.arch.2.gz
-rw-r--r-- 1 root root 180175 oct.  22 06:37 dpkg.status.2.gz
-rw-r--r-- 1 root root     32 oct.  21 07:00 dpkg.arch.3.gz
-rw-r--r-- 1 root root 180175 oct.  20 06:50 dpkg.status.3.gz
-rw-r--r-- 1 root root  42480 oct.  20 06:50 apt.extended_states.0
-rw-r--r-- 1 root root   2115 oct.  19 00:00 alternatives.tar.1.gz
-rw-r--r-- 1 root root     32 oct.  19 00:00 dpkg.arch.4.gz
```


## Envoi rsyslog

```
$ grep -rEs '^[^#]*@@?[0-9a-zA-Z]' /etc/rsyslog.conf /etc/rsyslog.d/
/etc/rsyslog.d/60-remote.conf:*.* @192.168.50.20:514
```


## Message de test envoyé

TAG : `healthcheck-20261120075309`
À vérifier sur srv-log-01 avec : `sudo bash health-check.sh healthcheck-20261120075309`
