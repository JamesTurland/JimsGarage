# Instructions
1. ```
    helm install \
    cert-manager jetstack/cert-manager \
    --create-namespace \
    --namespace cert-manager \
    --set installCRDs=true

    helm install \
    reflector emberstack/reflector \
    --create-namespace \
    --namespace reflector
    ```
2. ```
    helm upgrade \
    traefik traefik/traefik \
    --namespace traefik \
    -f traefik-values.yaml

    helm install \
    crowdsec crowdsec/crowdsec \
    --create-namespace \
    --namespace crowdsec \
    -f crowdsec-values.yaml
    ```