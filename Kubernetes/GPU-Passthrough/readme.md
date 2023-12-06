# Create directory
```
mkdir -p /etc/rancher/rke2
```
# Create File for RKE2 - Config
```
sudo nano /etc/rancher/rke2/config.yaml
```
# Add values
```
token: <ADD-TOKEN>
server: https://<ADD-VIP>:9345
node-label:
  - worker=true
  - longhorn=true
```
# Install RKE2
```
sudo su
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
```
# Enable RKE2
```
systemctl enable rke2-agent.service
systemctl start rke2-agent.service
```