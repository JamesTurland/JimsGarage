resource "proxmox_vm_qemu" "cloudinit-k3s-master" {
    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox-dell"
    desc = "Cloudinit Ubuntu"
    count = 3
    onboot = true

    # The template name to clone this vm from
    clone = "23.04-non-KVM"

    # Activate QEMU agent for this VM
    agent = 0

    os_type = "cloud-init"
    cores = 2
    sockets = 2
    numa = true
    vcpus = 0
    cpu = "host"
    memory = 4096
    name = "k3s-master-0${count.index + 1}"

    cloudinit_cdrom_storage = "nvme"
    scsihw   = "virtio-scsi-single" 
    bootdisk = "scsi0"

    disks {
        scsi {
            scsi0 {
                disk {
                  storage = "nvme"
                  size = 12
                }
            }
        }
    }

    # Setup the ip address using cloud-init.
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=192.168.3.10${count.index + 1}/24,gw=192.168.3.1"
    ciuser = "ubuntu"
    nameserver = "192.168.200.11"
    sshkeys = <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKfn+iQH2HnuXIa67zBzEUfrg4mfH9meVy/CWuzODj2G8K6xWXUx9YTzchqr2xjXxLDQcDC+RDwVY0cAiWZ/OrXd6H8QEkSSEuAc/exWvVmLQGr3e41Ff9BUslqayGEPwFP6fndCWK8FthiwYUUGM5sODLZl4DFcqtgICRzuEcNcRQZFpq/h5NzCYmdPWMrAuQLfF/fW2VRD5gnqaDkgW+pdw+1umut5ey6C4fCPA9/7vkSesDc2RafA3gRkBmO1IxBVhzgl7OLl84iFnl1dEUcrdSCoaRL2AHC36EDvhF5M/Zlv5hebITzc9f7cF88k/rsx2ZnlSOeIHD31/lRhWL root@proxmox-dell
    EOF
}

resource "proxmox_vm_qemu" "cloudinit-k3s-worker" {
    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox-dell"
    desc = "Cloudinit Ubuntu"
    count = 2
    onboot = true

    # The template name to clone this vm from
    clone = "23.04-non-KVM"

    # Activate QEMU agent for this VM
    agent = 0

    os_type = "cloud-init"
    cores = 2
    sockets = 2
    numa = true
    vcpus = 0
    cpu = "host"
    memory = 4096
    name = "k3s-worker-0${count.index + 1}"

    cloudinit_cdrom_storage = "nvme"
    scsihw   = "virtio-scsi-single" 
    bootdisk = "scsi0"

    disks {
        scsi {
            scsi0 {
                disk {
                  storage = "nvme"
                  size = 12
                }
            }
        }
    }

    # Setup the ip address using cloud-init.
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=192.168.3.11${count.index + 1}/24,gw=192.168.3.1"
    ciuser = "ubuntu"
    sshkeys = <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKfn+iQH2HnuXIa67zBzEUfrg4mfH9meVy/CWuzODj2G8K6xWXUx9YTzchqr2xjXxLDQcDC+RDwVY0cAiWZ/OrXd6H8QEkSSEuAc/exWvVmLQGr3e41Ff9BUslqayGEPwFP6fndCWK8FthiwYUUGM5sODLZl4DFcqtgICRzuEcNcRQZFpq/h5NzCYmdPWMrAuQLfF/fW2VRD5gnqaDkgW+pdw+1umut5ey6C4fCPA9/7vkSesDc2RafA3gRkBmO1IxBVhzgl7OLl84iFnl1dEUcrdSCoaRL2AHC36EDvhF5M/Zlv5hebITzc9f7cF88k/rsx2ZnlSOeIHD31/lRhWL root@proxmox-dell
    EOF
}