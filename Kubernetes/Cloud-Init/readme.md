1. Download the ISO using the GUI (tested on https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64-disk-kvm.img)
1. Create the VM via CLI
```
qm create 5000 --memory 2048 --core 2 --name ubuntu-cloud --net0 virtio,bridge=vmbr0
cd var/lib/vz/template/iso/
qm importdisk 5000 lunar-server-cloudimg-amd64-disk-kvm.img nvme
qm set 5000 --scsihw virtio-scsi-pci --scsi0 nvme:vm-5000-disk-0
qm set 5000 --ide2 nvme:cloudinit
qm set 5000 --boot c --bootdisk scsi0
qm set 5000 --serial0 socket --vga serial0
```
1. Expand the VM disk size to a suitable size
1. Create the Cloud-Init template 
1. Deploy new VMs by clonding the template (full clone)
