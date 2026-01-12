# Octopus Deploy Integration Setup

This guide explains how to configure Octopus Deploy integration with the nante-reusable-workflow pipeline.

## Prerequisites

- Octopus Deploy Server installed and accessible
- Octopus API key with appropriate permissions
- Network connectivity from VMs to Octopus Server (via Tailscale recommended)

## Required Doppler Secrets

Add these secrets to your Doppler project/config:

```bash
OCTOPUS_SERVER_URL=https://octopus.example.com
OCTOPUS_API_KEY=API-XXXXXXXXXXXXXXXXXXXXXXXXXX
OCTOPUS_SPACE_ID=Spaces-1
OCTOPUS_ENVIRONMENT=Development
```

### Secret Details

**`OCTOPUS_SERVER_URL`**
- Full URL to your Octopus Server
- Include protocol (https://)
- Example: `https://octopus.example.com` or `http://<INTERNAL_IP_VLAN20>:8080`

**`OCTOPUS_API_KEY`**
- API key with permissions to register deployment targets
- Generate in Octopus: Profile → My API Keys → New API Key
- Required permissions:
  - `MachineEdit` - Create and edit deployment targets
  - `EnvironmentView` - View environments
  - `MachineView` - View deployment targets

**`OCTOPUS_SPACE_ID`**
- Space ID where targets will be registered
- Default: `Spaces-1` (default space)
- Find in Octopus: Settings → Spaces → Copy Space ID

**`OCTOPUS_ENVIRONMENT`**
- Default environment for target registration
- Can be overridden per workflow call
- Common values: `Development`, `Staging`, `Production`

## Octopus Server Setup

### 1. Create Environments

In Octopus Deploy, create environments for your infrastructure:

1. Navigate to **Infrastructure → Environments**
2. Create environments:
   - Development
   - Staging
   - Production

### 2. Create API Key

1. Click your profile (top right)
2. Go to **My API Keys**
3. Click **New API Key**
4. Set purpose: "GitHub Actions Workflow"
5. Copy the API key and add to Doppler

### 3. Configure Spaces (Optional)

If using multiple spaces:

1. Navigate to **Settings → Spaces**
2. Note the Space ID for your target space
3. Add to Doppler as `OCTOPUS_SPACE_ID`

## Workflow Usage

**Note:** As of v1.0.0, Octopus Tentacle installation is integrated into `base_setup` and runs automatically on every VM. You just need to provide the environment and roles.

### Provision New VM with Octopus Registration

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
    with:
      app_name: "nginx"
      vlan_tag: "20"
      vm_target_ip: "<INTERNAL_IP_VLAN20>"
      cpu_cores: "2"
      ram_mb: "2048"
      disk_gb: "20G"
      octopus_environment: "Production"
      octopus_roles: "web-server,nginx"
    secrets: inherit
```

**What happens:**
1. Terraform provisions VM
2. Ansible runs `base_setup` role
3. `base_setup` automatically installs and registers Octopus Tentacle
4. VM appears in Octopus Deploy as a healthy target

### Onboard Existing Infrastructure

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@main
    with:
      target_ip: "<INTERNAL_IP_VLAN20>"
      ssh_user: "deploy"
      target_hostname: "docker-mgmt"
      app_role: "mgmt-docker"
      octopus_environment: "Development"
      octopus_roles: "docker-host,management"
    secrets: inherit
```

### Skip Octopus Registration

To skip Octopus registration, simply don't set the Octopus secrets in Doppler, or set them to empty values. The `base_setup` role will automatically skip Octopus installation if the required variables are not set.

Alternatively, you can override the variables:

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
    with:
      app_name: "test-vm"
      vlan_tag: "20"
      vm_target_ip: "<INTERNAL_IP_VLAN20>"
    secrets: inherit
    # Don't pass octopus_environment or octopus_roles
    # Or ensure OCTOPUS_SERVER_URL is not set in Doppler
```

## Octopus Roles

Roles are used to target specific deployment targets in Octopus Deploy projects.

### Common Roles

- `web-server` - Web servers (Nginx, Apache)
- `docker-host` - Docker hosts
- `k8s-node` - Kubernetes nodes
- `database` - Database servers
- `management` - Management/monitoring servers

### Assigning Roles

Pass roles as comma-separated string:

```yaml
octopus_roles: "web-server,nginx,production"
```

Or leave empty for no specific roles:

```yaml
octopus_roles: ""
```

## Communication Modes

### Polling Mode (Default, Recommended)

- Tentacle initiates connection to Octopus Server
- No inbound firewall rules required on target
- Better for security and NAT scenarios
- Works well with Tailscale

**Configuration:**
```yaml
# In ansible/roles/octopus-tentacle/defaults/main.yml
tentacle_communication_mode: "Polling"
```

### Listening Mode

- Octopus Server connects to Tentacle
- Requires inbound firewall rule on port 10933
- Useful for on-premises scenarios

**Configuration:**
```yaml
# In ansible/roles/octopus-tentacle/defaults/main.yml
tentacle_communication_mode: "Listening"
tentacle_port: 10933
```

## Verification

### Check Tentacle Service

On the target VM:

```bash
# Check service status
sudo systemctl status tentacle

# View logs
sudo journalctl -u tentacle -f

# Show configuration
sudo /opt/octopus/tentacle/Tentacle show-configuration --instance Tentacle

# Show thumbprint
sudo /opt/octopus/tentacle/Tentacle show-thumbprint --instance Tentacle
```

### Check in Octopus Deploy

1. Navigate to **Infrastructure → Deployment Targets**
2. Find your target by name (hostname)
3. Verify:
   - Status: Healthy (green)
   - Environment: Correct environment
   - Roles: Assigned roles visible
   - Last seen: Recent timestamp

### Health Check

Octopus automatically performs health checks. To manually trigger:

1. Go to **Infrastructure → Deployment Targets**
2. Select your target
3. Click **Check Health**

## Troubleshooting

### Tentacle Not Connecting

**Symptoms:** Target shows as "Offline" or "Unavailable" in Octopus

**Solutions:**

1. Check Tentacle service:
   ```bash
   sudo systemctl status tentacle
   sudo journalctl -u tentacle -n 50
   ```

2. Verify Octopus Server URL is accessible:
   ```bash
   curl -k https://octopus.example.com/api
   ```

3. Check Tentacle configuration:
   ```bash
   sudo /opt/octopus/tentacle/Tentacle show-configuration --instance Tentacle
   ```

4. Restart Tentacle:
   ```bash
   sudo systemctl restart tentacle
   ```

### Registration Failed

**Symptoms:** Ansible task fails during registration

**Solutions:**

1. Verify API key has correct permissions
2. Check `OCTOPUS_SERVER_URL` is correct and accessible
3. Ensure `OCTOPUS_SPACE_ID` exists
4. Verify environment name exists in Octopus

### Target Already Exists

**Symptoms:** Error message "already exists" during registration

**Solutions:**

This is expected if re-running the workflow. The role handles this gracefully and won't fail.

To force re-registration:

```bash
# On target VM
sudo /opt/octopus/tentacle/Tentacle deregister-from \
  --instance Tentacle \
  --server https://octopus.example.com \
  --apiKey API-XXXXXXXXXX

# Re-run workflow
```

### Port Conflicts (Listening Mode)

**Symptoms:** Tentacle fails to start, port already in use

**Solutions:**

1. Check what's using port 10933:
   ```bash
   sudo lsof -i :10933
   ```

2. Change Tentacle port in role defaults or via extra vars

### Network Connectivity Issues

**Symptoms:** Tentacle can't reach Octopus Server

**Solutions:**

1. Verify Tailscale is running:
   ```bash
   sudo tailscale status
   ```

2. Test connectivity:
   ```bash
   ping octopus.example.com
   curl -k https://octopus.example.com/api
   ```

3. Check firewall rules on both sides

## Advanced Configuration

### Custom Tentacle Port

Override in workflow:

```yaml
- name: Run Ansible with custom Tentacle port
  run: |
    ansible-playbook ... \
      --extra-vars "tentacle_port=10934"
```

### Multiple Spaces

Register targets in different spaces:

```yaml
# In Doppler, set per-config
OCTOPUS_SPACE_ID=Spaces-2

# Or override in workflow
--extra-vars "octopus_space_id=Spaces-2"
```

### Custom Installation Paths

Override in role defaults or via extra vars:

```yaml
tentacle_install_dir: "/opt/octopus/tentacle"
tentacle_app_dir: "/home/Octopus/Applications"
tentacle_config_dir: "/etc/octopus"
```

## Security Best Practices

1. **Use Polling Mode** - More secure, no inbound ports required
2. **Rotate API Keys** - Regularly rotate Octopus API keys
3. **Limit API Key Permissions** - Only grant necessary permissions
4. **Use Tailscale** - Keep Octopus Server on private network
5. **Monitor Tentacle Logs** - Watch for suspicious activity
6. **Keep Tentacle Updated** - Update Tentacle when new versions release

## Next Steps

After setting up Octopus integration:

1. Create deployment projects in Octopus
2. Configure deployment steps
3. Set up lifecycles and channels
4. Create releases and deploy applications
5. Monitor deployments in Octopus dashboard

## Resources

- [Octopus Deploy Documentation](https://octopus.com/docs)
- [Tentacle Documentation](https://octopus.com/docs/infrastructure/deployment-targets/tentacle)
- [API Documentation](https://octopus.com/docs/octopus-rest-api)
- [Polling Tentacles](https://octopus.com/docs/infrastructure/deployment-targets/tentacle/tentacle-communication#polling-tentacles)
