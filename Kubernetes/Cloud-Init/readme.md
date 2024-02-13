# Now Automated via Scripts
### 1. Create the Template with [create-template.sh](create-template.sh)
#### Parameters:
* Debian vs Ubuntu
* Automatically add the qemu-guest agent
* VM ID
* VM Name
* Final Disk size
* Memory size
* CPU sockets & cores/socket
* cloud image username/password
* cloud image public cert name
* storage location

Check script for setting paths to downloadable cloud images; currently set for _bookworm_ for Debian and _jammy_ for Ubuntu.
____
### 2. Clone the Template with [create-clones.sh](create-clones.sh)
#### Parameters:
* Template VM ID (script checks for validity)
* Number of clones to create
* First VM ID (uses sequential IDs)
* Final disk size
* Customize MAC Addresses for DHCP reservation

#### Features/Notes:
* If customizing MAC addresses, script will suggest same prefix as the template for random valid new addresses
* If starting up all VMs
    * Script will wait 60s to allow for full boot time & auto-updates
        * __Note:__ if your internet connection is slower, you may want to increase this wait time (lines 168-169) to allow for downloads
    * After wait time, script will suggest reboots on all VMs for updates made
* Script prints all VM clone info and pauses between boots to allow for you to apply DHCP reservations before next boot
