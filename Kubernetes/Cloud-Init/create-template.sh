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
# The first VM id, smallest id is 100
id=5000
# Name prefix of the first VM
name=cloud-template

drive_name=local-zfs
agent=1
disk_size=5G
memory=2048
socket=1
core=2

# IP for the first VM
ip=192.168.0.21
gateway=192.168.0.1

# ssh certificate name variable
cert_name=id_rsa

# User settings
user=$USER
password=password

ubuntu_url=http://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img
ubuntu_filename=jammy-server-cloudimg-amd64-disk-kvm.img

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
    yesno=y
    echo -e "\e[36mDo you want to add qemu agent to the VM images? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        echo "Agent will be installed."
        agent=1
        ;;
    *) 
        echo "Agent will not be installed."
        agent=0
        ;;
    esac
    echo -e "\e[36mVM Template ID? (minimum 100)\e[0m"
    read -e -p "" -i $id id
    echo -e "\e[36mVM name? \e[0m"
    read -e -p "" -i $name name
    echo -e "\e[36mDisk Size? \e[0m"
    read -e -p "" -i $disk_size disk_size
    echo -e "\e[36mMemory Size? \e[0m"
    read -e -p "" -i $memory memory
    echo -e "\e[36mNumber of cpu sockets? \e[0m"
    read -e -p "" -i $socket socket
    echo -e "\e[36mNumber of processor cores per socket? \e[0m"
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

function print_info() {
    echo -e "\e[36m\nThe following Virtual Machine Template will be created:\e[0m"
    echo -e "\e[32mVM ID: $id, Name: $name\e[0m"
    echo -e "\e[36m\nCommon VM parameters:\e[0m"
    echo -e "\e[32mOS cloud image:\e[0m" "$os"
    echo -e "\e[32mQEMU Agent:\e[0m" $yesno
    echo -e "\e[32mPublic Proxmox Certificate:\e[0m" "$cert_path/$cert_name.pub\n"
    echo -e "\e[32mDisk size:\e[0m" "$disk_size""B"
    echo -e "\e[32mMemory size:\e[0m" "$memory""GB"
    echo -e "\e[32mCPU sockets:\e[0m" "$socket"
    echo -e "\e[32mCPU cores per socket:\e[0m" "$core"
    echo -e "\e[32mDrive name:\e[0m" "$drive_name"
}

function setup() {
    yesno=n
    echo -e "\e[36mDo you want to proceed with the setup? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        get_os_image
        if [[ $agent == 1 ]]; then
            add_qemu_agent
        fi
        create_vms
        ;;
    [Nn]*)
        echo -e "\e[31mInstallation aborted by user. No changes were made.\e[0m"
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

function check_guestfs_tools() {
    REQUIRED_PKG="libguestfs-tools"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    echo -e "\e[33mChecking for $REQUIRED_PKG:\e[0m $PKG_OK"
    if [ "" = "$PKG_OK" ]; then
        echo "$REQUIRED_PKG not found. Setting up $REQUIRED_PKG"
        apt install $REQUIRED_PKG -y
    fi
}

function add_qemu_agent() {
    case $os in
    "Debian")
        os_url=$debian_url
        os_filename=$debian_filename
        cd $template_path/qcow
        os_newfilename=$(echo $os_filename | sed -E -e "s/\.qcow2/\-qemu\.qcow2/")
        ;;
    "Ubuntu")
        os_url=$ubuntu_url
        os_filename=$ubuntu_filename
        cd $template_path/iso
        os_newfilename=$(echo $os_filename | sed -E -e "s/\.img/\-qemu\.img/")
        ;;
    *)
        echo -e "\e[31Invalid option.\e[0m"
        ;;
    esac

    # Check if the os image file already exists.
    # If not then set it up
    if [ ! -f "$os_newfilename" ]; then
        echo -e "\e[33mAdding QEMU Guest Agent.\e[0m"
        check_guestfs_tools
        cp $os_filename $os_newfilename -f
        virt-customize -a $os_newfilename --install qemu-guest-agent
        $os_filename = $os_newfilename
    fi

}

# Only runs if you uncomment the function in `create_vms`. Please be careful
function destroy_existing_vms() {
    # Stop and destroy Virtual Machine if it already exists
    # TODO: Put confirmation before doing anything
    qm stop $id
    qm destroy $id --destroy-unreferenced-disks --purge
}

function create_vms() {
    # Stop and destroy Virtual Machine if it already exists.
    # Be really careful with this only uncomment if you know what are you doing. !!!
    #
    #  destroy_existing_vms
    #
    # #############################
    # Create VM from the cloud image
    echo -e "\e[33mCreating Virtual Machine:\e[0m"
    echo "VM ID: $id, Name: $name"
    qm create $id \
        --name $name \
        --cpu cputype=host \
        --socket $socket \
        --core $core \
        --numa 1 \
        --memory $memory \
        --balloon 0 \
        --net0 virtio,bridge=vmbr0 \
        --ipconfig0 ip=dhcp,ip6=dhcp \
        --cipassword $password \
        --ciuser $user \
        --ciupgrade 1 \
        --sshkeys $cert_path/$cert_name.pub \
        --agent=$agent


    echo -e "\e[33mImporting disk image.\e[0m"
    qm importdisk $id $os_filename $drive_name
    qm set $id --scsihw virtio-scsi-pci --scsi0 $drive_name:vm-$id-disk-0

    echo -e "\e[33mResizing disk\e[0m"
    qm disk resize $id scsi0 $disk_size

    echo -e "\e[33mImporting cloud image and setting boot parameters.\e[0m"
    qm set $id --ide2 $drive_name:cloudinit
    qm set $id --boot c --bootdisk scsi0

    echo -e "\e[33mConnecting serial VGA socket.\e[0m"
    qm set $id --serial0 socket --vga serial0

    echo -e "\e[33mConverting to template.\e[0m"
    qm template $id
}

#########################
# Run the script        #
#########################
run
