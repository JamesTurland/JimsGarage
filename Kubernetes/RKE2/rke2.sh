#!/bin/bash

echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"

echo -e " \033[36;5m                      ___ _  _____ ___                     \033[0m"
echo -e " \033[36;5m                     | _ \ |/ / __|_  )                    \033[0m"
echo -e " \033[36;5m                     |   / ' <| _| / /                     \033[0m"
echo -e " \033[36;5m                     |_|_\_|\_\___/___|                    \033[0m"
echo -e " \033[36;5m                                                           \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;5m                                                           \033[0m"


#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# Version of Kube-VIP to deploy
KVVERSION="v0.6.3"

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
echo "StrictHostKeyChecking no" > ~/.ssh/config

#add ssh keys for all nodes
for node in "${all[@]}"; do
  ssh-copy-id $user@$node
done

# Step 1: Create Kube VIP
# create RKE2's self-installing manifest dir
sudo mkdir -p /var/lib/rancher/rke2/server/manifests
# Install the kube-vip deployment into rke2's self-installing manifest folder
curl -sL https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/RKE2/k3s |  vipAddress=$vip vipInterface=$interface sh | sudo tee /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
# Find/Replace all k3s entries to represent rke2
sudo sed -i 's/k3s/rke2/g' /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
# copy kube-vip.yaml to home directory
sudo cp /var/lib/rancher/rke2/server/manifests/kube-vip.yaml ~/kube-vip.yaml
# change owner
sudo chown $user:$user kube-vip.yaml
# make kube folder to run kubectl later
mkdir ~/.kube

# create the rke2 config file
sudo mkdir -p /etc/rancher/rke2
touch config.yaml
echo "tls-san:" >> config.yaml 
echo "  - $vip" >> config.yaml
# copy config.yaml to rancher directory
sudo cp ~/config.yaml /etc/rancher/rke2/config.yaml

# update path with rke2-binaries
echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc ; echo 'export PATH=${PATH}:/var/lib/rancher/rke2/bin' >> ~/.bashrc ; echo 'alias k=kubectl' >> ~/.bashrc ; source ~/.bashrc ;

# Step 2: Copy kube-vip.yaml and certs to all masters
for newnode in "${allmasters[@]}"; do
  scp -i ~/.ssh/$certName $HOME/kube-vip.yaml $user@$newnode:~/kube-vip.yaml
  scp -i ~/.ssh/$certName $HOME/config.yaml $user@$newnode:~/config.yaml
  scp -i ~/.ssh/$certName ~/.ssh/{$certName,$certName.pub} $user@$newnode:~/.ssh
  echo -e " \033[32;5mCopied successfully!\033[0m"
done

# Step 3: Connect to Master1 and move kube-vip.yaml and config.yaml. Then install RKE2, copy token back to admin machine. We then use the token to bootstrap additional masternodes
ssh -tt $user@$master1 -i ~/.ssh/$certName sudo su <<EOF
mkdir -p /var/lib/rancher/rke2/server/manifests
mv kube-vip.yaml /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
mkdir -p /etc/rancher/rke2
mv config.yaml /etc/rancher/rke2/config.yaml
echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc ; echo 'export PATH=${PATH}:/var/lib/rancher/rke2/bin' >> ~/.bashrc ; echo 'alias k=kubectl' >> ~/.bashrc ; source ~/.bashrc ;
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
echo "StrictHostKeyChecking no" > ~/.ssh/config
ssh-copy-id -i /home/$user/.ssh/$certName $user@$admin
scp -i /home/$user/.ssh/$certName /var/lib/rancher/rke2/server/token $user@$admin:~/token
scp -i /home/$user/.ssh/$certName /etc/rancher/rke2/rke2.yaml $user@$admin:~/.kube/rke2.yaml
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml
exit
EOF
echo -e " \033[32;5mMaster1 Completed\033[0m"

# Step 4: Install kube-vip as network LoadBalancer - Install the kube-vip Cloud Provider
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
#IP range for loadbalancer services to use
kubectl create configmap -n kube-system kubevip --from-literal range-global=$lbrange

# Step 5: Set variable to the token we just extracted, set kube config location
token=`cat token`
sudo cat ~/.kube/rke2.yaml | sed 's/127.0.0.1/'$vip'/g' > $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=${HOME}/.kube/config
sudo cp ~/.kube/config /etc/rancher/rke2/rke2.yaml
kubectl get nodes

# Step 6: Add other Masternodes, note we import the token we extracted from step 3
for newnode in "${masters[@]}"; do
  ssh -tt $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  mkdir -p /etc/rancher/rke2
  touch /etc/rancher/rke2/config.yaml
  echo "token: $token" >> /etc/rancher/rke2/config.yaml
  echo "server: https://$master1:9345" >> /etc/rancher/rke2/config.yaml
  echo "tls-san:" >> /etc/rancher/rke2/config.yaml
  echo "  - $vip" >> /etc/rancher/rke2/config.yaml
  curl -sfL https://get.rke2.io | sh -
  systemctl enable rke2-server.service
  systemctl start rke2-server.service
  exit
EOF
  echo -e " \033[32;5mMaster node joined successfully!\033[0m"
done

kubectl get nodes -o wide

# Step 7: Add Workers
for newnode in "${workers[@]}"; do
  ssh -tt $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  mkdir -p /etc/rancher/rke2
  touch /etc/rancher/rke2/config.yaml
  echo "token: $token" >> /etc/rancher/rke2/config.yaml
  echo "server: https://$vip:9345" >> /etc/rancher/rke2/config.yaml
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
  systemctl enable rke2-agent.service
  systemctl start rke2-agent.service
  exit
EOF
  echo -e " \033[32;5mMaster node joined successfully!\033[0m"
done

kubectl get nodes -o wide

#Step 8: Setup Kube-VIP as LoadBalancer
#IP range for loadbalancer services to use
kubectl create configmap -n kube-system kubevip --from-literal range-global=$lbrange

# Step 9: Install Rancher (Optional - Delete if not required)
#Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Add Rancher Helm Repo & create namespace
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system

# Install Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
--namespace cert-manager \
--create-namespace \
--version v1.11.0
kubectl get pods --namespace cert-manager

# Install Rancher
helm install rancher rancher-latest/rancher \
 --namespace cattle-system \
 --set hostname=rancher.my.org \
 --set bootstrapPassword=admin
kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher

# Add Rancher LoadBalancer
kubectl get svc -n cattle-system
# sometimes it skips the install so do it again here - need to debug
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
kubectl expose deployment rancher --name=rancher-lb --port=443 --type=LoadBalancer -n cattle-system
while [[ $(kubectl get svc name=rancher-lb -n cattle-system 'jsonpath={..status.conditions[?(@.type=="Pending")].status}') = "True" ]]; do
   sleep 5
   echo -e " \033[32;5mWaiting for LoadBalancer to come online\033[0m" 
done
kubectl get svc -n cattle-system

echo -e " \033[32;5mAccess Rancher from the IP above - Password is admin!\033[0m"
