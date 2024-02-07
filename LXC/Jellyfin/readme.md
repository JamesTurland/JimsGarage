# Find Device Numbers
```
ls -l /dev/dri
```

# Find Group Numbers
```
cat /etc/group
```

# Add Group Numbers Values to subgid
Change values to map the to above ^^
```
nano /etc/subgid
```
Paste at the bottom, for example:
```
root:44:1
root:104:1
```

# Create CT Using Wizard. Edit .conf In /etc/pve/lxc
Edit your device IDs and renderD***
Ensure you match the idmap values
```
arch: amd64
cores: 2
cpulimit: 2
features: nesting=1
hostname: test-gpu-04
memory: 3000
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:06:18:78,ip=dhcp,type=veth
ostype: debian
rootfs: local-lvm:vm-104-disk-0,size=20G
swap: 512
unprivileged: 1
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
lxc.idmap: u 0 100000 65536
lxc.idmap: g 0 100000 44
lxc.idmap: g 44 44 1
lxc.idmap: g 45 100045 62
lxc.idmap: g 107 104 1
lxc.idmap: g 108 100108 65428
```

# Add Root to Groups
Do this on your Proxmox Host
```
usermod -aG render,video root
```

# Whatever You Want...
Install Docker, run apps, even change your LXC for a Linux Desktop!!!
