#!/bin/bash

echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"

echo -e " \033[36;5m    ___          _             ___                         \033[0m"
echo -e " \033[36;5m   |   \ ___  __| |_____ _ _  / __|_ __ ____ _ _ _ _ __    \033[0m"
echo -e " \033[36;5m   | |) / _ \/ _| / / -_) \'_| \__ \ V  V / _\` | '_| '  \   \033[0m"
echo -e " \033[36;5m   |___/\___/\__|_\_\___|_|   |___/\_/\_/\__,_|_| |_|_|_|  \033[0m"
echo -e " \033[36;5m                                                           \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;5m                                                           \033[0m"


#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# Set the IP addresses of the admin, masters, and workers nodes
admin=192.168.3.5
master1=192.168.3.21
master2=192.168.3.22
master3=192.168.3.23
worker1=192.168.3.24
worker2=192.168.3.25

# User of remote machines
user=ubuntu

# Interface used on remotes
interface=eth0

# Set the virtual IP address (VIP)
vip=192.168.3.50

# Array of all master nodes
allmasters=($master1 $master2 $master3)

# Array of master nodes
masters=($master2 $master3)

# Array of worker nodes
workers=($worker1 $worker2)

# Array of all
all=($master1 $master2 $master3 $worker1 $worker2)

# Array of all minus master1
allnomaster1=($master2 $master3 $worker1 $worker2)

#Loadbalancer IP range
lbrange=192.168.3.60-192.168.3.80

#ssh certificate name variable
certName=id_rsa

#############################################
#            DO NOT EDIT BELOW              #
#############################################
# For testing purposes - in case time is wrong due to VM snapshots
sudo timedatectl set-ntp off
sudo timedatectl set-ntp on

# Move SSH certs to ~/.ssh and change permissions
cp /home/$user/{$certName,$certName.pub} /home/$user/.ssh
chmod 600 /home/$user/.ssh/$certName 
chmod 644 /home/$user/.ssh/$certName.pub

# Create SSH Config file to ignore checking (don't use in production!)
echo "StrictHostKeyChecking no" > ~/.ssh/config

#add ssh keys for all nodes
for node in "${all[@]}"; do
  ssh-copy-id $user@$node
done

# Install Docker for each node
for newnode in "${all[@]}"; do
  ssh $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  # Add Docker's official GPG key:
  apt-get update
  NEEDRESTART_MODE=a apt install ca-certificates curl gnupg -y
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  NEEDRESTART_MODE=a apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
  exit
EOF
  echo -e " \033[32;5mPolicyCoreUtils installed!\033[0m"
done

# Step 1: Create Swarm on first node
ssh -tt $user@$master1 -i ~/.ssh/$certName sudo su <<EOF
docker swarm init --advertise-addr $master1
docker swarm join-token manager | sed -n 3p | grep -Po 'docker swarm join --token \\K[^\\s]*'` >> master.txt
docker swarm join-token worker | sed -n 3p | grep -Po 'docker swarm join --token \\K[^\\s]*'` >> master.txt
exit
EOF
echo -e " \033[32;5mMaster1 Completed\033[0m"