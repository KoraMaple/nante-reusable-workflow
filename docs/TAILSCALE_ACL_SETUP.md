# Tailscale ACL Setup for Ephemeral Keys

## Why This Is Needed

Tailscale requires tags to be defined in your ACL policy before you can use ephemeral auth keys. This is a security feature to ensure proper access control.

## Quick Setup

### 1. Access Tailscale ACL Editor

Go to: https://login.tailscale.com/admin/acls

### 2. Add Tag Definitions

Add this to your ACL policy (merge with existing policy):

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
    },
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:terraform-managed:*"]
    }
  ]
}
```

### 3. Save ACL Policy

Click **Save** in the Tailscale admin console.

### 4. Enable Ephemeral Keys

Edit `terraform/tailscale.tf`:

```hcl
resource "tailscale_tailnet_key" "vm_auth_key" {
  reusable      = true
  ephemeral     = true  # Change to true
  preauthorized = true
  expiry        = 7776000
  
  tags = [  # Uncomment these
    "tag:terraform-managed",
    "tag:proxmox-vm",
    "tag:${var.environment}"
  ]
}
```

### 5. Test

```bash
cd terraform/
terraform apply
# Should succeed now
```

## Complete ACL Example

Here's a complete ACL policy example:

```json
{
  "tagOwners": {
    "tag:terraform-managed": ["autogroup:admin"],
    "tag:proxmox-vm": ["autogroup:admin"],
    "tag:dev": ["autogroup:admin"],
    "tag:prod": ["autogroup:admin"],
    "tag:staging": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["tag:terraform-managed"],
      "dst": ["*:*"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["autogroup:self"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

## Understanding Tags

### Tag Ownership

```json
"tagOwners": {
  "tag:terraform-managed": ["autogroup:admin"]
}
```

- **Tag name**: `tag:terraform-managed`
- **Owners**: `autogroup:admin` (only admins can apply this tag)
- **Purpose**: Identifies devices created by Terraform

### ACL Rules

```json
{
  "action": "accept",
  "src": ["tag:terraform-managed"],
  "dst": ["*:*"]
}
```

- **Action**: Allow traffic
- **Source**: Devices with `tag:terraform-managed`
- **Destination**: All devices on all ports

## Benefits of Ephemeral Keys

Once configured:

✅ **Automatic cleanup** - Devices removed when VM destroyed  
✅ **Better organization** - Tag-based filtering in admin console  
✅ **Access control** - Tag-based ACL rules  
✅ **Audit trail** - Easy to identify Terraform-managed devices  

## Without ACL Configuration

If you don't want to configure ACL tags:

**Current setup works fine:**
- Non-ephemeral keys (no tags required)
- Manual cleanup via Tailscale admin console
- Or use automated cleanup workflow

**Trade-off:**
- Simpler setup (no ACL changes)
- Manual cleanup when VMs destroyed
- Less organized (no tag filtering)

## Troubleshooting

### Error: "tailnet-owned auth key must have tags set"

**Cause:** Ephemeral keys require tags, but tags aren't configured in ACL.

**Solution:**
1. Add tags to ACL policy (see above)
2. OR set `ephemeral = false` in `tailscale.tf`

### Error: "tags are invalid or not permitted"

**Cause:** Tags used in Terraform but not defined in ACL policy.

**Solution:**
1. Add tag definitions to ACL `tagOwners` section
2. Save ACL policy
3. Retry Terraform apply

### Can't Edit ACL Policy

**Cause:** You need admin permissions.

**Solution:**
1. Ask your Tailscale admin to add the tags
2. Or use non-ephemeral keys (no ACL changes needed)

## Migration Path

### Current State (No ACL Setup)
```hcl
ephemeral = false  # No tags needed
# tags commented out
```
- Works immediately
- Manual cleanup required

### After ACL Setup
```hcl
ephemeral = true  # Automatic cleanup
tags = ["tag:terraform-managed", ...]
```
- Requires ACL configuration
- Automatic cleanup

## Resources

- [Tailscale ACL Documentation](https://tailscale.com/kb/1018/acls)
- [Tailscale Tags Guide](https://tailscale.com/kb/1068/acl-tags)
- [Tailscale Admin Console](https://login.tailscale.com/admin/acls)
