You are an autonomous systems engineering agent. Your objective is to deploy a complete homelab stack on an existing Ubuntu 26.04 VM running in Proxmox.

---

### ENVIRONMENT & ACCESS SPECIFICATIONS
- Target Host: 192.168.8.86 (Hostname: "Docker VM")
- SSH User: ubuntu
- SSH Private Key: ~/SSH (run `chmod 600 ~/SSH` before initiating SSH sessions)
- Base Variables File: ~/variables (read this file first to extract environment keys)
- Base Domain: jimsgarage.co.uk
- Stored Project Root: /home/ubuntu/docker-compose/<service>/docker-compose.yml
- Bind Mounts Root: /home/ubuntu/docker/<service>/
- Internal Docker Network: `proxy` (bridge driver, subnet: 172.28.0.0/16)

---

### EXECUTION RULES & SAFETY CONSTRAINTS
1. Run all commands remotely over SSH or via structured command execution.
2. Read `~/variables` before proceeding. Extract:
   - `VAULTWARDEN_USER`, `VAULTWARDEN_MASTERKEY`
   - `CF_API_EMAIL`, `CF_DNS_API_TOKEN`, `CF_API_KEY`
   - `LLM_IP`
   - `MATRIX_USER`
   - `GOTIFY_USER`
   - `TIMEZONE`
3. Generate all passwords using: `pwgen -s 30 1`.
4. Stage all generated credentials to `/tmp/credentials_staging.env` (permissions `0600`) until Vaultwarden is fully functional. Once Vaultwarden is running, install the Bitwarden CLI (`bw`), log in, create the vault items, and securely shred the temporary file.
5. Every compose stack must be isolated in `/home/ubuntu/docker-compose/<service>/docker-compose.yml` with container state directories in `/home/ubuntu/docker/<service>/`.
6. Visit the link provided for each container. It provides the latest configuration guides and docker compose files.
7. Use the latest versions of containers where possible.
8. If an app supports OAuth, integrate it with Authentik.
9. Always use official documentation where possible, do not invent a solution if an official one exists.
10. Add containers to homepage, configure widgets if available.
11. Check for existing n8n automations to expedite actions.

---

### PHASE 1: HOST PREPARATION & DOCKER ENGINE
1. Connect via SSH using `~/SSH` to `ubuntu@192.168.8.86`.
2. Disable `systemd-resolved` stub listener to free host port 53 for Technitium:
   - Edit `/etc/systemd/resolved.conf`: set `DNSStubListener=no`.
   - Symlink `/run/systemd/resolve/resolv.conf` to `/etc/resolv.conf`.
   - Restart `systemd-resolved`.
3. Install Docker Engine, Docker Compose plugin, `pwgen`, `jq`, `curl`, and `nodejs`/`npm` (for `bw` CLI).
4. Ensure user `ubuntu` belongs to the `docker` and `video`/`render` groups (for Jellyfin iGPU passthrough). Verify `/dev/dri` exists on the host.
5. Create the shared ingress network:
   `docker network create --subnet=172.28.0.0/16 proxy || true`
6. Set `TIMEZONE` for all containers that support it.

---

### PHASE 2: CORE INGRESS, SECRETS & DNS

#### 1. Vaultwarden
- Documentation: follow instructions at: https://github.com/dani-garcia/vaultwarden
- URL: `vaultwarden.jimsgarage.co.uk`
- Direct Compose Path: `/home/ubuntu/docker-compose/vaultwarden/docker-compose.yml`
- Data Path: `/home/ubuntu/docker/vaultwarden/data`
- Environment: Set `SIGNUPS_ALLOWED=true` initially, `ADMIN_TOKEN=<generated_admin_key>`.
- Verification: Deploy, test HTTP response, programmatically create the account matching `VAULTWARDEN_USER` and `VAULTWARDEN_MASTERKEY`. 
- Post-Setup: Install `bw` CLI, login, unlock, and sync all passwords generated throughout this deployment.

#### 2. Traefik v3 & CrowdSec Bouncer
- Traefik documentation: follow instructions at: https://doc.traefik.io/traefik/setup/docker/
- URLs: 
  - Dashboard: `traefik-dashboard.jimsgarage.co.uk`
- Dynamic Config Path: `/home/ubuntu/docker/traefik/dynamic/`
- Let's Encrypt: Wildcard cert for `*.jimsgarage.co.uk` via Cloudflare DNS-01 challenge.
  - Documentation at: https://go-acme.github.io/lego/dns/
  - Determine whether the Cloudflare secret is a scoped token or global key, and assign `CF_DNS_API_TOKEN` or `CF_API_EMAIL` + `CF_API_KEY` accordingly.
- CrowdSec Integration:
  - Documentation at: https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin
  - Add CrowdSec Traefik Bouncer plugin via Traefik static configuration.
  - BasicAuth for Traefik Dashboard: Generate credentials using `htpasswd`, save password to `/tmp/credentials_staging.env` under `traefik-dashboard.jimsgarage.co.uk`.

#### 3. Technitium DNS (Cluster)
- Documentation: Follow https://github.com/TechnitiumSoftware/DnsServer/blob/master/docker-compose.yml
- Cluster documentation: https://blog.technitium.com/2025/11/understanding-clustering-and-how-to.html
- URL: `technitium.jimsgarage.co.uk`
- Node 1: Expose host ports `53:53/udp`, `53:53/tcp`, and Web UI on `5380:5380`.
- Node 2: Bind to secondary port/IP (e.g., Web UI `5381:5380`, DNS port `5353:53/udp`) or secondary IP alias on `eth0` to prevent port collision on `192.168.8.86`.
- Configuration: Initialize cluster pairing between Node 1 and Node 2. Configure zone `jimsgarage.co.uk` pointing subdomains to `192.168.8.86`. Use the option to ignore the TLS certificate validation errors while performing the joining process.

---

### PHASE 3: NOTIFICATIONS & MONITORING

#### 1. Gotify
- Documentation: Follow https://gotify.net/docs/install
- URL: `gotify.jimsgarage.co.uk`
- Create user `GOTIFY_USER` with a generated 30-character password.
- Generate application tokens for: `CrowdSec`, `Uptime-Kuma`.

#### 2. CrowdSec Engine
- Mount auth logs and Traefik access logs.
- Configure Gotify notification plugin (`/etc/crowdsec/notifications/gotify.yaml`) using the Gotify application token.
- Generate CrowdSec LAPI bouncer key and link it to Traefik’s bouncer middleware.

#### 3. Uptime Kuma
- Documentation: Follow https://github.com/louislam/uptime-kuma
- URL: `uptime-kuma.jimsgarage.co.uk`
- Configure auto-monitoring for all deployed subdomains.
- Set up Gotify as the default notification channel.

---

### PHASE 4: APPLICATION SUITE

Deploy the following containers in separate directories under `/home/ubuntu/docker-compose/<service>/`. Connect each web interface to the `proxy` network with appropriate Traefik router and service labels:

| Service | Documentation | Subdomain | Special Requirements |
| :--- | :--- | :--- |
| **Portainer CE** | https://docs.portainer.io/start/install-ce/server/docker/linux | `portainer.jimsgarage.co.uk` | Mount `/var/run/docker.sock`. Create admin user and generated password. |
| **Home Assistant** | https://www.home-assistant.io/installation/linux#docker-compose | `ha.jimsgarage.co.uk` | In `configuration.yaml`, append: <br>`http:`<br>`  use_x_forwarded_for: true`<br>`  trusted_proxies: [172.28.0.0/16]` |
| **Jellyfin** | https://jellyfin.org/docs/general/installation/container | `jellyfin.jimsgarage.co.uk` | Passthrough `/dev/dri` device nodes. Map permissions for hardware encoding. |
| **Immich** | https://docs.immich.app/install/docker-compose/ | `immich.jimsgarage.co.uk` | Official multi-container stack (server, machine-learning, redis, postgres with pgvector). Generate secure DB credentials. |
| **Halogen Dashboard** | https://github.com/Quat3rnion/halogen-dashboard/blob/main/docker-compose.yml | `halogen-dashboard.jimsgarage.co.uk` | Connect to backend target at `LLM_IP` sourced from `~/variables`. |
| **Homepage** | https://gethomepage.dev/installation/docker/ | `homepage.jimsgarage.co.uk` | Mount `/var/run/docker.sock:ro`. Configure `services.yaml` and `widgets.yaml` with API tokens from Portainer, Gotify, and Uptime Kuma. |

---

### PHASE 5: MATRIX SYNAPSE & AGENT INTEGRATION
- Documentation: available at: https://hub.docker.com/r/matrixdotorg/synapse
- Base URL: `matrix.jimsgarage.co.uk` (or internal hostname)
- Setup:
  1. Generate default configuration using `matrixdotorg/synapse:latest generate`.
  2. Enable registration shared secret in `homeserver.yaml`.
  3. Start Synapse container.
  4. Create user `MATRIX_USER` with generated password via `register_new_matrix_user`.
  5. Create bot user `HermesAgent` with generated credentials.
  6. Create an encrypted/direct room, invite `MATRIX_USER`, and accept the invite.
  7. Send a test confirmation message to the room: `"Hermes deployment complete and verified."`

---

### PHASE 6: SECRETS SYNC & FINAL AUDIT
1. Authenticate `bw` CLI against `https://vaultwarden.jimsgarage.co.uk`:
   - Documentation available at: https://bitwarden.com/en-gb/help/cli/
   - Store all generated credentials as separate items with exact subdomain URLs.
   - Store Cloudflare API credentials as a secure note titled `"Cloudflare API credentials"`.
   - Store Matrix tokens and recovery keys as secure notes.
2. Securely remove `/tmp/credentials_staging.env`.
3. Validate:
   - Run `docker ps` to verify all containers are healthy.
   - Run `curl -kL https://<subdomain>` for every configured URL and confirm HTTP 200/302 responses.
   - Confirm wildcard certificate on `jimsgarage.co.uk` is valid and not self-signed.
