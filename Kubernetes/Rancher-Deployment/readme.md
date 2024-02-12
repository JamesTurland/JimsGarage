# Install helm
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```
# Add Rancher Helm Repository
```
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
```

# Install Cert-Manager
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
--namespace cert-manager \
--create-namespace \
--version v1.13.2
kubectl get pods --namespace cert-manager
```

# Install Rancher
```
helm install rancher rancher-latest/rancher \
 --namespace cattle-system \
 --set hostname=rancher.my.org \
 --set bootstrapPassword=admin
kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher
```

# Expose Rancher via Loadbalancer
```
kubectl get svc -n cattle-system
kubectl expose deployment rancher --name=rancher-lb --port=443 --type=LoadBalancer -n cattle-system
kubectl get svc -n cattle-system
```

# Go to Rancher GUI
Hit the url… and create your account
Be patient as it downloads and configures a number of pods in the background to support the UI (can be 5-10mins)

# Bonus: Accessing Rancher through Ingress (Traefik)
Do you want that precious green lock in your URL bar?  If you have Traefik (or another Kubernetes Ingress controller) 
deployed and a Let's Encrypt issuer with Cert-Manager, the Rancher Helm chart offers support to automatically configure 
an ingress route with TLS certificate injection to access the Rancher UI via the `rancher` Kubernetes Service created 
by the Helm install (`kubectl -n cattle-system get service`). This can be configured retroactively after your initial 
`helm install ...`, but is a bit simpler to set up as part of your initial Rancher installation if you have the 
prerequisites in place.

You first need to save the TLS certificate and key that you want Traefik to use for Rancher as a Kubernetes Secret
called `tls-rancher-ingress`.  You can do this manually, or let Cert-Manager generate a certificate for you and 
store it in a Secret, using `kubectl` to create a Kubernetes Certificate resource to generate the certificate and 
populate the Secret for you:
```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: rancher-my-org
  namespace: cattle-system
spec:
  commonName: rancher.my.org
  dnsNames:
    - rancher.my.org
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  secretName: tls-rancher-ingress
```
This can take anywhere from a few minutes to 15-20 minutes to generate, so sit tight.  You'll know it is ready when 
the certificate's `Ready` status shows `True` in the output of:
```bash
kubectl -n cattle-system get certificate rancher-my-org
```
While you're waiting, make sure that your DNS record for `rancher.my.org` points to your Traefik deployment, 
instead of a LoadBalancer IP from kubeVIP. 
This can be an CNAME record using your Traefik FQDN, or an A record using the same IP address as Traefik.

Once the certificate and DNS record are ready, you can run your Rancher installation with one extra value set to 
configure your Ingress provider to use your custom certificate:
```bash
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.my.org \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=secret
```
If you are doing this after already installing Rancher (with the default setting of `ingress.tls.source=rancher`), 
you can overwrite the self-generated `tls-rancher-ingress` secret with your own certificate, then update your 
deployment. You may want to get your current Rancher version using `helm ls -n cattle-system` and provide it 
in your `helm upgrade` command so you don't unexpectedly upgrade your Rancher version.
```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.my.org \
  --set ingress.tls.source=secret \
  --version <DEPLOYED_RANCHER_VERSION>
```
## Ingress TLS Troubleshooting
You can validate the contents of your `tls-rancher-ingress` Secret using commands like this:
```bash
kubectl -n cattle-system get secret tls-rancher-ingress -o jsonpath='{.data}' | jq '."tls.crt"' | tr -d '"' | base64 --decode | openssl x509 -text
```
If you previously had your `rancher.my.org` DNS record associated with your LoadBalancer IP, your browser may be caching
that old record.  You may need to clear your browser's DNS cache, use an Incognito/Private window, etc.

There are also helpful instructions covering a handful of situations in Rancher's documentation:
* [Adding TLS Secrets](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/resources/add-tls-secrets)
* [Update Rancher Certificate](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/resources/update-rancher-certificate)

