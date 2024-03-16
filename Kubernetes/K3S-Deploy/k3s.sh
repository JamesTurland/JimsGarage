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

# Version of Kube-VIP to deploy

KVVERSION="v0.7.0"

# K3S Version

k3sVersion="v1.27.10+k3s2"

# Set the IP addresses of the master and worker nodes.

masters=(10.0.5.1 10.0.5.2 10.0.5.3)
workers=(10.0.5.4 10.0.5.5)

# User of remote machines

user=bones

# Interface used on remotes

interface=eth0

# Set the virtual IP address (VIP)

vip=10.0.5.10

# Loadbalancer IP range

lbrange=10.0.5.100-10.0.5.120

# SSH certificate name variable

certName=id_ed25519

# Should we copy the above SSH cert to the local .ssh directory?
# (Only set if you haven't done this)

copyCert=false

#############################################
#            DO NOT EDIT BELOW              #
#############################################

# For testing purposes - in case time is wrong due to VM snapshots

sudo timedatectl set-ntp off
sudo timedatectl set-ntp on

# Create handy functions for outputting messages.

function notice {
  echo -e " \033[32;5m${1}\033[0m"
}

function error {
  echo -e " \033[31;5m${1}\033[0m"
}

# Move SSH certs to ~/.ssh and change permissions if requested.

if [ "${copyCert}" = true ]; then
  cp ${HOME}/{$certName,$certName.pub} ${HOME}/.ssh
  chmod 600 ${HOME}/.ssh/$certName
  chmod 644 ${HOME}/.ssh/$certName.pub
fi

# Set some SSH options for the sake of convenience. The default is to include
# our specified cert and to disable strict host key checking.

ssh_ops="-o StrictHostKeyChecking=no -i ${HOME}/.ssh/$certName"

# Create a temporary folder where we can work without leaving artifacts after
# the script completes.

tempdir=$(mktemp --tmpdir -d kube_install-XXXXX)

# Download all of the K3S-Deploy files necessary for our work.

repo_path=https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy

for repo_file in kube-vip ipAddressPool l2Advertisement.yaml; do
  curl --output-dir ${tempdir} -sO ${repo_path}/${repo_file}
done

# Before starting to modify the cluster, download any other remote resources
# that could cause us to abort if one isn't available.

curl --output-dir ${tempdir} -sO https://kube-vip.io/manifests/rbac.yaml
curl --output-dir ${tempdir} -sO https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
curl --output-dir ${tempdir} -sO https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
curl --output-dir ${tempdir} -sO https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
curl --output-dir ${tempdir} -sO https://raw.githubusercontent.com/inlets/inlets-operator/master/contrib/nginx-sample-deployment.yaml

# Install k3sup to local machine if not already present

if ! command -v k3sup version &> /dev/null
then
    error "k3sup not found, installing"
    curl -sLS https://get.k3sup.dev | sh
    sudo install k3sup /usr/local/bin/
else
    notice "k3sup already installed"
fi

# Install Kubectl if not already present

if ! command -v kubectl version &> /dev/null
then
    kc_version=$(curl -sL https://dl.k8s.io/release/stable.txt)
    error "Kubectl not found, installing version ${kc_version}"
    curl -LO "https://dl.k8s.io/release/${kc_version}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    notice "Kubectl already installed"
fi

# Add ssh keys for all nodes; this may have already been done as part of
# cloud-init, but it never hurts to be certain.

for node in ${masters[@]} ${workers[@]}; do
  ssh-copy-id ${ssh_ops} $user@$node
done

# Install policycoreutils for each node

for node in ${masters[@]} ${workers[@]}; do
  ssh ${ssh_ops} $user@$node sudo su <<EOF
  NEEDRESTART_MODE=a apt-get install policycoreutils -y
  exit
EOF
  notice "PolicyCoreUtils installed!"
done

# Step 1: Bootstrap First k3s Node

notice "Setting up first master node"

mkdir ~/.kube

k3sup install \
  --ip ${masters[0]} \
  --user $user \
  --tls-san $vip \
  --cluster \
  --k3s-version $k3sVersion \
  --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=${masters[0]} --node-taint node-role.kubernetes.io/master=true:NoSchedule" \
  --merge \
  --sudo \
  --local-path $HOME/.kube/config \
  --ssh-key $HOME/.ssh/$certName \
  --context k3s-ha

notice "First Node bootstrapped successfully!"

# Step 2: Install Kube-VIP for HA

kubectl apply -f ${tempdir}/rbac.yaml

# Step 3: Copy kube-vip.yaml to master1

sed -i 's/$interface/'$interface'/g; s/$vip/'$vip'/g' ${tempdir}/kube-vip
sed -i "s%/version.*%/version: ${KVVERSION}%g" ${tempdir}/kube-vip

scp ${ssh_ops} ${tempdir}/kube-vip $user@${masters[0]}:kube-vip.yaml

# Step 4: Connect to Master1 and move kube-vip.yaml

ssh ${ssh_ops} $user@${masters[0]} <<- EOF
  sudo mkdir -p /var/lib/rancher/k3s/server/manifests
  sudo mv kube-vip.yaml /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
EOF

# Step 5: Add new master nodes (servers) & workers

notice "Setting up remaining master nodes"

for newnode in ${masters[@]:1}; do
  k3sup join \
    --ip $newnode \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server \
    --server-ip ${masters[0]} \
    --ssh-key $HOME/.ssh/$certName \
    --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$newnode --node-taint node-role.kubernetes.io/master=true:NoSchedule" \
    --server-user $user

  notice "Master node ${newnode} joined successfully!"
done

# Add workers

notice "Setting up worker nodes"

for newagent in ${workers[@]}; do
  k3sup join \
    --ip $newagent \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server-ip ${masters[0]} \
    --ssh-key $HOME/.ssh/$certName \
    --k3s-extra-args "--node-label \"longhorn=true\" --node-label \"worker=true\""

  notice "Agent node ${newagent} joined successfully!"
done

# Step 6: Install kube-vip as network LoadBalancer - Install the kube-vip Cloud Provider

notice "Installing kube-vip as Load Balancer and Cloud Provider"

kubectl apply -f ${tempdir}/kube-vip-cloud-controller.yaml

# Step 7: Install Metallb

notice "Installing MetalLB"

kubectl apply -f ${tempdir}/namespace.yaml
kubectl apply -f ${tempdir}/metallb-native.yaml

# Configure ipAddressPool using lbrange above

notice "Setting up ip address pool"

cat ${tempdir}/ipAddressPool | sed 's/$lbrange/'$lbrange'/g' > ${tempdir}/ipAddressPool.yaml

# Step 8: Test with Nginx

notice "Testing with Nginx"

kubectl apply -f ${tempdir}/nginx-sample-deployment.yaml -n default
kubectl expose deployment nginx-1 --port=80 --type=LoadBalancer -n default

notice "Waiting for K3S to sync and LoadBalancer to come online"

while [[ $(kubectl get pods -l app=nginx -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 1
done

# Step 9: Deploy IP Pools and l2Advertisement

notice "Deploying IP Pools and l2Advertisement"

kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=component=controller \
                --timeout=120s

kubectl apply -f ${tempdir}/ipAddressPool.yaml
kubectl apply -f ${tempdir}/l2Advertisement.yaml

kubectl get nodes
kubectl get svc
kubectl get pods --all-namespaces -o wide

notice "Happy Kubing! Access Nginx at EXTERNAL-IP above"
