#!/usr/bin/env bash
#
# JimsGarage — K3S HA deploy (k3sup + kube-vip + MetalLB)
# Tutorial: https://youtube.com/@jims-garage
# See ./README.md for prerequisites, configuration, and what changed
# from the original video.

set -euo pipefail

# ── Banner (kept from the original tutorial; blink preserved) ──────────
echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"
echo -e " \033[36;5m         _  _________   ___         _        _ _           \033[0m"
echo -e " \033[36;5m        | |/ |__ / __| |_ _|_ _  __| |_ __ _| | |          \033[0m"
echo -e " \033[36;5m        | ' < |_ \__ \  | || ' \(_-|  _/ _\` | | |          \033[0m"
echo -e " \033[36;5m        |_|\_|___|___/ |___|_||_/__/\__\__,_|_|_|          \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"

# ── Output helpers (non-blinking; auto-disable when not a TTY) ──────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  c_reset=$'\033[0m'; c_step=$'\033[1;36m'; c_info=$'\033[36m'
  c_ok=$'\033[32m';   c_warn=$'\033[33m';   c_err=$'\033[31m'
else
  c_reset=; c_step=; c_info=; c_ok=; c_warn=; c_err=
fi
step() { printf '\n%s━━━ %s ━━━%s\n' "$c_step" "$*" "$c_reset"; }
info() { printf ' %s•%s %s\n'  "$c_info" "$c_reset" "$*"; }
ok()   { printf ' %s✓%s %s\n'  "$c_ok"   "$c_reset" "$*"; }
warn() { printf ' %s!%s %s\n'  "$c_warn" "$c_reset" "$*" >&2; }
err()  { printf ' %s✗%s %s\n'  "$c_err"  "$c_reset" "$*" >&2; }
die()  { err "$*"; exit 1; }

#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# k3s version to install. To always track the latest stable release
# instead, set k3sChannel="stable" and leave k3sVersion empty (see README).
k3sVersion="v1.35.6+k3s1"
k3sChannel=""

# kube-vip: must match the image tag baked into the ./kube-vip manifest.
# To bump, regenerate ./kube-vip (see README "Upgrading kube-vip").
KVVERSION="v1.2.1"

# MetalLB version (used to build the manifest URL).
METALLB_VERSION="v0.16.0"

# Node IP addresses
master1=192.168.3.21
master2=192.168.3.22
master3=192.168.3.23
worker1=192.168.3.24
worker2=192.168.3.25

# SSH user on the remote nodes
user=ubuntu

# Network interface used on the remote nodes
interface=eth0

# Virtual IP (VIP) for the HA control plane
vip=192.168.3.50

# MetalLB LoadBalancer address range
lbrange=192.168.3.60-192.168.3.80

# SSH private key name (in ~/.ssh) used to reach the nodes
certName=id_rsa

# kubeconfig context name to create locally
context=k3s-ha

#############################################
#            DO NOT EDIT BELOW              #
#############################################

# Additional control-plane servers joined after master1
masters=("$master2" "$master3")
# Agent (worker) nodes
workers=("$worker1" "$worker2")
# All control-plane nodes (kube-vip manifest is placed on each)
masters_all=("$master1" "${masters[@]}")
# Every node (for SSH prep loops)
all=("$master1" "${masters[@]}" "${workers[@]}")

# Base URL for the sibling manifests (kube-vip, ipAddressPool,
# l2Advertisement). Override to test from a branch/fork/local copy, e.g.
#   RAW_BASE="file://$HOME/JimsGarage"
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/JamesTurland/JimsGarage/main}"
manifest_base="$RAW_BASE/Kubernetes/K3S-Deploy"

ssh_key="$HOME/.ssh/$certName"
ssh_opts=(-i "$ssh_key" -o StrictHostKeyChecking=accept-new)

# k3s version selector: prefer an explicit version, else a channel.
if [[ -n "$k3sVersion" ]]; then
  k3s_selector=(--k3s-version "$k3sVersion"); k3s_display="$k3sVersion"
else
  k3s_selector=(--k3s-channel "${k3sChannel:-stable}"); k3s_display="channel:${k3sChannel:-stable}"
fi

# Control-plane k3s args: disable bundled traefik + servicelb (we use
# MetalLB), pin the flannel interface + node IP, taint as control-plane.
# Explicit --disable is kept (not k3sup --no-extras) for tutorial clarity.
server_extra_args() {  # $1 = node ip
  printf '%s' "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$1 --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule"
}

# ── Pre-flight: show config, confirm before touching any node ──────────
step "Pre-flight · review configuration"
printf '  %-16s %s\n' \
  "k3s:"           "$k3s_display" \
  "kube-vip:"      "$KVVERSION" \
  "metallb:"       "$METALLB_VERSION" \
  "control plane:" "${masters_all[*]}" \
  "workers:"       "${workers[*]}" \
  "api VIP:"       "$vip (interface $interface)" \
  "lb range:"      "$lbrange" \
  "ssh user/key:"  "$user / $ssh_key" \
  "kube context:"  "$context"
if [[ "${ASSUME_YES:-}" == "1" ]]; then
  info "ASSUME_YES=1 — proceeding without prompt"
else
  read -rp "$(printf '\n Proceed? [y/N] ')" reply || reply=""
  [[ "$reply" =~ ^[Yy]$ ]] || die "Aborted."
fi

# ── Step 1/9 · Local tools (k3sup, kubectl) ────────────────────────────
step "Step 1/9 · Local tools (k3sup, kubectl)"
if ! command -v k3sup &>/dev/null; then
  info "Installing k3sup"
  curl -sLS https://get.k3sup.dev | sh
  # The installer leaves the binary in the CWD — named "k3sup", or
  # "k3sup-<arch>" when run unprivileged (it can't self-install to
  # /usr/local/bin). Install whichever it produced.
  k3sup_bin=""
  for f in k3sup k3sup-*; do
    [[ -f "$f" ]] && { k3sup_bin="$f"; break; }
  done
  [[ -n "$k3sup_bin" ]] || die "k3sup installer produced no binary"
  sudo install "$k3sup_bin" /usr/local/bin/k3sup
  rm -f k3sup k3sup-*
else
  ok "k3sup present"
fi
if ! command -v kubectl &>/dev/null; then
  info "Installing kubectl"
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "$arch" in
    amd64|x86_64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) die "Unsupported architecture for kubectl: $arch" ;;
  esac
  kver="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -LO "https://dl.k8s.io/release/${kver}/bin/linux/${arch}/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
  ok "kubectl present"
fi

# ── Step 2/9 · SSH keys and known_hosts ────────────────────────────────
step "Step 2/9 · SSH keys and known_hosts"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
# If the key was dropped in $HOME (per the README), move it into ~/.ssh.
if [[ -f "$HOME/$certName" && ! -f "$ssh_key" ]]; then
  info "Moving $certName into ~/.ssh"
  cp "$HOME/$certName" "$ssh_key"
  [[ -f "$HOME/$certName.pub" ]] && cp "$HOME/$certName.pub" "$ssh_key.pub"
fi
[[ -f "$ssh_key" ]] || die "SSH key not found: $ssh_key (see README prerequisites)"
chmod 600 "$ssh_key"; [[ -f "$ssh_key.pub" ]] && chmod 644 "$ssh_key.pub"
# Trust host keys without clobbering ~/.ssh/config (issue #62).
for node in "${all[@]}"; do
  ssh-keyscan "$node" 2>/dev/null >> "$HOME/.ssh/known_hosts" || \
    warn "ssh-keyscan failed for $node (will accept-new on first connect)"
done
[[ -f "$HOME/.ssh/known_hosts" ]] && sort -u "$HOME/.ssh/known_hosts" -o "$HOME/.ssh/known_hosts"
# Distribute the public key to each node.
for node in "${all[@]}"; do
  info "Copying SSH key to $user@$node"
  ssh-copy-id -i "$ssh_key.pub" -o StrictHostKeyChecking=accept-new "$user@$node" >/dev/null 2>&1 || \
    warn "ssh-copy-id to $node failed (key may already be present)"
done
ok "SSH ready for ${#all[@]} nodes"

# ── Step 3/9 · Prepare nodes (time sync + prerequisites) ───────────────
step "Step 3/9 · Prepare nodes (time sync + prerequisites)"
for node in "${all[@]}"; do
  info "Preparing $node"
  rc=0
  ssh "${ssh_opts[@]}" "$user@$node" 'sudo bash -s' <<'REMOTE' || rc=$?
set -e
# Resync time — VM snapshots drift, which breaks k3s/k3sup installs (issue #68).
timedatectl set-ntp off || true
timedatectl set-ntp on  || true
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
  ok=0
  for i in $(seq 1 10); do
    if apt-get update && apt-get install -y iptables sudo policycoreutils; then ok=1; break; fi
    echo "apt busy, retry $i/10..."; sleep 3
  done
  [ "$ok" = 1 ] || exit 91
else
  exit 90
fi
REMOTE
  case "$rc" in
    0)  ok "$node prepared" ;;
    90) die "Node $node is not apt-based. This script targets Ubuntu/Debian; install iptables, sudo, and policycoreutils manually (see README)." ;;
    91) die "Node $node: apt failed after retries." ;;
    *)  die "Node $node: preparation failed (exit $rc)." ;;
  esac
done

# ── Step 4/9 · Bootstrap first control-plane node ──────────────────────
step "Step 4/9 · Bootstrap first control-plane node ($master1)"
mkdir -p "$HOME/.kube"
k3sup install \
  --ip "$master1" \
  --user "$user" \
  --sudo \
  --tls-san "$vip" \
  --cluster \
  "${k3s_selector[@]}" \
  --k3s-extra-args "$(server_extra_args "$master1")" \
  --merge \
  --local-path "$HOME/.kube/config" \
  --ssh-key "$ssh_key" \
  --context "$context"
ok "First node bootstrapped"

# ── Step 5/9 · Install kube-vip (control-plane VIP) ────────────────────
step "Step 5/9 · Install kube-vip (control-plane VIP)"
# Ensure kubectl targets the cluster we just created (the merge above may
# have left a different current-context in a pre-existing ~/.kube/config).
kubectl config use-context "$context" >/dev/null
info "Applying kube-vip RBAC"
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml
info "Rendering kube-vip manifest (interface=$interface, vip=$vip)"
curl -sfL "$manifest_base/kube-vip" -o "$HOME/kube-vip.src"
sed "s/REPLACE_INTERFACE/$interface/g; s/REPLACE_VIP/$vip/g" \
  "$HOME/kube-vip.src" > "$HOME/kube-vip.yaml"
for node in "${masters_all[@]}"; do
  info "Placing kube-vip manifest on $node"
  # scp to /tmp (absolute) — the mv below runs as root, where ~ is /root,
  # not the ssh user's home where scp would otherwise land the file.
  scp "${ssh_opts[@]}" "$HOME/kube-vip.yaml" "$user@$node:/tmp/kube-vip.yaml" >/dev/null
  ssh "${ssh_opts[@]}" "$user@$node" 'sudo bash -s' <<'REMOTE'
set -e
mkdir -p /var/lib/rancher/k3s/server/manifests
mv /tmp/kube-vip.yaml /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
chown root:root /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
chmod 600 /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
REMOTE
done
ok "kube-vip deployed to ${#masters_all[@]} control-plane nodes"
info "Pointing local kubeconfig at the VIP ($vip)"
# Rewrite only the server URL (anchored) to avoid the regex dots in the IP
# matching anything else in the kubeconfig (e.g. base64 cert data).
sed -i "s#https://$master1:6443#https://$vip:6443#" "$HOME/.kube/config"

# Confirm the VIP is actually answering before any VIP-routed kubectl below.
# This is an early tripwire for a broken kube-vip (wrong interface, RBAC, etc.)
# instead of a confusing failure further down.
info "Waiting for the control-plane VIP ($vip) to answer"
vip_ready=""
for _ in $(seq 1 30); do
  if kubectl --request-timeout=5s get --raw='/readyz' &>/dev/null; then
    vip_ready=1; break
  fi
  sleep 2
done
[[ -n "$vip_ready" ]] || die "Control-plane VIP $vip is not answering — check kube-vip on the masters: kubectl -n kube-system logs -l app.kubernetes.io/name=kube-vip-ds"
ok "Control-plane VIP is answering"

# ── Step 6/9 · Fetch the cluster join token ────────────────────────────
step "Step 6/9 · Fetch the cluster join token"
node_token="$(k3sup node-token --ip "$master1" --user "$user" --ssh-key "$ssh_key")" \
  || die "Failed to fetch node token from $master1"
[[ -n "$node_token" ]] || die "Empty node token from $master1"
ok "Join token fetched"

# ── Step 7/9 · Join control-plane and worker nodes ─────────────────────
step "Step 7/9 · Join control-plane and worker nodes"
for node in "${masters[@]}"; do
  info "Joining control-plane node $node"
  k3sup join \
    --ip "$node" \
    --user "$user" \
    --sudo \
    --server \
    --server-ip "$master1" \
    --server-user "$user" \
    --node-token "$node_token" \
    "${k3s_selector[@]}" \
    --k3s-extra-args "$(server_extra_args "$node")" \
    --ssh-key "$ssh_key"
  ok "Control-plane node $node joined"
done
for node in "${workers[@]}"; do
  info "Joining worker node $node"
  k3sup join \
    --ip "$node" \
    --user "$user" \
    --sudo \
    --server-ip "$master1" \
    --server-user "$user" \
    --node-token "$node_token" \
    "${k3s_selector[@]}" \
    --k3s-extra-args '--node-label longhorn=true --node-label worker=true' \
    --ssh-key "$ssh_key"
  ok "Worker node $node joined"
done

# ── Step 8/9 · Install MetalLB (service LoadBalancer) ──────────────────
step "Step 8/9 · Install MetalLB (service LoadBalancer)"
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$METALLB_VERSION/config/manifests/metallb-native.yaml"
info "Waiting for the MetalLB controller"
# rollout status waits on the Deployment (created synchronously by apply) and
# avoids the "no matching resources found" race that `wait --for=condition=ready
# pod` hits when the controller pod does not exist yet.
kubectl -n metallb-system rollout status deploy/controller --timeout=120s
info "Configuring address pool ($lbrange)"
curl -sfL "$manifest_base/ipAddressPool" -o "$HOME/ipAddressPool.src"
sed "s|REPLACE_LBRANGE|$lbrange|g" "$HOME/ipAddressPool.src" > "$HOME/ipAddressPool.yaml"
kubectl apply -f "$HOME/ipAddressPool.yaml"
curl -sfL "$manifest_base/l2Advertisement.yaml" -o "$HOME/l2Advertisement.yaml"
kubectl apply -f "$HOME/l2Advertisement.yaml"
ok "MetalLB configured"

# ── Step 9/9 · Verify cluster and LoadBalancer ─────────────────────────
step "Step 9/9 · Verify cluster and LoadBalancer"
info "Waiting for the cluster to be ready"
k3sup ready --context "$context" --kubeconfig "$HOME/.kube/config"
info "Deploying nginx sample"
kubectl apply -n default -f https://raw.githubusercontent.com/inlets/inlets-operator/master/contrib/nginx-sample-deployment.yaml
kubectl expose deployment nginx-1 --port=80 --type=LoadBalancer -n default
info "Waiting for the nginx deployment"
kubectl -n default rollout status deploy/nginx-1 --timeout=120s
info "Waiting for the LoadBalancer IP"
lb_ip=""
for _ in $(seq 1 30); do
  lb_ip="$(kubectl get svc nginx-1 -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [[ -n "$lb_ip" ]] && break
  sleep 2
done

kubectl get nodes -o wide || true
step "Done · cluster ready"
ready_nodes="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{c++} END{print c+0}')" || ready_nodes=0
ok "$ready_nodes nodes Ready · context '$context'"
ok "API server: https://$vip:6443"
if [[ -n "$lb_ip" ]]; then
  ok "nginx LoadBalancer IP: $lb_ip  (curl http://$lb_ip)"
else
  warn "nginx LoadBalancer IP not assigned yet — check: kubectl get svc -A"
fi
info "Next: kubectl get pods -A"
