#!/bin/bash

echo -e " \033[33;2m    __  _          _        ___                            \033[0m"
echo -e " \033[33;2m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;2m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;2m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;2m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;2m                                               |___/       \033[0m"
echo -e " \033[36;2m             Traefik, Cert-Manager, and PiHole            \033[0m"
echo -e " \033[32;2m                                                          \033[0m"
echo -e " \033[32;2m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;2m                                                           \033[0m"

# ENSURE THAT YOU COPY AND AMEND YOUR YAML FILES FIRST!!!
# THE SCRIPT EXPECTS THE FILES TO BE IN ~/Helm/Traefik/ & ~/Manifest/Crowdsec & ~/Manifest/PiHole etc
# RUN THIS SCRIPT FROM THE HOME DIRECTORY

# Script created from Official Documentation available at: https://cert-manager.io/docs/tutorials/acme/nginx-ingress/
# and https://github.com/traefik/traefik-helm-chart

# Step 0: Clone repository
DESTINATION=~/Helm/Traefik
if [ ! -d "`eval echo ${DESTINATION//>}`" ]; then
    sudo apt install unzip -y
    mkdir jimsgarage
    mkdir Helm
    mkdir Manifest
    curl -L -o master.zip https://github.com/JamesTurland/JimsGarage/archive/refs/heads/main.zip
    unzip master.zip -d ~/jimsgarage
    cp -r ~/jimsgarage/JimsGarage-main/Kubernetes/Traefik-PiHole/* ~/
    rm master.zip
    rm -r ~/jimsgarage
    echo -e " \033[32;5mRepo cloned - EDIT FILES!!!\033[0m"
    exit
else
    echo -e " \033[32;5mRepo already exists, continuing...\033[0m"
fi

# Step 1: Check dependencies
# Helm
if ! command -v helm version &> /dev/null
then
    echo -e " \033[31;5mHelm not found, installing\033[0m"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
else
    echo -e " \033[32;5mHelm already installed\033[0m"
fi
# Kubectl
if ! command -v kubectl version &> /dev/null
then
    echo -e " \033[31;5mKubectl not found, installing\033[0m"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo -e " \033[32;5mKubectl already installed\033[0m"
fi

# Step 2: Add Helm Repos
helm repo add traefik https://helm.traefik.io/traefik
helm repo add emberstack https://emberstack.github.io/helm-charts # required to share certs for CrowdSec
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update

# Step 3: Create Traefik namespace
kubectl create namespace traefik

# Step 4: Install Traefik
helm install --namespace=traefik traefik traefik/traefik -f ~/Helm/Traefik/values.yaml

# Step 5: Check Traefik deployment
kubectl get svc -n traefik
kubectl get pods -n traefik

# Step 6: Apply Middleware
kubectl apply -f ~/Helm/Traefik/default-headers.yaml

# Step 7: Create Secret for Traefik Dashboard
kubectl apply -f ~/Helm/Traefik/Dashboard/secret-dashboard.yaml

# Step 8: Apply Middleware
kubectl apply -f ~/Helm/Traefik/Dashboard/middleware.yaml

# Step 9: Apply Ingress to Access Service
kubectl apply -f ~/Helm/Traefik/Dashboard/ingress.yaml

# Step 10: Install Cert-Manager (should already have this with Rancher deployment)
# Check if we already have it by querying namespace
namespaceStatus=$(kubectl get ns cert-manager -o json | jq .status.phase -r)
if [ $namespaceStatus == "Active" ]
then
    echo -e " \033[32;5mCert-Manager already installed, upgrading with new values.yaml...\033[0m"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.crds.yaml
    helm upgrade \
    cert-manager \
    jetstack/cert-manager \
    --namespace cert-manager \
    --values ~/Helm/Traefik/Cert-Manager/values.yaml
else
    echo "Cert-Manager is not present, installing..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.13.2
fi

# Step 11: Apply secret for certificate (Cloudflare)
kubectl apply -f ~/Helm/Traefik/Cert-Manager/Issuers/secret-cf-token.yaml

# Step 12: Apply production certificate issuer (technically you should use the staging to test as per documentation)
kubectl apply -f ~/Helm/Traefik/Cert-Manager/Issuers/letsencrypt-production.yaml

# Step 13: Apply production certificate
kubectl apply -f ~/Helm/Traefik/Cert-Manager/Certificates/Production/jimsgarage-production.yaml

# Step 14: Create PiHole namespace
kubectl create namespace pihole

# Step 15: Deploy PiHole
kubectl apply -f ~/Manifest/PiHole

echo -e " \033[32;5mScript finished. Be sure to create PVC for PiHole in Longhorn UI\033[0m"
