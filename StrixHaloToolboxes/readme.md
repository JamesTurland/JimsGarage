# AMD Strix Halo Toolboxes — Setup Notes

Tested on Ubuntu 24.04 LTS.

## System update
Run as root or prefix with sudo:
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

## Install AMD GPU packages (example: amdgpu/ROCm)
Download the installer (example version used here: 7.0.2):
```bash
wget https://repo.radeon.com/amdgpu-install/7.0.2/ubuntu/noble/amdgpu-install_7.0.2.70002-1_all.deb
sudo apt install ./amdgpu-install_7.0.2.70002-1_all.deb
sudo apt update
sudo apt install python3-setuptools python3-wheel
```

Add current user to render/video groups:
```bash
sudo usermod -a -G render,video $LOGNAME
```

Install ROCm:
```bash
sudo apt install rocm
```

Kernel extras and DKMS:
```bash
sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install amdgpu-dkms
sudo reboot
```

## Library path and ldconfig
Add ROCm libs to the loader path and refresh:
```bash
sudo tee /etc/ld.so.conf.d/rocm.conf <<'EOF'
/opt/rocm/lib
/opt/rocm/lib64
EOF
sudo ldconfig
```

You can also set LD_LIBRARY_PATH for the current session (or add to your shell profile):
```bash
export LD_LIBRARY_PATH=/opt/rocm-7.0.2/lib:$LD_LIBRARY_PATH
```

Verify installation:
```bash
apt list --installed | grep -E 'rocm|amdgpu'
rocminfo | grep -i 'Marketing Name:'
```

## Kernel / AMD TTM tuning
Edit GRUB:
```bash
sudo nano /etc/default/grub
# add or update GRUB_CMDLINE_LINUX_DEFAULT with required options, for example:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amdttm.pages_limit=33554432 amdgpu.gttsize=131072 amd_iommu=off"
sudo update-grub
sudo reboot
# verify:
sudo dmesg | grep -i 'amdgpu.*memory'
```

## Ubuntu Users
If you do not wish to run as root, create rule:
```bash
sudo nano /etc/udev/rules.d/99-amd-kfd.rules
```
Paste the following:
```bash
SUBSYSTEM=="kfd", GROUP="render", MODE="0666", OPTIONS+="last_rule"
SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0666", OPTIONS+="last_rule"
```

## Toolbox / Container workflow
Install Podman Toolbox if desired:
```bash
sudo apt-get install podman-toolbox
```

Clone the repo:
```bash
git clone https://github.com/kyuz0/amd-strix-halo-toolboxes.git
cd amd-strix-halo-toolboxes/toolboxes/
```

Create a toolbox container (example):
```bash
sudo toolbox create llama-rocm-7rc-rocwmma \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7rc-rocwmma \
  -- --device /dev/dri --device /dev/kfd \
     --group-add video --group-add render --group-add sudo \
     --security-opt seccomp=unconfined
```

Enter the toolbox:
```bash
toolbox enter llama-rocm-7rc-rocwmma
```

Inside the container you can list devices:
```bash
llama-cli --list-devices
```

Run a server example (adjust model name and flags as needed):
```bash
llama-server --no-mmap -ngl 999 -fa on --host 0.0.0.0 -hf unsloth/Qwen3-235B-A22B-Instruct-2507-GGUF:Q3_K_XL
```

## Notes
- Always check official AMD docs and AMD-Strix-Halo Repo for changes