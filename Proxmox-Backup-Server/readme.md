# Video Commands:
1. Mount command: mount -t cifs -o rw,vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34 //IP-OF-NAS/SHARE-NAME /mnt/truenas
2. fstab: //IP-OF-NAS/SHARE-NAME /mnt/test-pbs cifs vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34,defaults 0 0