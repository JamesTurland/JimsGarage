# Instructions
1. Create Longhorn volume
2. Mount longhorn volume to a node (recommend worker node)
3. Log into selected worker node
4. Create temporary folder for migration
> sudo mkdir /tmp/folder
5. List the disks to format
> sudo fdisk -l
6. Format the disk 
> sudo mkfs -t ext4 /dev/sdx
7. Mount the new disk to tmp folder
> sudo mount /dev/sdx /tmp/folder
8. Copy data from Docker Host to new drive (substitute your values below)
> sudo rsync -avxHAX username@DockerHostIP:/home/ubuntu/docker/some-directory/* /tmp/folder