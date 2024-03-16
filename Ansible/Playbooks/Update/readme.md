# Add to Hosts File (change ansible_user if required)
```
[all:vars]
ansible_user='ubuntu'
ansible_become=yes
ansible_become_method=sudo
```