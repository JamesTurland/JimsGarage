# IMPORTANT #
Make sure that you watch the video instructions carefully as you need to amend the files correctly.
YOU CANNOT JUST RUN THIS SCRIPT!
Incorrect use can result in you being locked out of Lets Encrypt for a period of time.

# NOTE FOR TRAEFIK v3 #
Many guides out there (including, until recently, this repo) reference an older version of the Kubernetes CRDs API group.
This older version is [deprecated](https://doc.traefik.io/traefik/master/migration/v2-to-v3/#kubernetes-crds-api-group-traefikcontainous) 
as of Traefik v3 (released [29 April 2024](https://github.com/traefik/traefik/releases/tag/v3.0.0)) and must be updated to the new version
in your IngressRoute, Middleware, ServersTransport, etc. yaml manifests for Traefik.  Any resources with the deprecated version will not 
be recognized by Traefik v3.

Old, deprecated version:
```yaml
apiVersion: traefik.containo.us/v1alpha1
```

New, supported version:
```yaml
apiVersion: traefik.io/v1alpha1
```
This new version is also supported in later releases of Traefik v2, so you can update your Traefik-related manifests 
to the new version and apply the updated manifests before upgrading your Traefik deployment.

It may be worth reviewing other v2 to v3 migration notes provided by Traefik: 
[Traefik v2 to v3 Migration](https://doc.traefik.io/traefik/master/migration/v2-to-v3/)
