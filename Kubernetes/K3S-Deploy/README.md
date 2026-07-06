# K3S HA Deploy (k3sup + kube-vip + MetalLB)

Deploys a highly-available k3s cluster over SSH with `k3sup`, a floating
control-plane VIP via **kube-vip**, and `type: LoadBalancer` support via
**MetalLB**.

> **Following the YouTube tutorial?** This script has been modernized since
> the video — see [What changed](#what-changed-from-the-video) below.

## What it builds

- A 3-server (control-plane) + 2-agent (worker) k3s cluster with embedded etcd.
- **kube-vip** advertises a single virtual IP for the Kubernetes API across
  all control-plane nodes (survives a node failure).
- **MetalLB** hands out real IPs to `type: LoadBalancer` services.

### Why both kube-vip and MetalLB?

They solve different problems. **kube-vip** provides the *control-plane* VIP
(one address for the API server, HA across masters). **MetalLB** provides
*service* load balancing (`type: LoadBalancer` for your apps). The older
kube-vip cloud-provider that overlapped MetalLB has been removed to avoid
duplicate LoadBalancer controllers.

## Prerequisites

- **Ubuntu/Debian** nodes (the script installs prerequisites with `apt`; on a
  non-apt distro it exits with a clear message).
- **Passwordless sudo** for the SSH user on every node. Example cloud-init:

  ```yaml
  #cloud-config
  users:
    - name: <your-user>
      sudo: ["ALL=(ALL) NOPASSWD:ALL"]
      groups: [sudo]
  ```

- An **SSH key pair** you can use to reach the nodes (the script distributes
  the public key and never clobbers your `~/.ssh/config`).
- At least **3 control-plane nodes** for real HA (etcd needs a quorum).
- Run the script from an **Ubuntu/Debian admin box** (it installs `k3sup`
  and `kubectl` locally if missing).

## Usage

1. Snapshot your VMs.
2. Copy your SSH key into your home directory (or into `~/.ssh`).
3. Edit the **"YOU SHOULD ONLY NEED TO EDIT THIS SECTION"** block in
   `k3s.sh` — node IPs, `user`, `interface`, `vip`, `lbrange`, `certName`.
4. `chmod +x k3s.sh && ./k3s.sh`
5. Review the pre-flight summary and confirm. Grab a coffee.

### Options (environment variables)

| Variable         | Purpose                                               |
| ---------------- | ----------------------------------------------------- |
| `ASSUME_YES=1`   | Skip the pre-flight `[y/N]` prompt (unattended runs). |
| `NO_COLOR=1`     | Disable colored output.                               |
| `RAW_BASE=<url>` | Base URL for the sibling manifests (default: `main`). |

### Tracking the latest k3s instead of a pinned version

In the config block set `k3sChannel="stable"` and leave `k3sVersion=""`.
The script then always installs the current stable k3s release.

### Upgrading kube-vip

The `kube-vip` manifest is generated from the pinned image (its env schema
changes between releases). To bump:

```bash
docker run --rm ghcr.io/kube-vip/kube-vip:<version> manifest daemonset \
  --interface eth0 --address 10.0.0.254 \
  --controlplane --arp --leaderElection --taint --inCluster > kube-vip
sed -i 's/value: eth0/value: REPLACE_INTERFACE/' kube-vip
sed -i 's/value: 10.0.0.254/value: REPLACE_VIP/' kube-vip

```

`--inCluster` is required on k3s: it makes kube-vip use the `kube-vip`
ServiceAccount (created by the RBAC the script applies) instead of the
kubeadm `/etc/kubernetes/admin.conf` kubeconfig, which does not exist on k3s.
Then update `KVVERSION` in `k3s.sh` to match.

## What changed from the video

- **Versions:** k3s `v1.35.6+k3s1`, kube-vip `v1.2.1`, MetalLB `v0.16.0`.
- **kube-vip** now runs on **all** control-plane nodes, and your kubeconfig
  points at the **VIP** (not master1) — fixes `localhost:8080`/API errors. A
  readiness check confirms the VIP is answering before the script continues.
- Removed the redundant kube-vip **cloud-provider**; MetalLB alone handles
  `type: LoadBalancer`.
- **MetalLB** installs from a single native manifest (which creates its own
  `metallb-system` namespace) — the old separate namespace apply and its
  mismatched MetalLB versions are gone.
- **k3sup:** the join token is fetched once and reused across all nodes, and
  `k3sup ready` waits for the cluster instead of a hand-rolled poll loop.
- **Safer SSH:** host keys are added via `ssh-keyscan`; the script no longer
  overwrites `~/.ssh/config`.
- **Hardening:** `set -euo pipefail`, per-node time sync, `apt` prerequisite
  install with a clear message on unsupported distros, arch-aware `kubectl`,
  and it is safe to re-run.
- **Cleaner output:** non-blinking step-by-step logging (only the banner
  still blinks — for old times' sake), a pre-flight config summary with a
  `[y/N]` confirmation (`ASSUME_YES=1` to skip), and a final summary listing
  the API VIP and the assigned LoadBalancer IP.
