#!/bin/bash

echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"

echo -e " \033[36;5m         _  _________   ___         _        _ _           \033[0m"
echo -e " \033[36;5m        | |/ |__ / __| |_ _|_ _  __| |_ __ _| | |          \033[0m"
echo -e " \033[36;5m        | ' < |_ \__ \  | || ' \(_-|  _/ _\` | | |          \033[0m"
echo -e " \033[36;5m        |_|\_|___|___/ |___|_||_/__/\__\__,_|_|_|          \033[0m"
echo -e " \033[36;5m                                                           \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;5m                                                           \033[0m"


#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# This is an update version of the K3S script that install longhorn on the worker nodes.
# The worker nodes are scaled to 3 for redundancy and HA
# This has the added benefit of using local storage on worker nodes (faster)

# Version of Kube-VIP to deploy
KVVERSION="v0.6.3"

# K3S Version
k3sVersion="v1.28.7+k3s1"

# Set the IP addresses of the master and work nodes
master1=192.168.3.21
master2=192.168.3.22
master3=192.168.3.23
worker1=192.168.3.24
worker2=192.168.3.25
worker3=192.168.3.26

# User of remote machines
user=ubuntu

# Interface used on remotes
interface=eth0

# Set the virtual IP address (VIP)
vip=192.168.3.50

# Array of master nodes
masters=($master2 $master3)

# Array of worker nodes
workers=($worker1 $worker2 $worker3)

# Array of all
all=($master1 $master2 $master3 $worker1 $worker2 $worker3)

# Array of all minus master
allnomaster1=($master2 $master3 $worker1 $worker2 $worker3)

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

# Install k3sup to local machine if not already present
if ! command -v k3sup version &> /dev/null
then
    echo -e " \033[31;5mk3sup not found, installing\033[0m"
    curl -sLS https://get.k3sup.dev | sh
    sudo install k3sup /usr/local/bin/
else
    echo -e " \033[32;5mk3sup already installed\033[0m"
fi

# Install Kubectl if not already present
if ! command -v kubectl version &> /dev/null
then
    echo -e " \033[31;5mKubectl not found, installing\033[0m"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo -e " \033[32;5mKubectl already installed\033[0m"
fi

# Create SSH Config file to ignore checking (don't use in production!)
sed -i '1s/^/StrictHostKeyChecking no\n/' ~/.ssh/config

#add ssh keys for all nodes
for node in "${all[@]}"; do
  ssh-copy-id $user@$node
done

# Install policycoreutils for each node
for newnode in "${all[@]}"; do
  ssh $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  NEEDRESTART_MODE=a apt install policycoreutils -y
  exit
EOF
  echo -e " \033[32;5mPolicyCoreUtils installed!\033[0m"
done

# Step 1: Bootstrap First k3s Node
mkdir ~/.kube
k3sup install \
  --ip $master1 \
  --user $user \
  --tls-san $vip \
  --cluster \
  --k3s-version $k3sVersion \
  --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$master1 --node-taint node-role.kubernetes.io/master=true:NoSchedule" \
  --merge \
  --sudo \
  --local-path $HOME/.kube/config \
  --ssh-key $HOME/.ssh/$certName \
  --context k3s-ha
echo -e " \033[32;5mFirst Node bootstrapped successfully!\033[0m"

# Step 2: Install Kube-VIP for HA
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml

# Step 3: Download kube-vip
curl -sO https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/kube-vip
cat kube-vip | sed 's/$interface/'$interface'/g; s/$vip/'$vip'/g' > $HOME/kube-vip.yaml

# Step 4: Copy kube-vip.yaml to master1
scp -i ~/.ssh/$certName $HOME/kube-vip.yaml $user@$master1:~/kube-vip.yaml


# Step 5: Connect to Master1 and move kube-vip.yaml
ssh $user@$master1 -i ~/.ssh/$certName <<- EOF
  sudo mkdir -p /var/lib/rancher/k3s/server/manifests
  sudo mv kube-vip.yaml /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
EOF

# Step 6: Add new master nodes (servers) & workers
for newnode in "${masters[@]}"; do
  k3sup join \
    --ip $newnode \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server \
    --server-ip $master1 \
    --ssh-key $HOME/.ssh/$certName \
    --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$newnode --node-taint node-role.kubernetes.io/master=true:NoSchedule" \
    --server-user $user
  echo -e " \033[32;5mMaster node joined successfully!\033[0m"
done

# add workers
for newagent in "${workers[@]}"; do
  k3sup join \
    --ip $newagent \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server-ip $master1 \
    --ssh-key $HOME/.ssh/$certName \
    --k3s-extra-args "--node-label \"longhorn=true\" --node-label \"worker=true\""
  echo -e " \033[32;5mAgent node joined successfully!\033[0m"
done

# Step 7: Install kube-vip as network LoadBalancer - Install the kube-vip Cloud Provider
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

# Step 8: Install Metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
# Download ipAddressPool and configure using lbrange above
curl -sO https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/ipAddressPool
cat ipAddressPool | sed 's/$lbrange/'$lbrange'/g' > $HOME/ipAddressPool.yaml

# Step 9: Test with Nginx
kubectl apply -f https://raw.githubusercontent.com/inlets/inlets-operator/master/contrib/nginx-sample-deployment.yaml -n default
kubectl expose deployment nginx-1 --port=80 --type=LoadBalancer -n default

echo -e " \033[32;5mWaiting for K3S to sync and LoadBalancer to come online\033[0m"

while [[ $(kubectl get pods -l app=nginx -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 1
done

# Step 10: Deploy IP Pools and l2Advertisement
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=component=controller \
                --timeout=120s
kubectl apply -f ipAddressPool.yaml
kubectl apply -f https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/l2Advertisement.yaml

kubectl get nodes
kubectl get svc
kubectl get pods --all-namespaces -o wide

echo -e " \033[32;5mHappy Kubing! Access Nginx at EXTERNAL-IP above\033[0m"

# Step 11: Install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Step 12: Add Rancher Helm Repository
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system

# Step 13: Install Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
--namespace cert-manager \
--create-namespace \
--version v1.13.2
kubectl get pods --namespace cert-manager

# Step 14: Install Rancher
helm install rancher rancher-latest/rancher \
 --namespace cattle-system \
 --set hostname=rancher.my.org \
 --set bootstrapPassword=admin
kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher

# Step 15: Expose Rancher via Loadbalancer
kubectl get svc -n cattle-system
kubectl expose deployment rancher --name=rancher-lb --port=443 --type=LoadBalancer -n cattle-system
kubectl get svc -n cattle-system

# Profit: Go to Rancher GUI
echo -e " \033[32;5mHit the url… and create your account\033[0m"
echo -e " \033[32;5mBe patient as it downloads and configures a number of pods in the background to support the UI (can be 5-10mins)\033[0m"

# Step 16: Install Longhorn (using modified Official to pin to Longhorn Nodes)
echo -e " \033[32;5mInstalling Longhorn - It can take a while for all pods to deploy...\033[0m"
kubectl apply -f https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/Longhorn/longhorn.yaml
kubectl get pods \
--namespace longhorn-system \
--watch

# Step 17: Print out confirmation

kubectl get nodes
kubectl get svc -n longhorn-system

echo -e " \033[32;5mHappy Kubing! Access Longhorn through Rancher UI\033[0m"
