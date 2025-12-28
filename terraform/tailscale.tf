# Tailscale configuration for automatic device registration and cleanup

# IMPORTANT: This approach has a limitation
# The Tailscale Terraform provider cannot manage devices registered via Ansible
# because it doesn't know the device ID until after Ansible runs.
#
# Current behavior:
# - terraform destroy → Removes VM and auth key
# - Tailscale device → Remains orphaned (manual cleanup needed)
#
# Workaround options:
# 1. Use ephemeral auth keys (device auto-removed when offline)
# 2. Use cleanup workflow (automated periodic cleanup)
# 3. Manual cleanup via Tailscale admin console

# Create a reusable auth key for VM registration
# Note: Tags must be defined in your Tailscale ACL policy first
resource "tailscale_tailnet_key" "vm_auth_key" {
  reusable      = true
  ephemeral     = true  # CHANGED: Device auto-removed when offline
  preauthorized = true
  expiry        = 7776000  # 90 days
  description   = "Auth key for ${var.app_name} VM managed by Terraform"
  
  # Only include tags if they're defined in your Tailscale ACL
  # Comment out or remove tags if you haven't configured them yet
  # tags = [
  #   "tag:terraform-managed",
  #   "tag:proxmox-vm",
  #   "tag:${var.environment}"
  # ]
}

# Output the auth key for use in cloud-init (marked sensitive)
output "tailscale_auth_key" {
  value     = tailscale_tailnet_key.vm_auth_key.key
  sensitive = true
  description = "Tailscale auth key for VM registration"
}
