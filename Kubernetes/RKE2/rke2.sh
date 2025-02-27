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
export KVVERSION="v0.7.2"

# The domain name of your cluster, inherit env by default
DOMAIN=${DOMAIN:-my.org}

# Set the IP addresses of the admin, masters, and workers nodes
# "admin" is your desktop machine from which you will be running the ops,
# just for this run, make sure you have sshd
# running and accessible here!
admin=192.168.60.22
master1=192.168.60.37
master2=192.168.60.38
master3=192.168.60.39

# Array of worker nodes
workers=(192.168.60.26 192.168.60.83)

# User of remote machines
remoteuser=ubuntu

# Interface used on remotes
interface=eth0

# Set the virtual IP address (VIP)
vip=192.168.60.171

# Array of extra master nodes
extramasters=("$master2" "$master3")

# Array of all master nodes
allmasters=("$master1" "${extramasters[@]}")

# Array of all minus master1
allnomaster1=("${extramasters[@]}" "${workers[@]}")

# Array of all
all=("$master1" "${allnomaster1[@]}")

#Loadbalancer IP range
lbrange=192.168.60.171-192.168.60.189

#ssh certificate name variable
certName=id_rsa

#############################################
#            DO NOT EDIT BELOW              #
#############################################

#fail immediately on errors
set -e

# For testing purposes - in case time is wrong due to VM snapshots
if hash timedatectl 2>/dev/null; then
	sudo timedatectl set-ntp off
	sudo timedatectl set-ntp on
fi

# Create a directory for the SSH certs
mkdir -p ~/.ssh

# Generate SSH certs if missing
if [ ! -f "$HOME"/.ssh/$certName ]; then
	if [ -f "$HOME"/$certName ]; then
		# Move SSH certs to ~/.ssh and change permissions
		cp "$HOME"/$certName{,.pub} "$HOME"/.ssh
		chmod 400 "$HOME"/.ssh/*
		chmod 700 "$HOME"/.ssh
	else
		ssh-keygen -t rsa -f "$HOME"/.ssh/$certName -N ""
	fi
fi

# Install Kubectl if not already present
if ! command -v kubectl version &>/dev/null; then
	if [ "$OS" == "Darwin" ]; then
		brew install kubernetes-cli
	else # assume Linux?
		echo -e " \033[31;5mKubectl not found, installing\033[0m"
		curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(uname -m)/kubectl"
		sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	fi
else
	echo -e " \033[32;5mKubectl already installed\033[0m"
fi

# Create SSH Config file to ignore checking (don't use in production!)
sed -i '1s/^/StrictHostKeyChecking no\n/' ~/.ssh/config

#add ssh keys for all nodes
for node in "${all[@]}"; do
	ssh-copy-id "$remoteuser@$node"
done

# Step 1: Create Kube VIP
# create RKE2's self-installing manifest dir
sudo mkdir -p /var/lib/rancher/rke2/server/manifests
# Install the kube-vip deployment into rke2's self-installing manifest folder
# shellcheck disable=SC2016
curl -s https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/RKE2/kube-vip |
	sed 's/$interface/'$interface'/g; s/$vip/'$vip'/g' >~/kube-vip.yaml
# Find/Replace all k3s entries to represent rke2
sed -i 's/k3s/rke2/g' ~/kube-vip.yaml
sudo cp ~/kube-vip.yaml /var/lib/rancher/rke2/server/manifests/kube-vip.yaml

# make kube folder to run kubectl later
mkdir -p ~/.kube

# create the rke2 config file
sudo mkdir -p /etc/rancher/rke2
echo >~/config.yaml
{
	echo "tls-san:"
	echo "  - $vip"
	echo "  - $master1"
	echo "  - $master2"
	echo "  - $master3"
	echo "write-kubeconfig-mode: 0644"
	echo "disable:"
	echo "  - rke2-ingress-nginx"
} >>~/config.yaml
# copy config.yaml to rancher directory
sudo cp ~/config.yaml /etc/rancher/rke2/config.yaml

{
	# update path with rke2-binaries
	echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml'
	# shellcheck disable=SC2016
	echo 'export PATH=${PATH}:/var/lib/rancher/rke2/bin'
	echo 'alias k=kubectl'
} >>~/.bashrc

# shellcheck disable=SC1090
source ~/.bashrc

# Step 2: Copy kube-vip.yaml and certs to all masters
for newnode in "${allmasters[@]}"; do
	scp -i ~/.ssh/$certName ~/kube-vip.yaml "$remoteuser@$newnode":~/kube-vip.yaml
	scp -i ~/.ssh/$certName ~/config.yaml "$remoteuser@$newnode":~/config.yaml
	scp -i ~/.ssh/$certName ~/.ssh/$certName{,.pub} "$remoteuser@$newnode":~/.ssh
	echo -e " \033[32;5mCopied successfully!\033[0m"
done

# Step 3: Connect to Master1 and move kube-vip.yaml and config.yaml. Then install RKE2, copy token back to admin machine. We then use the token to bootstrap additional masternodes
# shellcheck disable=SC2087
ssh -tt $remoteuser@$master1 -i ~/.ssh/$certName sudo su <<EOF
mkdir -p /var/lib/rancher/rke2/server/manifests
mv kube-vip.yaml /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
mkdir -p /etc/rancher/rke2
mv config.yaml /etc/rancher/rke2/config.yaml
{
	echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml'
	echo 'export PATH=\${PATH}:/var/lib/rancher/rke2/bin'
	echo 'alias k=kubectl'
} >> ~/.bashrc
source ~/.bashrc
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
echo "StrictHostKeyChecking no" > ~/.ssh/config
ssh-copy-id -i ~/.ssh/$certName $USER@$admin
scp -i ~/.ssh/$certName /var/lib/rancher/rke2/server/token $USER@$admin:~/token
scp -i ~/.ssh/$certName /etc/rancher/rke2/rke2.yaml $USER@$admin:~/.kube/rke2.yaml
exit
EOF
echo -e " \033[32;5mMaster1 Completed\033[0m"

# Step 4: Set variable to the token we just extracted, set kube config location
token=$(cat ~/token)
sed 's/127.0.0.1/'$master1'/g' <~/.kube/rke2.yaml >~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
export KUBECONFIG=${HOME}/.kube/config
sudo cp ~/.kube/config /etc/rancher/rke2/rke2.yaml
kubectl get nodes

# Step 5: Install kube-vip as network LoadBalancer - Install the kube-vip Cloud Provider
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

# Step 6: Add other Masternodes, note we import the token we extracted from step 3
for newnode in "${extramasters[@]}"; do
	# shellcheck disable=SC2087
	ssh -tt "$remoteuser@$newnode" -i ~/.ssh/$certName sudo su <<EOF
  mkdir -p /etc/rancher/rke2
  echo > /etc/rancher/rke2/config.yaml
  {
  	echo "token: $token"
  	echo "server: https://$master1:9345"
  	echo "tls-san:"
  	echo "  - $vip"
  	echo "  - $master1"
  	echo "  - $master2"
  	echo "  - $master3"
  } >> /etc/rancher/rke2/config.yaml
  curl -sfL https://get.rke2.io | sh -
  systemctl enable rke2-server.service
  time systemctl start rke2-server.service
  exit
EOF
	echo -e " \033[32;5mMaster node joined successfully!\033[0m"
done

kubectl get nodes

# Step 7: Add Workers
for newnode in "${workers[@]}"; do
	# shellcheck disable=SC2087
	ssh -tt "$remoteuser@$newnode" -i ~/.ssh/$certName sudo su <<EOF
  mkdir -p /etc/rancher/rke2
  echo > /etc/rancher/rke2/config.yaml
  echo "token: $token" >> /etc/rancher/rke2/config.yaml
  echo "server: https://$vip:9345" >> /etc/rancher/rke2/config.yaml
  echo "node-label:" >> /etc/rancher/rke2/config.yaml
  echo "  - worker=true" >> /etc/rancher/rke2/config.yaml
  echo "  - longhorn=true" >> /etc/rancher/rke2/config.yaml
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
  systemctl enable rke2-agent.service
  time systemctl start rke2-agent.service
  exit
EOF
	echo -e " \033[32;5mWorker node joined successfully!\033[0m"
done

kubectl get nodes

# Step 8: Install Metallb
echo -e " \033[32;5mDeploying Metallb\033[0m"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
# Download ipAddressPool and configure using lbrange above
# shellcheck disable=SC2016
curl -s https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/RKE2/ipAddressPool |
	sed 's/$lbrange/'$lbrange'/g' >~/ipAddressPool.yaml

# Step 9: Deploy IP Pools and l2Advertisement
echo -e " \033[32;5mAdding IP Pools, waiting for Metallb to be available first. This can take a long time as we're likely being rate limited for container pulls...\033[0m"
kubectl wait --namespace metallb-system \
	--for=condition=ready pod \
	--selector=component=controller \
	--timeout=1800s
kubectl apply -f ~/ipAddressPool.yaml
kubectl apply -f https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/RKE2/l2Advertisement.yaml

# Step 10: Install Rancher (Optional - Delete if not required)
#Install Helm
echo -e " \033[32;5mInstalling Helm\033[0m"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Add Rancher Helm Repo & create namespace
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system

# Install Cert-Manager
echo -e " \033[32;5mDeploying Cert-Manager\033[0m"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
	--namespace cert-manager \
	--create-namespace \
	--version v1.13.2
kubectl get pods --namespace cert-manager

# Install Rancher
echo -e " \033[32;5mDeploying Rancher\033[0m"
helm install rancher rancher-latest/rancher \
	--namespace cattle-system \
	--set hostname="rancher.$DOMAIN" \
	--set bootstrapPassword=admin
kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher

# Add Rancher LoadBalancer
kubectl get svc -n cattle-system
kubectl expose deployment rancher --name=rancher-lb --port=443 --type=LoadBalancer -n cattle-system
while [[ $(kubectl get svc -n cattle-system 'jsonpath={..status.conditions[?(@.type=="Pending")].status}') = "True" ]]; do
	sleep 5
	echo -e " \033[32;5mWaiting for LoadBalancer to come online\033[0m"
done
kubectl get svc -n cattle-system

echo -e " \033[32;5mAccess Rancher from the IP above - Password is admin!\033[0m"
