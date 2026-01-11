# Tailscale Setup Guide

This workflow uses Terraform to manage Tailscale authentication keys via OAuth, eliminating the need for manually created auth keys stored in Doppler.

## Prerequisites

### 1. Create Tailscale OAuth Client

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/oauth)
2. Click **Generate OAuth client**
3. Set the following scopes:
   - `devices:write` - Required to create auth keys
   - `devices:read` - Optional, for status checks
4. Copy the **Client ID** and **Client Secret**

### 2. Configure Doppler Secrets

Add the following secrets to your Doppler project:

```bash
TAILSCALE_OAUTH_CLIENT_ID=<your-client-id>
TAILSCALE_OAUTH_CLIENT_SECRET=<your-client-secret>
TAILSCALE_TAILNET=<your-tailnet-name>  # Optional, defaults to "-"
```

**Note:** You do **NOT** need to create or store `TS_AUTHKEY` in Doppler anymore. Terraform will generate it automatically.

### 3. Configure Tailscale ACL Tags (Optional)

If you want to use tags for access control, add them to your Tailscale ACL policy:

```json
{
  "tagOwners": {
    "tag:proxmox-vm": ["autogroup:admin"],
    "tag:prod": ["autogroup:admin"],
    "tag:dev": ["autogroup:admin"]
  }
}
```

If you don't want to use tags, comment out the `tags` section in `terraform/tailscale.tf`:

```hcl
resource "tailscale_tailnet_key" "vm_auth_key" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000  # 90 days
  description   = "Auth key for ${var.app_name} VM managed by Terraform"
  
  # Comment out if tags not configured in ACL
  # tags = [
  #   "tag:proxmox-vm",
  #   "tag:${var.environment}"
  # ]
}
```

## How It Works

1. **Terraform Phase:**
   - Workflow exports `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET` from Doppler
   - Terraform provider authenticates with Tailscale using OAuth credentials
   - Terraform creates a reusable auth key via `tailscale_tailnet_key` resource
   - Auth key is captured as Terraform output

2. **Ansible Phase:**
   - Workflow retrieves auth key from Terraform: `terraform output -raw tailscale_auth_key`
   - Auth key is exported as `TS_AUTHKEY` environment variable
   - Ansible reads `TS_AUTHKEY` and uses it to connect the VM/CT to Tailscale

## Troubleshooting

### No Tailscale auth key from Terraform

**Symptoms:**
```
⚠️  No Tailscale auth key from Terraform - check OAuth credentials
```

**Causes:**
1. OAuth credentials not set in Doppler
2. OAuth client doesn't have `devices:write` scope
3. Tailscale ACL tags not defined (if using tags)

**Solutions:**
1. Verify Doppler secrets are set correctly
2. Check OAuth client scopes in Tailscale admin console
3. Comment out `tags` in `terraform/tailscale.tf` if not using ACL tags

### Tailscale connection fails in Ansible

**Symptoms:**
```
FAILED - RETRYING: Wait for Tailscale to be online (10 retries left)
```

**Causes:**
1. Auth key not being passed to Ansible
2. Network connectivity issues
3. Tailscale service not starting

**Solutions:**
1. Check workflow logs for "✓ Using Terraform-generated Tailscale auth key"
2. SSH into VM/CT and check: `tailscale status`
3. Check Tailscale logs: `journalctl -u tailscaled -f`

### Device not appearing in Tailscale admin

**Causes:**
1. Auth key expired or invalid
2. Firewall blocking Tailscale traffic (UDP 41641)
3. Device hostname conflict

**Solutions:**
1. Regenerate auth key by destroying and recreating Terraform resources
2. Check firewall rules on Proxmox host and VM/CT
3. Verify hostname is unique in Tailscale network

## Auth Key Management

### Key Properties
- **Reusable:** Yes - same key can register multiple devices
- **Ephemeral:** No - devices persist after going offline
- **Preauthorized:** Yes - no manual approval needed
- **Expiry:** 90 days

### Key Rotation
To rotate the auth key:
```bash
cd terraform
terraform taint tailscale_tailnet_key.vm_auth_key
terraform apply
```

### Cleanup
When you destroy a VM/CT with `terraform destroy`:
- ✅ Terraform removes the VM/CT
- ✅ Terraform removes the auth key
- ❌ Tailscale device remains (manual cleanup needed)

**Cleanup options:**
1. Use ephemeral keys (auto-removed when offline)
2. Use the `tailscale-cleanup.yml` workflow
3. Manual removal via Tailscale admin console
