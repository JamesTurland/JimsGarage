# Create directory
```
  mkdir -p /etc/rancher/rke2
```
# Create File for RKE2 - Config
```
  sudo touch /etc/rancher/rke2/config.yaml
  echo "token: <ADD-TOKEN>" >> /etc/rancher/rke2/config.yaml
  echo "server: https://<ADD-VIP>:9345" >> /etc/rancher/rke2/config.yaml
  echo "node-label:" >> /etc/rancher/rke2/config.yaml
  echo "  - worker=true" >> /etc/rancher/rke2/config.yaml
  echo "  - longhorn=true" >> /etc/rancher/rke2/config.yaml
```
# Install RKE2
```
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
```
# Enable RKE2
```
  systemctl enable rke2-agent.service
  systemctl start rke2-agent.service
```