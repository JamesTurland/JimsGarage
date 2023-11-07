# Instructions
1. Create Longhorn volume
1. Mount longhorn volume to a node (recommend worker node)
1. Log into selected worker node
1. Create temporary folder for migration
sudo mkdir /tmp/folder
1. List the disks to format
sudo fdisk -l
1. Format the disk 
sudo mkfs -t ext4 /dev/sdx
1. Mount the new disk to tmp folder
sudo mount /dev/sdx /tmp/folder
1. Copy data from Docker Host to new drive (substitute your values below)
sudo rsync -avxHAX username@DockerHostIP:/home/ubuntu/docker/some-directory/* /tmp/folder