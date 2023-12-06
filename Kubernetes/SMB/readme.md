# Install CSI driver
```
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/v1.13.0/deploy/install-driver.sh | bash -s v1.13.0 --
```

# Create SMB creds
```
kubectl create secret generic smbcreds --from-literal username=USERNAME --from-literal password="PASSWORD"
```

# Create storage class
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: smb
provisioner: smb.csi.k8s.io
parameters:
  source: //smb-server.default.svc.cluster.local/share
  # if csi.storage.k8s.io/provisioner-secret is provided, will create a sub directory
  # with PV name under source
  csi.storage.k8s.io/provisioner-secret-name: smbcreds
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: smbcreds
  csi.storage.k8s.io/node-stage-secret-namespace: default
reclaimPolicy: Delete  # available values: Delete, Retain
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1001
  - gid=1001
```