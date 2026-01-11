#cloud-config
# Tailscale installation for Terraform-managed VMs
# This file is a template that will be processed by the workflow

runcmd:
  # Install Tailscale
  - curl -fsSL https://tailscale.com/install.sh | sh
  # Join Tailnet with pre-authorized key
  - tailscale up --authkey=${tailscale_auth_key} --hostname=${hostname} --accept-routes
  # Verify Tailscale is connected (wait up to 30 seconds)
  - timeout 30 sh -c 'until tailscale status --json | grep -q "\"Online\":true"; do sleep 2; done' || echo "Tailscale connection timeout - will retry via systemd"
  # Create systemd service to ensure Tailscale stays connected
  - systemctl enable tailscaled
  - systemctl start tailscaled

final_message: "Tailscale installation complete. Device registered in Tailnet."
