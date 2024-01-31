#!/bin/bash

# for Debian this must be installed for Longhorn to work
# sudo apt-get install -y open-iscsi

###########################
# DEFAULT VALUES          #
###########################
os_options=("Debian" "Ubuntu")
os="Debian"
# Proxmox path to the template folder
template_path="/var/lib/vz/template"
# Proxmox certificate path
cert_path="/root/.ssh"
# Number of VMs to be created
vm_number=3
# The first VM id, smallest id is 100
id=121
# Name prefix of the first VM
name=k3s

drive_name=local-zfs
agent=0 # TODO: Implement User Option for it
disk_size=20G
memory=2048
core=2

# IP for the first VM
ip=192.168.0.21
gateway=192.168.0.1

# ssh certificate name variable
cert_name=id_rsa

# User settings
user=$USER
password=password

ubuntu_url=https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img
ubuntu_filename=lunar-server-cloudimg-amd64.img

debian_url=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
debian_filename=debian-12-genericcloud-amd64.qcow2

os_url=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
os_filename=debian-12-genericcloud-amd64.qcow2

##################
# Functions      #
##################
function run() {
    get_user_variables
    print_info # Prints information about what will be created based on defaults/user inputs
    setup      # Do not worry it asks for confirmation before the setup/installation starts
    start_vms  # You can choose to start all VMs if you want
    #qemu_agent # Not implemented yet, you can choose to add qemu-agent to the installation image
}

function get_user_variables() {
    echo -e -n "\e[36mWhich OS cloud image would you like to use?\n\e[0m"
    PS3=""
    select option in "${os_options[@]}"; do
        # Check if the user selected an option
        if [[ -n "$option" ]]; then
            # Do something with the selected option
            case $option in
            "Debian") ;;
            "Ubuntu") ;;
            *)
                echo -e "\e[31mInvalid option selected. Exiting...\e[0m"
                exit
                ;;
            esac
        else
            # No option was selected
            echo -e "\e[31mNo option was selected. Exiting...\e[0m"
            exit
        fi
        # Set the selected Operating system
        os=$option
        # Exit the select loop
        break
    done
    echo -e "\e[36mHow many VM do you want to create? \e[0m"
    read -e -p "" -i "$vm_number" vm_number
    echo -e "\e[36mFirst VM ID? (minimum 100)\e[0m"
    read -e -p "" -i $id id
    echo -e "\e[36mVM name prefix? \e[0m"
    read -e -p "" -i $name name
    echo -e "\e[36mIP address? \e[0m"
    read -e -p "" -i $ip ip

    # Split the IP address into its parts using the '.' character as the delimiter.
    ip_address_parts=(${ip//./ })
    octet1=${ip_address_parts[0]}
    octet2=${ip_address_parts[1]}
    octet3=${ip_address_parts[2]}
    octet4=${ip_address_parts[3]}

    echo -e "\e[36mGateway? \e[0m"
    read -e -p "" -i $gateway gateway
    echo -e "\e[36mDisk Size? \e[0m"
    read -e -p "" -i $disk_size disk_size
    echo -e "\e[36mMemory Size? \e[0m"
    read -e -p "" -i $memory memory
    echo -e "\e[36mNumber of processor cores? \e[0m"
    read -e -p "" -i $core core
    echo -e "\e[36mUser name? \e[0m"
    read -e -p "" -i $user user
    echo -e "\e[36mUser password? \e[0m"
    read -e -p "" -i $password password
    echo -e "\e[36mCertification name? \e[0m"
    read -e -p "" -i $cert_name cert_name
    echo -e "\e[36mDrive name to store images? \e[0m"
    read -e -p "" -i $drive_name drive_name
}

#
function qemu_agent() {
    yesno=n
    echo -e "\e[36mDo you want to add qemu agent to the VM images? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        # Install qemu agent packages for each VM
        echo -e "\e[32mInstalling qemu agent packages.\e[0m"

        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi

            # TODO: ssh into all VMs one by one and intalll the necessary qemu agent packages
        done
        ;;
    [Nn]*)
        echo -e "\e[33mSkipping qemu agent installation.\e[0m"
        ;;
    *) ;;
    esac
}

function print_info() {
    echo -e "\e[36m\nThe following Virtual Machines will be created:\e[0m"
    for ((i = 1; i <= $vm_number; i++)); do
        if [[ $i -le 9 ]]; then
            idx="0$i"
        else
            idx=$i
        fi
        echo -e "\e[32mVM ID: $(($id + $i - 1)), Name: $name-$idx, IP address: $octet1.$octet2.$octet3.$(($octet4 + $i - 1))\e[0m"
    done
    echo -e "\e[36m\nCommon VM parameters:\e[0m"
    echo -e "\e[32mOS cloud image:\e[0m" "$os"
    echo -e "\e[32mPublic Proxmox Certificate:\e[0m" "$cert_path/$cert_name.pub\n"
    echo -e "\e[32mGateway:\e[0m" "$gateway"
    echo -e "\e[32mDisk size:\e[0m" "$disk_size""B"
    echo -e "\e[32mMemory size:\e[0m" "$memory""GB"
    echo -e "\e[32mCPU cores:\e[0m" "$core"
    echo -e "\e[32mDrive name:\e[0m" "$drive_name"
}

function setup() {
    yesno=n
    echo -e "\e[36mDo you want to proceed with the setup? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        get_os_image
        create_vms
        ;;
    [Nn]*)
        echo -e "\e[31mInstallation aborted by user. No changes were made.\e[0m"
        exit
        ;;
    *) ;;
    esac
}

function start_vms() {
    yesno=n
    echo -e "\e[36mDo you want to start up the Virtual Machines now? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        # Start VMs
        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi
            echo -e "\e[33mStarting Virtual Machine $idx\e[0m"
            qm start $(($id + $i - 1))
        done
        # Print VMs statuses
        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi
            echo -e "\e[33mVirtual Machine $idx status: \e[0m"
            qm status $(($id + $i - 1))
        done
        ;;
    [Nn]*)
        exit
        ;;
    *) ;;
    esac
}

function get_os_image() {
    case $os in
    "Debian")
        os_url=$debian_url
        os_filename=$debian_filename
        # Check if the directory exists.
        if [ ! -d "$template_path/qcow" ]; then
            mkdir $template_path/qcow
        fi
        cd $template_path/qcow
        ;;
    "Ubuntu")
        os_url=$ubuntu_url
        os_filename=$ubuntu_filename
        # Check if the directory exists.
        if [ ! -d "$template_path/iso" ]; then
            mkdir $template_path/iso
        fi
        cd $template_path/iso
        ;;
    *)
        echo -e "\e[31Invalid option.\e[0m"
        ;;
    esac

    # Check if the os image file already exists.
    # If not then download it.
    if [ ! -f "$os_filename" ]; then
        # Download the selected os cloud image
        echo -e "\e[33mDownloading $os cloud image ...\e[0m"
        wget $os_url
    fi

}

# Only runs if you uncomment the function in `create_vms`. Please be careful
function destroy_existing_vms() {
    # Stop and destroy Virtual Machine if it already exists
    # TODO: Put loop and confirmation before doing anything
    qm stop $(($id + $i - 1))
    qm destroy $(($id + $i - 1)) --destroy-unreferenced-disks --purge
}

function create_vms() {
    for ((i = 1; i <= $vm_number; i++)); do
        # Stop and destroy Virtual Machine if it already exists.
        # Be really careful with this only uncomment if you know what are you doing. !!!
        #
        #  destroy_existing_vms
        #
        # #############################
        # Create VM from the cloud image
        if [[ $i -le 9 ]]; then
            idx="0$i"
        else
            idx=$i
        fi
        echo -e "\e[33mCreating Virtual Machine: $idx\e[0m"
        echo "VM ID: $(($id + $i - 1)), Name: $name-$idx, IP address: $octet1.$octet2.$octet3.$(($octet4 + $i - 1))"
        qm create $(($id + $i - 1)) \
            --memory $memory \
            --core $core \
            --numa 1 \
            --name $name-$idx \
            --net0 virtio,bridge=vmbr0 \
            --balloon 0 \
            --ipconfig0 gw=$gateway,ip=$octet1.$octet2.$octet3.$(($octet4 + $i - 1))/24 \
            --cipassword $password \
            --ciuser $user \
            --ciupgrade 1 \
            --sshkeys $cert_path/$cert_name.pub \
            --agent=$agent

        qm importdisk $(($id + $i - 1)) $os_filename $drive_name
        qm set $(($id + $i - 1)) --scsihw virtio-scsi-pci --scsi0 $drive_name:vm-$(($id + $i - 1))-disk-0
        qm disk resize $(($id + $i - 1)) scsi0 $disk_size
        qm set $(($id + $i - 1)) --ide2 $drive_name:cloudinit
        qm set $(($id + $i - 1)) --boot c --bootdisk scsi0
        qm set $(($id + $i - 1)) --serial0 socket --vga serial0
    done
}

#########################
# Run the script        #
#########################
run
