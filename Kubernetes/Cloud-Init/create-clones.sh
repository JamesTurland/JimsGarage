#!/bin/bash

###########################
# DEFAULT VALUES          #
###########################
# Template VMID
template_id=5000
# Number of VMs to be created
vm_number=5
# The first VM id, smallest id is 100
id=1001
# Name prefix of the first VM
name=k3s

drive_name=local-zfs
disk_size=10G
custom_macs=()

##################
# Functions      #
##################
function run() {
    get_user_variables
    print_info # Prints information about what will be created based on defaults/user inputs
    setup      # Do not worry it asks for confirmation before the setup/installation starts
    start_vms  # You can choose to start all VMs if you want
}

function get_user_variables() {
    cnt=1
    while [ $cnt -eq 1 ] || [[ $(qm list | grep $template_id | cut -c 1-10 | xargs) != $template_id ]]; do
        if [ $cnt -gt 1 ]; then
            echo -e "\e[1;31mVM Template $template_id not found.\e[0m"
        fi
        echo -e "\e[36mWhich VMID template? (q to quit)\e[0m"
        read -e -p "" -i $template_id template_id
        if [ $template_id == "q" ]; then
            echo -e "\e[31mInstallation aborted by user. No changes were made.\e[0m"
            exit
        fi
        cnt+=1
    done
    echo -e "\e[36mHow many VM do you want to create? \e[0m"
    read -e -p "" -i "$vm_number" vm_number
    echo -e "\e[36mFirst VM ID? (minimum 100)\e[0m"
    read -e -p "" -i $id id
    echo -e "\e[36mVM name prefix? \e[0m"
    read -e -p "" -i $name name
    echo -e "\e[36mDisk Size? \e[0m"
    read -e -p "" -i $disk_size disk_size
    customize=n
    echo -e "\e[36mCustomize MAC addresses? \e[0m"
    read -e -p "" -i $customize customize
    case $customize in
    [Yy]*)
        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi
            # Get a random valid MAC address for PVE as a suggestion
            # tweaked from https://serverfault.com/questions/40712/what-range-of-mac-addresses-can-i-safely-use-for-my-virtual-machines#comment1485911_40720
            # loop until the proper length mac address is formed since /dev/urandom is a stream
            mac_start=$(cat /etc/pve/qemu-server/$template_id.conf | grep virtio | grep net | cut -c 14-22)
            mac=""
            until [[ ${#mac} == 17 ]]
            do
                mac="$mac_start$(od -vAn -N6 -tu1 < /dev/urandom | tr -d -c '[:digit:]A-F' | fold -w 12 | sed -E -n -e '/^.[26AE]/s/(..)/\1:/gp' | sed -e 's/:$//g')"
            done

            echo -n -e "  \e[46m$name-$idx\e[0m\e[36m MAC address:\e[0m "
            read -e -p "" -i $mac mac
            custom_macs+=($mac)
        done
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
        echo -n -e "\e[32mVM ID: $(($id + $i - 1)), Name: $name-$idx"
        case $customize in
        [Yy]*)
            echo -e ", MAC: ${custom_macs[$i-1]}\e[0m"
            ;;
        *)
            echo "\e[0m"
            ;;
        esac
    done
    echo -e "\e[32mDisk size:\e[0m" "$disk_size""B"
}

function setup() {
    yesno=n
    echo -e "\e[36mDo you want to proceed with the setup? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        create_vms
        ;;
    [Nn]*)
        echo -e "\e[31mInstallation aborted by user. No changes were made.\e[0m"
        exit
        ;;
    *) ;;
    esac
}

function create_vms() {
    for ((i = 1; i <= $vm_number; i++)); do
        # Create VM from the template
        if [[ $i -le 9 ]]; then
            idx="0$i"
        else
            idx=$i
        fi
        echo -e "\e[33mCreating Virtual Machine: $idx\e[0m"
        echo "VM ID: $(($id + $i - 1)), Name: $name-$idx, Cloning ID: $template_id"
        qm clone $template_id $(($id + $i - 1)) \
            --name $name-$idx \
            --full
        echo -e "\e[33mResizing disk to $disk_size...\e[0m"
        qm disk resize $(($id + $i - 1)) scsi0 $disk_size
        case $customize in
        [Yy]*)
            echo -e "\e[33mSetting MAC address to ${custom_macs[$i-1]}...\e[0m"
            oldMac=$(cat /etc/pve/qemu-server/$(($id + $i - 1)).conf | grep virtio | grep net | cut -c 14-30)
            sed -i "s/$oldMac/${custom_macs[$i-1]}/g" /etc/pve/qemu-server/$(($id + $i - 1)).conf
            ;;
        *) ;;
        esac

        print_vm_status
    done
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

        # Typically after the first cloud-init boot, there will be updates to apply
        # Wait 60s before offering
        echo -e "\e[33mWaiting for VMs to start...(60s)\e[0m"
        for ((i=60; i >- 0; i--)); do
            echo -e "\e[1A\e[K\e[33mWaiting for VMs to start...($i s)\e[0m"
            sleep 1
        done

        print_vm_status

        echo -e "\n\e[94;43;5mMake any needed updates to DHCP reservations now...\e[0m\n"

        restart_vms
        ;;
    [Nn]*)
        exit
        ;;
    *) ;;
    esac
}

function restart_vms() {
    yesno=n
    echo -e "\e[36mDo you want to restart the Virtual Machines now to apply updates? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi
            echo -e "\e[33mInitial reboot of Virtual Machine $idx to apply updates...\e[0m"
            qm reboot $(($id + $i - 1))
        done
        
        echo -e "\e[33mWaiting for VMs to restart...(30s)\e[0m"
        for ((i=30; i >- 0; i--)); do
            echo -e "\e[1A\e[K\e[33mWaiting for VMs to start...($i s)\e[0m"
            sleep 1
        done

        print_vm_status
        ;;
    [Nn]*)
        exit
        ;;
    *) ;;
    esac
}

function print_vm_status() {
        # Print VMs info
        echo -e "\n\n\e[95m   Virtual Machine  \e[0m|\e[35m    MAC Address    \e[0m|\e[35m  Status\e[0m"
        echo -e "-----------------------------------------------------"
        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi
            printf "%18.18s" "$name-$idx"
            echo -n "  | $(cat /etc/pve/qemu-server/$(($id + $i - 1)).conf | grep virtio | grep net | cut -c 14-30) |  "
            qm status $(($id + $i - 1)) | sed 's/status: //'
            echo -e "\n\n"
        done
}

#########################
# Run the script        #
#########################
run
