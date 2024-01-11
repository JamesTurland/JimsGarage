#!/bin/bash

echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"

echo -e " \033[36;5m    ___          _             ___                         \033[0m"
echo -e " \033[36;5m   |   \ ___  __| |_____ _ _  / __|_ __ ____ _ _ _ _ __    \033[0m"
echo -e " \033[36;5m   | |) / _ \/ _| / / -_) '_| \__ \ V  V / _\` | '_| '  \   \033[0m"
echo -e " \033[36;5m   |___/\___/\__|_\_\___|_|   |___/\_/\_/\__,_|_| |_|_|_|  \033[0m"
echo -e " \033[36;5m                                                           \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;5m                                                           \033[0m"


#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# Set the IP addresses of the admin, managers, and workers nodes
admin=192.168.3.5
manager1=192.168.3.21
manager2=192.168.3.22
manager3=192.168.3.23
worker1=192.168.3.24
worker2=192.168.3.25

# Set the workers' hostnames (if using cloud-init in Proxmox it's the name of the VM)
workerHostname1=dockerSwarm-04
workerHostname2=dockerSwarm-05

# User of remote machines
user=ubuntu

# Interface used on remotes
interface=eth0

# Array of all manager nodes
allmanagers=($manager1 $manager2 $manager3)

# Array of manager nodes
managers=($manager2 $manager3)

# Array of worker nodes
workers=($worker1 $worker2)

# Array of all
all=($manager1 $worker1 $worker2)

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

# Copy SSH keys to MN1 to copy tokens back later
scp -i /home/$user/.ssh/$certName /home/$user/$certName $user@$manager1:~/.ssh
scp -i /home/$user/.ssh/$certName /home/$user/$certName.pub $user@$manager1:~/.ssh


# Install dependencies for each node (Docker, GlusterFS)
for newnode in "${all[@]}"; do
  ssh $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  iptables -F    
  iptables -P INPUT ACCEPT  
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
  NEEDRESTART_MODE=a apt install software-properties-common glusterfs-server -y
  systemctl start glusterd
  systemctl enable glusterd
  mkdir -p /gluster/volume1
  exit
EOF
  echo -e " \033[32;5m$newnode - Docker & GlusterFS installed!\033[0m"
done

# Step 1: Create Swarm on first node
ssh -tt $user@$manager1 -i ~/.ssh/$certName sudo su <<EOF
docker swarm init --advertise-addr $manager1 --default-addr-pool 10.20.0.0/16 --default-addr-pool-mask-length 26
docker swarm join-token manager | sed -n 3p | grep -Po 'docker swarm join --token \\K[^\\s]*' > manager.txt
docker swarm join-token worker | sed -n 3p | grep -Po 'docker swarm join --token \\K[^\\s]*' > worker.txt
echo "StrictHostKeyChecking no" > ~/.ssh/config
ssh-copy-id -i /home/$user/.ssh/$certName $user@$admin
scp -i /home/$user/.ssh/$certName /home/$user/manager.txt $user@$admin:~/manager
scp -i /home/$user/.ssh/$certName /home/$user/worker.txt $user@$admin:~/worker
exit
EOF
echo -e " \033[32;5mManager1 Completed\033[0m"

# Step 2: Set variables
managerToken=`cat manager`
workerToken=`cat worker`

# Step 3: Connect additional worker
for newnode in "${workers[@]}"; do
  ssh -tt $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  docker swarm join \
  --token  $workerToken \
  $manager1
  exit
EOF
  echo -e " \033[32;5m$newnode - Worker node joined successfully!\033[0m"
done

# Step 4: Create GlusterFS Cluster across all nodes (connect to Manager1) - we will also label our nodes to restrict deployment of services to workers only
ssh -tt $user@$manager1 -i ~/.ssh/$certName sudo su <<EOF
gluster peer probe $manager1; gluster peer probe $worker1; gluster peer probe $worker2;
gluster volume create staging-gfs replica 3 $manager1:/gluster/volume1 $worker1:/gluster/volume1 $worker2:/gluster/volume1 force
gluster volume start staging-gfs
chmod 666 /var/run/docker.sock
docker node update --label-add worker=true $workerHostname1
docker node update --label-add worker=true $workerHostname2
exit
EOF
echo -e " \033[32;5mGlusterFS created\033[0m"

# Step 5: Connect to all machines to ensure that GlusterFS mount restarts after boot
for newnode in "${all[@]}"; do
  ssh $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  echo 'localhost:/staging-gfs /mnt glusterfs defaults,_netdev,backupvolfile-server=localhost 0 0' >> /etc/fstab
  mount.glusterfs localhost:/staging-gfs /mnt
  chown -R root:docker /mnt
  exit
EOF
  echo -e " \033[32;5m$newnode - GlusterFS mounted on reboot\033[0m"
done

# OPTIONAL #
# Step 6: Add Portainer
ssh -tt $user@$manager1 -i ~/.ssh/$certName sudo su <<EOF
mkdir /mnt/Portainer
curl -L https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Docker-Swarm/portainer-agent-stack.yml -o portainer-agent-stack.yml
docker stack deploy -c portainer-agent-stack.yml portainer
docker node ls
docker service ls
gluster pool list
exit
EOF
echo -e " \033[32;5mPortainer deployed\033[0m"