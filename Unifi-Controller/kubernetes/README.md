# Deployment

You can't just deploy the whole folder. You have to apply the files in the following order:

1. Create the namespace and the secrets using ´kubectl apply -f namespaceAndSecret.yaml ´
2. Apply the init-script using ´kubectl create configmap create-db-configmap --from-file=init-mongo.js --namespace unifi-controller´
3. Create two persistent volumes and two persistent volume claims in Longhorn

- unifi-db
- unifi-config

4. Deploy the pod and the service using ´kubectl apply -f deployment.yaml ´
5. If you want to access the GUI via Traefik you can add an ingress using ´kubectl apply -f ingress.yaml ´
6. Check if the MongoDB Container is running and delete the configmap ´create-db-configmap´ for security reasons
