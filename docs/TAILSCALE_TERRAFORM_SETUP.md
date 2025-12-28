# Tailscale Terraform Setup Guide

This guide explains how to set up and use Tailscale with Terraform for automatic device lifecycle management.

## Overview

As of v1.0.0, Tailscale device management is handled by Terraform, providing automatic cleanup when VMs are destroyed. Ansible still handles Tailscale installation for existing infrastructure onboarding.

## Architecture

```
Terraform creates Tailscale auth key
    ↓
Terraform provisions VM
    ↓
Ansible installs Tailscale (if not already configured)
    ↓
Tailscale connects using Terraform-generated key
    ↓
Device registered in Tailnet
    ↓
terraform destroy → Device automatically removed
```

## Prerequisites

1. Tailscale account with admin access
2. OAuth client credentials (recommended) or API key

## Setup Steps

### 1. Create Tailscale OAuth Client

**Recommended approach for automation:**

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/oauth)
2. Click **Generate OAuth Client**
3. Set description: "Terraform Provider"
4. Select scopes:
   - `devices:write` - Create and manage devices
   - `auth_keys:write` - Create auth keys
5. Copy the Client ID and Client Secret

### 2. Add Secrets to Doppler

```bash
# Add to your Doppler project/config
TAILSCALE_OAUTH_CLIENT_ID=k123abc...
TAILSCALE_OAUTH_CLIENT_SECRET=tskey-client-k123abc...
TAILSCALE_TAILNET=-  # Use "-" for default tailnet
```

**Alternative: API Key (not recommended)**
```bash
TAILSCALE_API_KEY=tskey-api-k123abc...
TAILSCALE_TAILNET=-
```

### 3. Configure Tailscale ACLs (Optional)

Define tags in your Tailscale ACL policy:

```json
{
  "tagOwners": {
    "tag:terraform-managed": ["autogroup:admin"],
    "tag:proxmox-vm": ["autogroup:admin"],
    "tag:dev": ["autogroup:admin"],
    "tag:prod": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:terraform-managed"],
      "dst": ["*:*"]
    }
  ]
}
```

## How It Works

### Automatic Cleanup with Ephemeral Keys

**Key Configuration:**
```hcl
resource "tailscale_tailnet_key" "vm_auth_key" {
  reusable      = true
  ephemeral     = true  # ← Device auto-removed when offline
  preauthorized = true
  expiry        = 7776000  # 90 days
}
```

**What happens:**
1. Terraform creates ephemeral auth key
2. Ansible installs Tailscale using this key
3. Device registers in Tailnet
4. **When VM destroyed** → Device goes offline → **Tailscale auto-removes it**

**Ephemeral vs Non-Ephemeral:**

| Type | Behavior | Use Case |
|------|----------|----------|
| **Ephemeral** (default) | Auto-removed when offline | VMs that are destroyed/recreated |
| **Non-Ephemeral** | Persists when offline | Long-lived infrastructure |

### Terraform Resources

**`terraform/providers.tf`**
```hcl
provider "tailscale" {
  # Uses environment variables:
  # TAILSCALE_OAUTH_CLIENT_ID
  # TAILSCALE_OAUTH_CLIENT_SECRET
  # TAILSCALE_TAILNET
}
```

### Ansible Behavior

Ansible roles now check if Tailscale is already configured:

```yaml
- name: Check if Tailscale is already configured
  command: tailscale status --json
  register: tailscale_status
  failed_when: false

- name: Install Tailscale (if not managed by Terraform)
  when: tailscale_status.rc != 0
  # ... installation tasks
```

**Result:**
- New VMs provisioned by Terraform: Ansible skips installation
- Existing infrastructure onboarded: Ansible installs Tailscale
- Hybrid approach works seamlessly

## Usage

### Provision New VM with Terraform-Managed Tailscale

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
    with:
      app_name: "nginx"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.50"
    secrets: inherit
```

**What happens:**
1. Terraform creates auth key with tags
2. Terraform provisions VM
3. Ansible runs, detects Tailscale not configured
4. Ansible installs Tailscale using Terraform-generated key
5. Device appears in Tailnet with tags
6. `terraform destroy` removes device automatically

### Onboard Existing Infrastructure

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@main
    with:
      target_ip: "192.168.20.100"
      target_hostname: "existing-server"
    secrets: inherit
```

**What happens:**
1. Ansible connects to existing server
2. Ansible installs Tailscale (not Terraform-managed)
3. Device registered with fallback auth key
4. Manual cleanup required when decommissioned

## Verification

### Check Device in Tailscale

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Find your device by name
3. Verify tags are applied:
   - `tag:terraform-managed`
   - `tag:proxmox-vm`
   - `tag:dev` or `tag:prod`

### Check on VM

```bash
# SSH to VM
ssh deploy@192.168.20.50

# Check Tailscale status
tailscale status

# View device info
tailscale status --json | jq '.Self'
```

### Test Automatic Cleanup

```bash
# Destroy VM
cd terraform/
terraform destroy -var="app_name=test-vm"

# Wait a few minutes (Tailscale checks device status periodically)
# Check Tailscale admin console
# Device should be removed automatically (ephemeral devices removed when offline)
```

**Timeline:**
- VM destroyed → Device goes offline immediately
- Tailscale detects offline status → Within 1-5 minutes
- Device automatically removed → Ephemeral cleanup triggered

## Troubleshooting

### Device Not Appearing in Tailnet

**Check Terraform output:**
```bash
cd terraform/
terraform output tailscale_auth_key
```

**Check Ansible logs:**
```bash
# Look for Tailscale installation in workflow logs
```

**Verify on VM:**
```bash
ssh deploy@<vm-ip>
tailscale status
journalctl -u tailscaled -n 50
```

### Auth Key Expired

Auth keys expire after 90 days by default.

**Solution:**
```bash
cd terraform/
terraform taint tailscale_tailnet_key.vm_auth_key
terraform apply
```

### Device Not Removed on Destroy

**Check Terraform state:**
```bash
terraform state list
# Should show tailscale_tailnet_key.vm_auth_key
```

**Manual cleanup:**
```bash
# In Tailscale admin console
# Machines → Select device → Delete
```

### OAuth Client Permissions

**Error:** "insufficient permissions"

**Solution:**
1. Verify OAuth client has correct scopes
2. Regenerate OAuth client if needed
3. Update Doppler secrets

## Migration from Ansible-Only

If you have existing VMs with Ansible-managed Tailscale:

### Option 1: Leave As-Is (Recommended)

- Existing VMs continue using Ansible-managed Tailscale
- New VMs use Terraform-managed Tailscale
- No migration needed

### Option 2: Migrate to Terraform

1. Note device name in Tailscale
2. Remove device from Tailscale admin console
3. Re-run Ansible with Terraform-managed workflow
4. Device re-registers with Terraform management

## Best Practices

1. **Use OAuth Client** - More secure than API key, doesn't expire
2. **Tag Devices** - Organize by environment, purpose, etc.
3. **Monitor Expiry** - Set calendar reminder for 90-day auth key rotation
4. **Test Cleanup** - Verify devices removed on destroy
5. **Document Exceptions** - Note any manually-managed devices

## Advanced Configuration

### Custom Auth Key Expiry

```hcl
# terraform/tailscale.tf
resource "tailscale_tailnet_key" "vm_auth_key" {
  expiry = 15552000  # 180 days
  # ...
}
```

### Environment-Specific Tags

```hcl
tags = [
  "tag:terraform-managed",
  "tag:proxmox-vm",
  "tag:${var.environment}",
  "tag:${var.app_name}"
]
```

### Ephemeral Devices

For short-lived VMs:

```hcl
resource "tailscale_tailnet_key" "vm_auth_key" {
  ephemeral = true  # Device removed when offline
  # ...
}
```

## Resources

- [Tailscale Terraform Provider Docs](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [Tailscale OAuth Clients](https://tailscale.com/kb/1215/oauth-clients)
- [Tailscale ACL Documentation](https://tailscale.com/kb/1018/acls)
- [Migration Guide](./TAILSCALE_TERRAFORM_MIGRATION.md)

## Next Steps

1. Create OAuth client in Tailscale
2. Add secrets to Doppler
3. Test with new VM provisioning
4. Verify automatic cleanup
5. Update existing infrastructure as needed
