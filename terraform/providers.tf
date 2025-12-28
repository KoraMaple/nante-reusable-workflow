terraform {
  backend "s3" {
    # MinIO configuration - values provided via -backend-config in workflow
    # bucket, endpoints, access_key, secret_key are passed at init time
    key                         = "terraform.tfstate"
    region                      = "us-east-1"  # Required but ignored by MinIO
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true  # Required for MinIO
    skip_s3_checksum            = true  # Disable checksums for MinIO compatibility
  }
  
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

provider "tailscale" {
  # Uses environment variables:
  # TAILSCALE_OAUTH_CLIENT_ID
  # TAILSCALE_OAUTH_CLIENT_SECRET
  # TAILSCALE_TAILNET (or "-" for default)
}
