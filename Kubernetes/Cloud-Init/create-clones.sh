#!/bin/bash

###########################
# DEFAULT VALUES          #
###########################
# Template VMID
template_id=5000
# Number of VMs to be created
vm_number=3
# The first VM id, smallest id is 100
id=121
# Name prefix of the first VM
name=k3s

drive_name=local-zfs
disk_size=20G

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
    echo -e "\e[36mWhich VMID template? \e[0m"
    read -e -p "" -i $template_id template_id
    echo -e "\e[36mHow many VM do you want to create? \e[0m"
    read -e -p "" -i "$vm_number" vm_number
    echo -e "\e[36mFirst VM ID? (minimum 100)\e[0m"
    read -e -p "" -i $id id
    echo -e "\e[36mVM name prefix? \e[0m"
    read -e -p "" -i $name name
    echo -e "\e[36mDisk Size? \e[0m"
    read -e -p "" -i $disk_size disk_size
}

function print_info() {
    echo -e "\e[36m\nThe following Virtual Machines will be created:\e[0m"
    for ((i = 1; i <= $vm_number; i++)); do
        if [[ $i -le 9 ]]; then
            idx="0$i"
        else
            idx=$i
        fi
        echo -e "\e[32mVM ID: $(($id + $i - 1)), Name: $name-$idx\e[0m"
    done
    echo -e "\e[32mDisk size:\e[0m" "$disk_size""B"
}

function setup() {
    yesno=n
    echo -e "\e[36mDo you want to proceed with the setup? (y/n) \e[0m"
    read -e -p "" -i $yesno yesno
    case $yesno in
    [Yy]*)
        check_template
        create_vms
        ;;
    [Nn]*)
        echo -e "\e[31mInstallation aborted by user. No changes were made.\e[0m"
        exit
        ;;
    *) ;;
    esac
}

function check_template() {
    # Make sure our template exists
    if [[ $(qm list | grep $template_id | cut -c 1-10 | xargs) != $template_id ]]; then
        echo -e "\e[31mVM Template $template_id not found. Script aborted. No changes were made.\e[0m"
        exit 
    fi
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
        echo "VM ID: $(($id + $i - 1)), Name: $name-$idx, Clone Of: $template_id"
        qm clone $template_id $(($id + $i - 1)) \
            --name $name-$idx \
            --full
        echo -e "\e[33mResizing disk to $disk_size...\e[0m"
        qm disk resize $(($id + $i - 1)) scsi0 $disk_size
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
        # Wait 60s and reboot
        wait 60
        for ((i = 1; i <= $vm_number; i++)); do
            if [[ $i -le 9 ]]; then
                idx="0$i"
            else
                idx=$i
            fi
            echo -e "\e[33mInitial reboot of Virtual Machine $idx to apply updates...\e[0m"
            qm reboot $(($id + $i - 1))
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

#########################
# Run the script        #
#########################
run
