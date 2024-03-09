# Edit Hosts File
```
sudo nano /etc/ansible/hosts
```

# Fix SSH Key Permissions
```
chmod 600 ~/.ssh/ansible
```
# Ansible Ping Command
```
ansible all -m ping
```

# Create SSH Key
```
ssh-keygen -t ed25519 -C "ansible"
```

# Copy SSH Key
```
ssh-copy-id -i ~/.ssh/ansible.pub 192.168.200.50
```

# Ansible Ping Command With New SSH Key
```
ansible all -m ping --key-file ~/.ssh/ansible
```
