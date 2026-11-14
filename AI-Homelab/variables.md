# ==============================================================================
# Hermes Autonomous Agent - Base Variables Configuration
# File Path: ~/variables
# Target Host: 192.168.8.86 (Docker VM)
# Permissions: chmod 600 ~/variables
# ==============================================================================

# --- VAULTWARDEN INITIAL CREDENTIALS ---
# Master credentials used to initialize the administrative Vaultwarden account
VAULTWARDEN_USER="admin@jimsgarage.co.uk"
VAULTWARDEN_MASTERKEY="REPLACE_WITH_STRONG_MASTER_PASSWORD"

# --- CLOUDFLARE DNS-01 CHALLENGE ---
# Scoped API Token (Permissions: Zone -> DNS -> Edit)
# Leave CF_API_EMAIL blank if using a scoped token (maps to CF_DNS_API_TOKEN)
CF_DNS_API_TOKEN="token"
CF_API_EMAIL="email"
CF_API_KEY="token"

# --- LOCAL AI / LLM BACKEND ---
# IP address of the local LLM host queried by Halogen Dashboard
LLM_IP="192.168.8.148"

# --- MATRIX SYNAPSE USER ---
# Username for Matrix Synapse
MATRIX_USER="james"

# --- GOTIFY USER ---
# Username for Gotify
GOTIFY_USER="james"

# --- ENVIRONMENT & STACK METADATA ---
BASE_DOMAIN="jimsgarage.co.uk"
TARGET_HOST="192.168.8.86"
DOCKER_NETWORK="proxy"
DOCKER_SUBNET="172.28.0.0/16"
TIMEZONE="Europe/London"
