terraform {
  required_version = ">= 0.14"
  required_providers {
    proxmox = {
      source  = "registry.example.com/telmate/proxmox"
      version = ">= 1.0.0"
    }
  }
}

provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = "https://proxmox.jimsgarage.co.uk/api2/json"
    pm_api_token_secret = "112e04a7-4f15-45c5-b1e1-624e90a55f8b"
    pm_api_token_id = "root@pam!terraform"
}