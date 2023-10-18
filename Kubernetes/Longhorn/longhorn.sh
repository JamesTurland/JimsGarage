#!/bin/bash

echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"

echo -e " \033[36;5m                                                           \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;5m                                                           \033[0m"


#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################
# Set the IP addresses of master1
master1=192.168.3.21

# Set the IP addresses of your Longhorn nodes
longhorn1=192.168.3.26
longhorn2=192.168.3.27
longhorn3=192.168.3.28

# User of remote machines
user=ubuntu

# Interface used on remotes
interface=eth0

# Set the virtual IP address (VIP)
vip=192.168.3.50

# Array of longhorn nodes
storage=($longhorn1 $longhorn2 $longhorn3)

#############################################
#            DO NOT EDIT BELOW              #
#############################################
# For testing purposes - in case time is wrong due to VM snapshots
sudo timedatectl set-ntp off
sudo timedatectl set-ntp on

# Step 1: Add new longhorn nodes to cluster (note: label added)
for newnode in "${storage[@]}"; do
  k3sup join \
    --ip $newagent \
    --user $user \
    --sudo \
    --k3s-channel stable \
    --server-ip $master1 \
    --k3s-extra-args "--node-label "longhorn=true"" \
    --ssh-key $HOME/.ssh/id_rsa
  echo -e " \033[32;5mAgent node joined successfully!\033[0m"
done

# Step 2: Install Longhorn (using modified Official to pin to Longhorn Nodes)
kubectl apply -f https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/Longhorn/longhorn.yaml
kubectl get pods \
--namespace longhorn-system \
--watch

# Step 3: Expose UI
kubectl expose deployment longhorn-ui --name=longhorn-lb --port=80 --type=LoadBalancer -n longhorn-system

kubectl get nodes
kubectl get svc
kubectl get pods --all-namespaces -o wide

echo -e " \033[32;5mHappy Kubing! Access Nginx at EXTERNAL-IP above\033[0m"
