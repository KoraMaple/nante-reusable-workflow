# Tailscale configuration for automatic device registration and cleanup

# Create a reusable auth key for VM registration
resource "tailscale_tailnet_key" "vm_auth_key" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000  # 90 days
  description   = "Auth key for ${var.app_name} VM managed by Terraform"
  
  tags = [
    "tag:terraform-managed",
    "tag:proxmox-vm",
    "tag:${var.environment}"
  ]
}

# Output the auth key for use in cloud-init (marked sensitive)
output "tailscale_auth_key" {
  value     = tailscale_tailnet_key.vm_auth_key.key
  sensitive = true
  description = "Tailscale auth key for VM registration"
}
