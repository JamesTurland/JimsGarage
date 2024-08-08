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
k3sVersion="v1.26.10+k3s2"

# Define node types and their properties
declare -A nodes=(
    ["master1"]="ip=192.168.2.132,user=laneone,interface=eth0,type=master"
    ["master2"]="ip=192.168.2.133,user=laneone,interface=eth0,type=master"
    ["master3"]="ip=192.168.2.134,user=laneone,interface=eth0,type=master"
    ["worker1"]="ip=192.168.2.129,user=laneone,interface=eth0,type=worker,labels=longhorn=true,worker=true"
    ["worker2"]="ip=192.168.2.130,user=laneone,interface=eth0,type=worker,labels=longhorn=true,worker=true"
    ["worker3"]="ip=192.168.2.131,user=laneone,interface=eth0,type=worker,labels=longhorn=true,worker=true"
    ["worker4"]="ip=192.168.2.125,user=laneone,interface=enp34s0,type=worker,labels=worker=true,auth=password,password=l"
    ["worker5"]="ip=192.168.2.104,user=laneone,interface=enp104s0,type=worker,labels=worker=true,auth=password,password=l"
)

# Set the virtual IP address (VIP)
vip=192.168.2.50

#Loadbalancer IP range
lbrange=192.168.2.60-192.168.2.100

#ssh certificate name variable
certName=id_rsa

# Additional k3s flags for metrics
common_extra_args="--kubelet-arg containerd=/run/k3s/containerd/containerd.sock"
server_extra_args="--no-deploy servicelb --no-deploy traefik --kube-controller-manager-arg bind-address=0.0.0.0 --kube-proxy-arg metrics-bind-address=0.0.0.0 --kube-scheduler-arg bind-address=0.0.0.0 --etcd-expose-metrics true"
agent_extra_args="--node-label worker=true"

# Create Grafana admin credentials

grafana_user="adminuser"  # desired grafana username
grafana_password="adminpassword"  # Generates a random 12-character password


#############################################
#            HELPER FUNCTIONS               #
#############################################

get_node_ip() {
    echo "${nodes[$1]}" | grep -oP 'ip=\K[^,]+'
}

get_node_user() {
    echo "${nodes[$1]}" | grep -oP 'user=\K[^,]+'
}

get_node_interface() {
    echo "${nodes[$1]}" | grep -oP 'interface=\K[^,]+'
}

get_node_type() {
    echo "${nodes[$1]}" | grep -oP 'type=\K[^,]+'
}

get_node_labels() {
    echo "${nodes[$1]}" | grep -oP 'labels=\K[^,]*' | tr ',' ' '
}

get_node_auth() {
    echo "${nodes[$1]}" | grep -oP 'auth=\K[^,]*'
}

get_node_password() {
    echo "${nodes[$1]}" | grep -oP 'password=\K[^,]*'
}

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
mkdir -p ~/.kube
first_master=$(echo "${!nodes[@]}" | tr ' ' '\n' | grep "master" | head -n1)
k3sup install \
  --ip $(get_node_ip $first_master) \
  --user $(get_node_user $first_master) \
  --tls-san $vip \
  --cluster \
  --k3s-version $k3sVersion \
  --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$(get_node_interface $first_master) --node-ip=$(get_node_ip $first_master) --node-taint node-role.kubernetes.io/master=true:NoSchedule $common_extra_args $server_extra_args" \
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

# Function to set up passwordless sudo
setup_passwordless_sudo() {
    local node=$1
    local user=$(get_node_user $node)
    local ip=$(get_node_ip $node)
    local auth_method=$(get_node_auth $node)
    local password=$(get_node_password $node)

    echo "Setting up passwordless sudo for $user on $ip"
    
    if [ "$auth_method" == "password" ]; then
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no $user@$ip "echo '$password' | sudo -S sh -c 'echo \"$user ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/$user && chmod 0440 /etc/sudoers.d/$user'"
    else
        ssh -i $HOME/.ssh/$certName -o StrictHostKeyChecking=no $user@$ip "sudo sh -c 'echo \"$user ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/$user && chmod 0440 /etc/sudoers.d/$user'"
    fi
}

# Step 6: Add new master nodes (servers) & workers
for node in "${!nodes[@]}"; do
    setup_passwordless_sudo $node

    if [ "$(get_node_type $node)" == "master" ] && [ "$node" != "$first_master" ]; then
        k3sup join \
          --ip $(get_node_ip $node) \
          --user $(get_node_user $node) \
          --sudo \
          --k3s-version $k3sVersion \
          --server \
          --server-ip $(get_node_ip $first_master) \
          --ssh-key $HOME/.ssh/$certName \
          --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$(get_node_interface $node) --node-ip=$(get_node_ip $node) --node-taint node-role.kubernetes.io/master=true:NoSchedule $common_extra_args $server_extra_args" \
          --server-user $(get_node_user $first_master)
        echo -e " \033[32;5mMaster node $node joined successfully!\033[0m"
    elif [ "$(get_node_type $node)" == "worker" ]; then
        labels=$(get_node_labels $node)
        label_args=""
        if [ ! -z "$labels" ]; then
            label_args="--node-label \"$labels\""
        fi
        auth_method=$(get_node_auth $node)
        if [ "$auth_method" == "password" ]; then
            password=$(get_node_password $node)
            sshpass -p "$password" k3sup join \
              --ip $(get_node_ip $node) \
              --user $(get_node_user $node) \
              --sudo \
              --k3s-version $k3sVersion \
              --server-ip $(get_node_ip $first_master) \
              --k3s-extra-args "$label_args $common_extra_args $agent_extra_args" \
              --ssh-key $HOME/.ssh/$certName
        else
            k3sup join \
              --ip $(get_node_ip $node) \
              --user $(get_node_user $node) \
              --sudo \
              --k3s-version $k3sVersion \
              --server-ip $(get_node_ip $first_master) \
              --ssh-key $HOME/.ssh/$certName \
              --k3s-extra-args "$label_args $common_extra_args $agent_extra_args"
        fi
        echo -e " \033[32;5mWorker node $node joined successfully!\033[0m"
    fi
done

# Step 7: Install kube-vip as network LoadBalancer - Install the kube-vip Cloud Provider
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

# Step 8: Install Metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
# Download ipAddressPool and configure using lbrange above
curl -sO https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/ipAddressPool
cat ipAddressPool | sed 's/$lbrange/'$lbrange'/g' > ipAddressPool.yaml

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
--namespace longhorn-system

echo "Waiting for Longhorn UI deployment to be fully ready..."
while ! (kubectl wait --for=condition=available deployment/longhorn-driver-deployer -n longhorn-system --timeout=600s && \
         kubectl wait --for=condition=available deployment/longhorn-ui -n longhorn-system --timeout=600s && \
         kubectl wait --for=condition=available deployment/csi-attacher -n longhorn-system --timeout=600s && \
         kubectl wait --for=condition=available deployment/csi-provisioner -n longhorn-system --timeout=600s && \
         kubectl wait --for=condition=available deployment/csi-resizer -n longhorn-system --timeout=600s && \
         kubectl wait --for=condition=available deployment/csi-snapshotter -n longhorn-system --timeout=600s); do
    echo "Waiting for Longhorn UI deployment to be fully ready..."
    sleep 1
done

# Step 17: Print out confirmation

kubectl get nodes
kubectl get svc -n longhorn-system

echo -e " \033[32;5mHappy Kubing! Access Longhorn through Rancher UI\033[0m"

# Step 18: Download and modify values.yaml for Prometheus

# Ensure yq is installed
if ! command -v yq &> /dev/null; then
    echo "yq is not installed. Installing yq..."
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
fi

echo -e " \033[32;5mSetting up Prometheus...\033[0m"

# Download values.yaml
wget https://raw.githubusercontent.com/techno-tim/launchpad/master/kubernetes/kube-prometheus-stack/values.yml -O values.yaml

# Get master node IPs
master_ips=$(for node in "${!nodes[@]}"; do
    if [ "$(get_node_type $node)" == "master" ]; then
        echo "$(get_node_ip $node)"
    fi
done | sort -u)

echo '------'
echo 'Master IPs: ' 
echo $master_ips
echo '------'

# Function to update endpoints in values.yaml
update_endpoints() {
    local component=$1
    echo "Updating endpoints for $component"
    
    # Create the new endpoints content
    local new_endpoints=""
    for ip in $master_ips; do
        new_endpoints+="    - $ip\n"
    done
    
    # Use awk to replace the endpoints section
    awk -v component="$component" -v new_endpoints="$new_endpoints" '
    $0 ~ "^" component ":" { 
        print $0
        in_component = 1
        next
    }
    in_component && /^[a-z]/ { 
        in_component = 0 
    }
    in_component && /^ *endpoints:/ { 
        print "  endpoints:"
        print new_endpoints
        skip = 1
        next
    }
    skip && /^[^ ]/ { 
        skip = 0 
    }
    !skip { print }
    ' values.yaml > values.yaml.tmp && mv values.yaml.tmp values.yaml
    
    echo "Updated $component endpoints"
}

# Update endpoints for different components
components=("kubeControllerManager" "kubeEtcd" "kubeScheduler" "kubeProxy")
for component in "${components[@]}"; do
    update_endpoints "$component"
done

# Create Grafana admin credentials
echo -e " \033[32;5mCreating Grafana admin credentials...\033[0m"

# Create Kubernetes secret for Grafana
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin-credentials \
    --from-literal=admin-user=$grafana_user \
    --from-literal=admin-password=$grafana_password \
    -n monitoring \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e " \033[32;5mGrafana admin credentials created. Username: $grafana_user, Password: $grafana_password\033[0m"
echo -e " \033[32;5mPlease make note of these credentials and store them securely.\033[0m"

# Update Grafana admin credentials in values.yaml
yq eval '.grafana.admin.existingSecret = "grafana-admin-credentials"' -i values.yaml
yq eval '.grafana.admin.userKey = "admin-user"' -i values.yaml
yq eval '.grafana.admin.passwordKey = "admin-password"' -i values.yaml

# Verify the changes
for component in "${components[@]}"; do
    echo "Endpoints for ${component}:"
    yq eval ".${component}.endpoints" values.yaml
done

echo -e " \033[32;5mvalues.yaml has been updated with master node IPs\033[0m"

# Step 19: Install Prometheus using Helm
echo -e " \033[32;5mInstalling Prometheus...\033[0m"

# Add prometheus-community helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f values.yaml \
  --namespace monitoring \
  --create-namespace

# Wait for the Grafana deployment to be ready
kubectl -n monitoring rollout status deploy/grafana

echo "Changing Grafana service to LoadBalancer type..."
    kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

echo -e " \033[32;5mPrometheus has been installed!\033[0m"


# Show external ip on which to access grafana
kubectl get svc/grafana -n monitoring

echo -e " \033[32;5m Happy Charting! \033[0m"
