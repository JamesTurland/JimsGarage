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
- **5 nodes by default** (3 servers + 2 agents). The minimum for HA is 3
  servers (etcd needs a quorum); workers are optional. Adjust the node list in
  the config block if you have fewer machines.
- Run the script from a **separate Ubuntu/Debian admin machine** (your
  laptop/workstation) that can SSH to every node — not on one of the nodes
  themselves. It installs `k3sup` and `kubectl` locally if missing.

## Important caveats

- **The VIP and the MetalLB range must be outside your DHCP pool**, and must
  not overlap each other or any node IP. If your router hands out `vip` or an
  address in `lbrange` via DHCP, you'll get intermittent, hard-to-debug
  failures — reserve them on your router/DHCP server first.
- **Same subnet / L2 only.** kube-vip (ARP mode) and MetalLB (L2) both
  advertise via ARP, so the VIP and LoadBalancer IPs must be on the **same
  subnet/VLAN** as the nodes and the clients reaching them — they are not
  routed across subnets.
- **`interface` must match your nodes' real NIC.** It's `eth0` on many
  systems but often `ens18`/`enp0s3` on Proxmox and cloud images. Check with
  `ip -o -4 route show default`.
- **Host keys are trusted on first use** (`accept-new`). If you re-image a
  node, clear its stale entry first: `ssh-keygen -R <node-ip>`.
- This is a **homelab tutorial, not production-hardened** as-is (aggressive
  leader election, no etcd backups, single L2 domain).

## Usage

1. Snapshot your VMs (so you can roll back — the script modifies every node).
2. Place your SSH **private** key at `~/<certName>` or `~/.ssh/<certName>`,
   with the matching `.pub` beside it. `certName` is the key's *filename only*
   — no path, no `.pub` suffix. Modern OpenSSH defaults to `id_ed25519`, so set
   `certName` to match the key you actually have.
3. Edit the **"YOU SHOULD ONLY NEED TO EDIT THIS SECTION"** block in
   `k3s.sh` — node IPs, `user`, `interface`, `vip`, `lbrange`, `certName`.
   The example IPs (`192.168.3.x`, VIP `.50`, range `.60-.80`) and
   `interface=eth0` are placeholders — change them for your network.
4. `chmod +x k3s.sh && ./k3s.sh`
5. Review the pre-flight summary and confirm. Grab a coffee.

### After it finishes

The kubeconfig is **merged** into `~/.kube/config` as context `k3s-ha` (set by
`context` in the config block), pointed at the VIP. Select it and check the
cluster:

```bash
kubectl config use-context k3s-ha
kubectl get nodes -o wide
curl http://<load-balancer-ip>   # the script prints the assigned IP
```

Worker nodes are labeled `worker=true` and `longhorn=true` (the latter for the
companion Longhorn storage tutorial — harmless if you don't use it).

If a node fails to join, reset just that node and re-run the script (it's
idempotent): `k3s-uninstall.sh` on a server, `k3s-agent-uninstall.sh` on a
worker.

### Options (environment variables)

| Variable         | Purpose                                               |
| ---------------- | ----------------------------------------------------- |
| `ASSUME_YES=1`   | Skip the pre-flight `[y/N]` prompt (unattended runs). |
| `NO_COLOR=1`     | Disable colored output.                               |
| `RAW_BASE=<url>` | Where to fetch the sibling manifests (kube-vip, ipAddressPool, l2Advertisement); default: upstream `main`. Override for a fork/branch/local copy. |

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
