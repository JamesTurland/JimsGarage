
# Instructions Used In Video

  

## K3S

  

bootstrap first node:

    curl -sfL https://get.k3s.io | sh -

  

add agents:

    curl -sfL https://get.k3s.io | K3S_URL=https://myserver:6443 K3S_TOKEN=mynodetoken sh -

  

## Helm

    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
    
    chmod 700 get_helm.sh
    
    ./get_helm.sh

  

## Metallb

    helm repo add metallb https://metallb.github.io/metallb
    
    helm install metallb metallb/metallb

  

### then edit and apply the manifests:

  

    kubectl apply -f ....

  

## Authentik

create passwords:

  

    pwgen -s 50 1
    
    openssl rand 60 | base64 -w 0

  

 set values in values.yaml - see example

  

    nano values.yaml

  

deploy authentik:

  

    helm repo add authentik https://charts.goauthentik.io
    
    helm repo update
    
    helm upgrade --install authentik authentik/authentik -f values.yaml

  

edit for Traefik proxy using files

  

    kubectl apply -f ...
