# Troubleshooting Guide

## Common Issues

### Tailscale Device Not Appearing

**Symptom:**
Terraform completes successfully but device doesn't appear in Tailscale admin console.

**Cause:**
Tailscale is installed by Ansible, not Terraform. Device registration happens AFTER Terraform completes.

**Timeline:**
1. Terraform creates VM (1-2 minutes)
2. VM boots and becomes SSH-accessible (30-60 seconds)
3. Ansible runs and installs Tailscale (1-2 minutes)
4. Device appears in Tailscale (immediately after Ansible completes)

**Solution:**
Wait for the complete workflow to finish. Check Tailscale admin console after you see:
```
✓ VM provisioned and configured
✓ Octopus Tentacle installed and registered
```

**Verify:**
```bash
# SSH to VM
ssh deploy@<vm-ip>

# Check Tailscale status
tailscale status

# Should show connected
```

### Missing jq Command Error

**Symptom:**
```
bash: line 25: jq: command not found
Error: Process completed with exit code 127
```

**Cause:**
Workflow tried to use `jq` which isn't installed on the runner.

**Solution:**
Fixed in latest version - workflows now use pure bash for JSON parsing (no `jq` dependency).

If you see this error, pull latest changes:
```bash
git pull origin main
```

## Workflow Failures and Retries

### VM Already Exists Error

**Symptom:**
```
Error: VM 104 already running
  with proxmox_vm_qemu.generic_vm
```

**Cause:**
Workflow failed after VM was created but before Ansible completed. Re-running the workflow tries to create the VM again.

**Solution:**
The workflow now automatically detects existing VMs and skips Terraform apply. Simply **re-run the workflow** - it will:
1. Detect VM exists in Terraform state
2. Skip VM creation
3. Proceed directly to Ansible configuration

**Manual Recovery (if needed):**
```bash
# Option 1: Import existing VM into Terraform state
cd terraform/
terraform workspace select <app_name>
terraform import proxmox_vm_qemu.generic_vm <proxmox_node>/qemu/<vm_id>

# Option 2: Destroy and start fresh
terraform destroy
# Then re-run workflow
```

### Tailscale Tag Error

**Symptom:**
```
Error: Failed to create key
requested tags [tag:terraform-managed tag:proxmox-vm tag:***] are invalid
or not permitted (400)
```

**Cause:**
Tailscale tags must be defined in your Tailscale ACL policy before they can be used.

**Solution 1: Remove Tags (Quick Fix)**
Tags are now commented out by default in `terraform/tailscale.tf`. No action needed.

**Solution 2: Configure ACL (Recommended)**
1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/acls)
2. Add tag definitions to your ACL policy:
```json
{
  "tagOwners": {
    "tag:terraform-managed": ["autogroup:admin"],
    "tag:proxmox-vm": ["autogroup:admin"],
    "tag:dev": ["autogroup:admin"],
    "tag:prod": ["autogroup:admin"]
  }
}
```
3. Save ACL policy
4. Uncomment tags in `terraform/tailscale.tf`
5. Re-run workflow

### Ansible Fails After Terraform Success

**Symptom:**
Terraform creates VM successfully, but Ansible configuration fails.

**Solution:**
Re-run the workflow. It will:
1. Detect existing VM
2. Skip Terraform
3. Retry Ansible configuration

The workflow is now idempotent and safe to retry.

## SSH Permission Denied (Password Authentication)

### Symptom
```
Permission denied (publickey,password).
```
or
```
Permission denied, please try again.
```

Even with the correct password.

### Cause
The target VM's SSH server is likely configured to reject password authentication.

### Diagnosis

SSH to the target VM and check SSH configuration:

```bash
# On the target VM
sudo grep -E "^PasswordAuthentication|^PermitRootLogin|^PubkeyAuthentication" /etc/ssh/sshd_config
```

### Solution 1: Enable Password Authentication (Temporary)

**On the target VM**, edit `/etc/ssh/sshd_config`:

```bash
sudo nano /etc/ssh/sshd_config
```

Ensure these settings:
```
PasswordAuthentication yes
PermitRootLogin yes  # or 'prohibit-password' if you want to allow root with keys only
PubkeyAuthentication yes
```

Restart SSH service:
```bash
sudo systemctl restart sshd
```

**Security Note:** After bootstrapping the deploy user, you should disable password auth again:
```
PasswordAuthentication no
PermitRootLogin prohibit-password
```

### Solution 2: Manual Bootstrap (Recommended)

If you have console access to the VM (Proxmox GUI, physical access, etc.), manually create the deploy user:

```bash
# Run directly on the target VM (via console)
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo deploy
echo "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deploy
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh

# Add your public key (get from Doppler ANS_SSH_PUBLIC_KEY)
echo "YOUR_PUBLIC_KEY_HERE" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
```

Then use `reusable-onboard` workflow normally.

### Solution 3: Use Existing SSH Key

If you already have SSH key access to the VM with a different user:

1. SSH to the VM with your existing key
2. Run the manual bootstrap commands above
3. Use `reusable-onboard` workflow

### Testing SSH Access

From your runner, test SSH access:

```bash
# Test password authentication
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@192.168.20.10

# Test with sshpass
sshpass -p 'YOUR_PASSWORD' ssh -o StrictHostKeyChecking=no root@192.168.20.10 'echo "SSH works"'

# Check SSH server config remotely
ssh root@192.168.20.10 'grep PasswordAuthentication /etc/ssh/sshd_config'
```

## Common Bootstrap Issues

### Issue: "sshpass: command not found"

**Solution:** Install on runner:
```bash
sudo apt-get update && sudo apt-get install -y sshpass
```

### Issue: "sudo: a password is required"

**Solution:** Configure passwordless sudo on runner:
```bash
echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/github-runner
```

### Issue: "Host key verification failed"

**Solution:** Already handled by `StrictHostKeyChecking=no` in workflows, but you can also:
```bash
# On runner, add to known_hosts
ssh-keyscan -H 192.168.20.10 >> ~/.ssh/known_hosts
```

### Issue: Doppler secret not found

**Solution:** Verify secret exists in Doppler:
```bash
# On runner or locally with Doppler configured
doppler secrets get BOOTSTRAP_SSH_PASSWORD
```

## Workflow-Specific Issues

### Provision Workflow

**Issue:** "MINIO_ROOT_USER not found"
- Ensure Doppler is configured with correct project/config
- Verify secrets exist in Doppler dashboard

**Issue:** "Terraform workspace does not exist"
- This is normal for first run - workspace will be created
- For destroy, ensure you're using the correct app_name

### Onboard Workflow

**Issue:** "Ansible cannot connect to VM"
- Verify deploy user exists on target
- Verify SSH key is in `/home/deploy/.ssh/authorized_keys`
- Test SSH manually: `ssh deploy@TARGET_IP`

### Destroy Workflow

**Issue:** "Workspace does not exist"
- Verify app_name matches the one used during provision
- Check available workspaces: `terraform workspace list`

## Network Issues

### Issue: Cannot reach target VM

**Diagnosis:**
```bash
# From runner
ping 192.168.20.10
nc -zv 192.168.20.10 22  # Test SSH port
```

**Common Causes:**
- VM is not on the same network as runner
- Firewall blocking SSH (port 22)
- VM is powered off
- Wrong IP address

### Issue: Cannot reach MinIO

**Diagnosis:**
```bash
# From runner
curl -v http://192.168.20.10:9000
```

**Solution:** Ensure MinIO is accessible from runner's network.

## Debugging Tips

### Enable Ansible Verbose Output

Modify workflow to add `-vvv` to ansible-playbook:
```yaml
ansible-playbook -vvv -i "IP," playbook.yml
```

### Enable Terraform Debug

Add to workflow:
```yaml
env:
  TF_LOG: DEBUG
```

### Check Doppler Secrets

In workflow, add debug step:
```yaml
- name: Debug Doppler
  run: |
    doppler run -- bash <<'EOF'
    echo "Available secrets (names only):"
    env | grep -v "PASSWORD\|SECRET\|TOKEN\|KEY" | cut -d= -f1 | sort
    EOF
```

### Manual Workflow Testing

Test workflow steps manually on runner:

```bash
# Setup Doppler
doppler setup --project YOUR_PROJECT --config YOUR_CONFIG

# Test secret access
doppler run -- bash -c 'echo $MINIO_ROOT_USER'

# Test Ansible connectivity
cd ansible/
doppler run -- ansible all -i "192.168.20.10," -m ping --user deploy
```
