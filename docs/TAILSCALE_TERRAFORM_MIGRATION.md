# Tailscale Terraform Migration Plan

## Overview

Migrate from Ansible-managed Tailscale to Terraform-managed Tailscale for automatic device cleanup when VMs are destroyed.

## Current State (Ansible)

**How it works now:**
- Ansible installs Tailscale via script
- Ansible runs `tailscale up` with auth key
- Device registered in Tailnet
- **Problem:** Device remains in Tailnet after VM destruction

**Files involved:**
- `ansible/roles/base_setup/tasks/main.yml` - Tailscale installation
- `ansible/roles/mgmt-docker/tasks/main.yml` - Tailscale installation

## Target State (Terraform)

**How it will work:**
- Terraform creates `tailscale_device_authorization` resource
- Cloud-init installs Tailscale and runs `tailscale up`
- VM registers with pre-authorized key
- **Benefit:** Device automatically removed when VM destroyed

## Implementation Steps

### Step 1: Add Tailscale Provider to Terraform

**File:** `terraform/providers.tf` (new file)

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.15"
    }
  }
}

provider "tailscale" {
  # Uses environment variables:
  # TAILSCALE_OAUTH_CLIENT_ID
  # TAILSCALE_OAUTH_CLIENT_SECRET
  # TAILSCALE_TAILNET (or "-" for default)
}
```

### Step 2: Create Reusable Auth Key Resource

**File:** `terraform/tailscale.tf` (new file)

```hcl
# Create a reusable auth key for VM registration
resource "tailscale_tailnet_key" "vm_auth_key" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000  # 90 days
  description   = "Auth key for Proxmox VMs managed by Terraform"
  
  tags = [
    "tag:terraform-managed",
    "tag:proxmox-vm"
  ]
}

# Output the auth key for cloud-init
output "tailscale_auth_key" {
  value     = tailscale_tailnet_key.vm_auth_key.key
  sensitive = true
}
```

### Step 3: Update VM Resource with Tailscale in Cloud-Init

**File:** `terraform/main.tf`

```hcl
resource "proxmox_vm_qemu" "vm" {
  # ... existing config ...
  
  # Update cloud-init to include Tailscale
  cicustom = "user=local:snippets/${var.app_name}-user-data.yml"
  
  # Create cloud-init config with Tailscale
  provisioner "local-exec" {
    command = <<-EOT
      cat > /tmp/${var.app_name}-user-data.yml <<'EOF'
      #cloud-config
      users:
        - name: deploy
          ssh_authorized_keys:
            - ${var.ssh_public_key}
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: sudo
          shell: /bin/bash
      
      package_update: true
      package_upgrade: true
      
      packages:
        - curl
        - qemu-guest-agent
      
      runcmd:
        # Install Tailscale
        - curl -fsSL https://tailscale.com/install.sh | sh
        # Join Tailnet with pre-authorized key
        - tailscale up --authkey=${tailscale_tailnet_key.vm_auth_key.key} --hostname=${var.app_name}
        # Enable and start qemu-guest-agent
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
      
      final_message: "Cloud-init complete after $UPTIME seconds"
      EOF
    EOT
  }
}
```

### Step 4: Alternative - Device Authorization Resource

**More explicit control per VM:**

```hcl
# In terraform/main.tf

# Pre-authorize the device
resource "tailscale_device_authorization" "vm" {
  device_id = proxmox_vm_qemu.vm.default_ipv4_address
  authorized = true
}

# Or use device key for more control
resource "tailscale_device_key" "vm" {
  device_id = data.tailscale_device.vm.id
  key_expiry_disabled = false
}
```

### Step 5: Update Ansible to Skip Tailscale

**File:** `ansible/roles/base_setup/tasks/main.yml`

```yaml
- name: Check if Tailscale is already configured
  command: tailscale status --json
  register: tailscale_status
  failed_when: false
  changed_when: false

- name: Install Tailscale (if not managed by Terraform)
  when: tailscale_status.rc != 0
  block:
    - name: Install Tailscale
      shell: "curl -fsSL https://tailscale.com/install.sh | sh"
      args:
        creates: /usr/bin/tailscale
    
    - name: Connect to Tailscale
      command: "tailscale up --authkey={{ ts_authkey }} --hostname={{ target_hostname }}"
      environment:
        TS_AUTHKEY: "{{ ts_authkey }}"
      register: tailscale_result
      changed_when: "'Success' in tailscale_result.stdout or tailscale_result.rc == 0"
      failed_when: false
```

### Step 6: Add Doppler Secrets

**Required secrets:**

```bash
# Tailscale OAuth Client (recommended)
TAILSCALE_OAUTH_CLIENT_ID=k123abc...
TAILSCALE_OAUTH_CLIENT_SECRET=tskey-client-k123abc...
TAILSCALE_TAILNET=-  # or your tailnet name

# Or API Key (alternative)
TAILSCALE_API_KEY=tskey-api-k123abc...
TAILSCALE_TAILNET=-
```

### Step 7: Update Workflows

**File:** `.github/workflows/reusable-provision.yml`

No changes needed - Terraform will handle Tailscale automatically.

## Migration Strategy

### Option A: Clean Migration (Recommended)

1. **Add Tailscale provider to Terraform**
2. **Create new VMs with Terraform-managed Tailscale**
3. **Gradually decommission old VMs**
4. **Remove Ansible Tailscale tasks once all VMs migrated**

### Option B: Hybrid Approach

1. **Add Tailscale provider to Terraform**
2. **Make Ansible Tailscale conditional** (skip if already configured)
3. **New VMs use Terraform, existing VMs keep Ansible**
4. **Eventually migrate all to Terraform**

## Testing Plan

### Test 1: New VM with Terraform Tailscale

```yaml
# Test workflow
jobs:
  test:
    uses: ./.github/workflows/reusable-provision.yml@develop
    with:
      app_name: "test-ts-terraform"
      vlan_tag: "20"
      vm_target_ip: "<INTERNAL_IP_VLAN20>"
```

**Verify:**
- ✅ VM appears in Tailnet with correct name
- ✅ Device is pre-authorized
- ✅ Tags applied correctly
- ✅ Ansible skips Tailscale installation

### Test 2: VM Destruction Cleanup

```bash
# Destroy VM
terraform destroy -var="app_name=test-ts-terraform"
```

**Verify:**
- ✅ VM removed from Proxmox
- ✅ Device removed from Tailnet automatically
- ✅ No orphaned devices in Tailnet

### Test 3: Existing VM Onboarding

```yaml
# Test onboard workflow
jobs:
  test:
    uses: ./.github/workflows/reusable-onboard.yml@develop
    with:
      target_ip: "<INTERNAL_IP_VLAN20>"
      target_hostname: "existing-server"
```

**Verify:**
- ✅ Ansible installs Tailscale (not managed by Terraform)
- ✅ Device registers successfully
- ✅ No conflicts with Terraform

## Benefits After Migration

1. **Automatic Cleanup**
   - No orphaned devices in Tailnet
   - Clean infrastructure lifecycle

2. **Better Naming**
   - Device names match VM names
   - Consistent naming convention

3. **Tag-Based ACLs**
   - Apply tags via Terraform
   - Enforce access policies

4. **Audit Trail**
   - Terraform state tracks all devices
   - Easy to see what's managed

5. **Simplified Ansible**
   - Less responsibility for Ansible
   - Faster playbook execution

## Rollback Plan

If issues arise:

1. **Revert Terraform changes**
   ```bash
   git revert <commit>
   ```

2. **Re-enable Ansible Tailscale**
   - Remove conditional checks
   - Restore original tasks

3. **Manually clean up Tailnet**
   - Remove Terraform-created devices
   - Re-register with Ansible

## Timeline

- **Week 1:** Add Tailscale provider, create resources
- **Week 2:** Test with new VMs, verify cleanup
- **Week 3:** Update Ansible to be conditional
- **Week 4:** Documentation and examples
- **Target:** Include in v1.0.0 or v1.1.0 release

## Documentation Updates

Files to update:
- `docs/OCTOPUS_SETUP.md` - Add Tailscale OAuth setup
- `.github/copilot-instructions.md` - Update Tailscale section
- `CHANGELOG.md` - Document migration
- `README.md` - Update architecture diagram
- New: `docs/TAILSCALE_SETUP.md` - Comprehensive guide

## Considerations

### OAuth Client vs API Key

**OAuth Client (Recommended):**
- ✅ Doesn't expire
- ✅ Scoped permissions
- ✅ Not tied to user account
- ✅ Better for automation

**API Key:**
- ⚠️ Tied to user account
- ⚠️ Full access (no scopes)
- ⚠️ Less secure for CI/CD

### Device Tags

Define tags in Tailscale ACL:

```json
{
  "tagOwners": {
    "tag:terraform-managed": ["autogroup:admin"],
    "tag:proxmox-vm": ["autogroup:admin"],
    "tag:production": ["autogroup:admin"],
    "tag:development": ["autogroup:admin"]
  }
}
```

Apply in Terraform:

```hcl
resource "tailscale_tailnet_key" "vm_auth_key" {
  tags = [
    "tag:terraform-managed",
    "tag:proxmox-vm",
    "tag:${var.environment}"
  ]
}
```

### Ephemeral vs Persistent

**Ephemeral Nodes:**
- Removed immediately when offline
- Good for short-lived VMs
- `ephemeral = true`

**Persistent Nodes:**
- Remain in Tailnet when offline
- Good for VMs that may reboot
- `ephemeral = false` (default)

**Recommendation:** Use persistent for infrastructure VMs

## Next Steps

1. Create Tailscale OAuth client in admin console
2. Add secrets to Doppler
3. Implement Terraform resources
4. Test with new VM
5. Verify cleanup on destroy
6. Update documentation
7. Include in next release
