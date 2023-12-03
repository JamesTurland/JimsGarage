1. Download the ISO using the GUI (tested on https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64-disk-kvm.img)
2. Create the VM via CLI
```bash
VMID=<TEMPLATE ID HERE>
STORAGE=<YOUR STORAGE HERE>

qm create $VMID --memory 2048 --balloon 0 --core 2 --name ubuntu-cloud --net0 virtio,bridge=vmbr0
cd /var/lib/vz/template/iso/
qm importdisk 5000 lunar-server-cloudimg-amd64-disk-kvm.img $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-$VMID-disk-0,discard=on,ssd=1
qm set $VMID --ide2 ${STORAGE}:cloudinit
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0
```
3. Expand the VM disk size to a suitable size (suggested 10 GB)
```bash
qm resize $VMID scsi0 10G
```
4. Head over to Proxmox UI > `VMID` > `Cloud-Init` section and set username, password, ssh keys and ip address configuration as desired.
5. Create the Cloud-Init template 
```bash
qm template $VMID
```
6. Deploy new VMs by cloning the template (full clone)
