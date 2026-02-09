# Config file for NUT server
```
# Network UPS Tools: upsd.users
# User access definitions for upsd

# Admin user with full access
[admin]
    password = "admin"
    actions = SET
    actions = FSD
    instcmds = ALL
    upsmon primary

[client]
    password = client
    upsmon secondary

# Monitor user for upsmon with master privileges
[monuser]
    password = "monpass"
    upsmon ups = master
    actions = SET
    actions = FSD
    instcmds = ALL
```

# Example of using SNMP
```
[ups]
    driver = snmp-ups
    port = 192.168.1.104
    snmp_version = v1
    community = public
    desc = Network UPS
    pollinterval = 1
    pollfreq = 1
    user = nut
    group = nut 
```
 
# Commands for client setup
```
sudo apt install nut-client

upsc ups@192.168.200.116

sudo nano /etc/nut/upsmon.conf

MONITOR ups@192.168.200.116 1 client client secondary

sudo nano /etc/nut/nut.conf -> MODE=netclient

sudo systemctl restart nut-client

sudo systemctl enable nut-client
```