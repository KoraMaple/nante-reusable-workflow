# Workflow Retry Guide

## Overview

Workflows are now designed to be **idempotent** - you can safely re-run them after failures without causing conflicts or duplicate resources.

## Common Failure Scenarios

### 1. Terraform Fails During VM Creation

**What happens:**
- VM partially created in Proxmox
- Terraform state may or may not be updated
- Workflow fails

**Recovery:**
Simply **re-run the workflow**. It will:
1. Initialize Terraform
2. Detect VM exists in state
3. Skip VM creation
4. Proceed to Ansible configuration

**Example output:**
```
⚠️  VM already exists in Terraform state
This is likely a retry after a previous failure
Skipping Terraform apply, proceeding to Ansible configuration...
```

### 2. Tailscale Provider Fails

**Error:**
```
Error: Failed to create key
requested tags [...] are invalid or not permitted (400)
```

**Cause:**
Tags not defined in Tailscale ACL policy.

**Recovery:**
Tags are now commented out by default. Re-run the workflow - it will work without tags.

**Optional - Enable Tags:**
1. Configure Tailscale ACL (see TROUBLESHOOTING.md)
2. Uncomment tags in `terraform/tailscale.tf`
3. Re-run workflow

### 3. Ansible Fails During Configuration

**What happens:**
- VM created successfully
- Terraform state saved
- Ansible fails (network issue, package error, etc.)

**Recovery:**
Re-run the workflow. It will:
1. Detect VM exists
2. Skip Terraform
3. Retry Ansible from the beginning

**Note:** Ansible roles are designed to be idempotent - running them multiple times is safe.

### 4. Octopus Registration Fails

**What happens:**
- VM created and configured
- Octopus Tentacle installation fails

**Recovery:**
Re-run the workflow. The `base_setup` role will:
1. Skip Tailscale (already configured)
2. Skip Alloy (already configured)
3. Retry Octopus Tentacle installation

## Manual Recovery Options

### Check Terraform State

```bash
cd terraform/
terraform workspace select <app_name>
terraform state list

# Should show:
# proxmox_vm_qemu.generic_vm
# tailscale_tailnet_key.vm_auth_key
```

### Import Existing VM

If VM exists in Proxmox but not in Terraform state:

```bash
cd terraform/
terraform workspace select <app_name>

# Find VM ID in Proxmox UI or CLI
# Then import:
terraform import proxmox_vm_qemu.generic_vm <node>/qemu/<vm_id>

# Example:
terraform import proxmox_vm_qemu.generic_vm pmx/qemu/104
```

### Destroy and Start Fresh

If you want to completely start over:

```bash
cd terraform/
terraform workspace select <app_name>
terraform destroy

# Then re-run workflow from GitHub Actions
```

### Manual Ansible Run

If you want to retry just the Ansible portion:

```bash
cd ansible/
ansible-galaxy install -r requirements.yml

# Test connectivity
ansible all -i "192.168.20.50," -m ping --user deploy

# Run playbook
ansible-playbook -i "192.168.20.50," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp" \
  --extra-vars "app_role_name=myapp" \
  --extra-vars "octopus_environment=Development" \
  --extra-vars 'octopus_roles=["web-server","myapp"]'
```

## Best Practices

### 1. Always Re-run First

Before manual intervention, try re-running the workflow. It's designed to handle most failure scenarios automatically.

### 2. Check Workflow Logs

Look for these key indicators:
- `⚠️  VM already exists in Terraform state` - Retry detected
- `✓ Ansible connectivity confirmed` - VM is reachable
- `Tailscale is already configured` - Skipping duplicate work
- `✓ Octopus Tentacle installed and registered` - Success

### 3. Verify State After Retry

After successful retry:
1. Check Proxmox - VM should be running
2. Check Tailscale - Device should be online
3. Check Octopus - Target should be healthy
4. SSH to VM - Verify services running

### 4. Clean Up Failed Attempts

If you have multiple failed attempts:

```bash
# List all workspaces
cd terraform/
terraform workspace list

# Delete failed workspace
terraform workspace select default
terraform workspace delete <failed-app-name>
```

## Workflow Idempotency Features

### Terraform
- ✅ Detects existing VMs in state
- ✅ Skips creation if VM exists
- ✅ Creates missing resources only

### Ansible
- ✅ Checks if Tailscale already configured
- ✅ Checks if Alloy already installed
- ✅ Octopus registration handles "already exists" gracefully
- ✅ All tasks are idempotent (safe to re-run)

### Tailscale
- ✅ Auth keys are reusable
- ✅ Device re-registration is safe
- ✅ Skips installation if already configured

### Octopus
- ✅ Tentacle registration handles duplicates
- ✅ Updates existing targets if already registered
- ✅ Idempotent configuration

## Troubleshooting Retries

### Retry Doesn't Skip Terraform

**Check:**
```bash
cd terraform/
terraform workspace select <app_name>
terraform state list
```

**If empty:**
State wasn't saved. VM exists in Proxmox but not in Terraform state. Use `terraform import`.

### Ansible Still Fails on Retry

**Common causes:**
1. Network connectivity issues
2. Package repository problems
3. Doppler secrets not configured
4. SSH key issues

**Debug:**
```bash
# Test SSH
ssh deploy@<vm-ip>

# Test Ansible connectivity
ansible all -i "<vm-ip>," -m ping --user deploy

# Check Doppler
doppler secrets
```

### VM Exists But Can't Connect

**Check:**
1. VM is running in Proxmox
2. IP address is correct
3. SSH service is running
4. Firewall not blocking

**Verify:**
```bash
# Ping test
ping <vm-ip>

# SSH test
ssh -v deploy@<vm-ip>

# From Proxmox console
qm terminal <vm-id>
```

## Support

If retries continue to fail:
1. Check `docs/TROUBLESHOOTING.md`
2. Review workflow logs for specific errors
3. Verify all Doppler secrets are configured
4. Test manual Terraform/Ansible commands
