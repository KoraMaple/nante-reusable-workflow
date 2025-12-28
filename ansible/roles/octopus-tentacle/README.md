# Octopus Tentacle Role

Ansible role to install and configure Octopus Deploy Tentacle agent on Linux servers, registering them as deployment targets in Octopus Deploy.

## Description

This role:
- Installs Octopus Tentacle on Ubuntu/Debian systems
- Configures Tentacle in Polling or Listening mode
- Registers the target with Octopus Server
- Assigns environment, roles, and tenants
- Sets up systemd service for automatic startup

## Requirements

- Ubuntu 20.04+ or Debian 10+
- Network connectivity to Octopus Server
- Octopus Server API key with appropriate permissions

## Role Variables

### Required Variables (from Doppler)

```yaml
octopus_server_url: "https://octopus.example.com"  # Octopus Server URL
octopus_api_key: "API-XXXXXXXXXX"                  # Octopus API key
```

### Optional Variables

```yaml
# Octopus configuration
octopus_space_id: "Spaces-1"                       # Octopus Space ID (default: Spaces-1)
octopus_environment: "Development"                 # Environment name (default: Development)

# Tentacle configuration
tentacle_instance_name: "Tentacle"                 # Instance name (default: Tentacle)
tentacle_port: 10933                               # Tentacle port (default: 10933)
tentacle_communication_mode: "Polling"             # Polling or Listening (default: Polling)

# Target configuration
target_name: "{{ inventory_hostname }}"            # Target name in Octopus
target_roles: []                                   # List of roles (e.g., ['web-server', 'docker-host'])
target_tenants: []                                 # List of tenants (for multi-tenancy)

# Installation paths
tentacle_install_dir: "/opt/octopus/tentacle"
tentacle_app_dir: "/home/Octopus/Applications"
tentacle_config_dir: "/etc/octopus"
```

## Communication Modes

### Polling Mode (Recommended)
- Tentacle initiates connection to Octopus Server
- No inbound firewall rules required on target
- Better for security and NAT scenarios
- Default mode

### Listening Mode
- Octopus Server connects to Tentacle
- Requires inbound firewall rule on port 10933
- Useful for on-premises scenarios

## Dependencies

None. This role is self-contained.

## Example Playbook

### Basic Usage (Polling Mode)

```yaml
- hosts: servers
  become: true
  vars:
    octopus_server_url: "{{ lookup('env', 'OCTOPUS_SERVER_URL') }}"
    octopus_api_key: "{{ lookup('env', 'OCTOPUS_API_KEY') }}"
    octopus_environment: "Production"
  roles:
    - octopus-tentacle
```

### With Roles and Tenants

```yaml
- hosts: web_servers
  become: true
  vars:
    octopus_server_url: "{{ lookup('env', 'OCTOPUS_SERVER_URL') }}"
    octopus_api_key: "{{ lookup('env', 'OCTOPUS_API_KEY') }}"
    octopus_environment: "Production"
    target_roles:
      - web-server
      - nginx
    target_tenants:
      - customer-a
      - customer-b
  roles:
    - octopus-tentacle
```

### Listening Mode

```yaml
- hosts: servers
  become: true
  vars:
    octopus_server_url: "{{ lookup('env', 'OCTOPUS_SERVER_URL') }}"
    octopus_api_key: "{{ lookup('env', 'OCTOPUS_API_KEY') }}"
    tentacle_communication_mode: "Listening"
    tentacle_port: 10933
  roles:
    - octopus-tentacle
```

## Usage in Workflows

### With reusable-provision.yml

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
    with:
      app_name: "myapp"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.50"
      app_role: "nginx"
      octopus_environment: "Production"
      octopus_roles: "web-server,nginx"
    secrets: inherit
```

### With reusable-onboard.yml

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@main
    with:
      target_ip: "192.168.20.100"
      ssh_user: "deploy"
      target_hostname: "docker-mgmt"
      app_role: "mgmt-docker"
      octopus_environment: "Development"
      octopus_roles: "docker-host"
    secrets: inherit
```

## Doppler Secrets Required

Add these secrets to your Doppler project:

```bash
OCTOPUS_SERVER_URL=https://octopus.example.com
OCTOPUS_API_KEY=API-XXXXXXXXXX
OCTOPUS_SPACE_ID=Spaces-1
OCTOPUS_ENVIRONMENT=Development
```

## Verification

After running the role, verify the Tentacle is registered:

```bash
# Check Tentacle service status
sudo systemctl status tentacle

# Check Tentacle configuration
sudo /opt/octopus/tentacle/Tentacle show-configuration --instance Tentacle

# Check Tentacle thumbprint
sudo /opt/octopus/tentacle/Tentacle show-thumbprint --instance Tentacle
```

In Octopus Deploy:
1. Navigate to Infrastructure → Deployment Targets
2. Find your target by name
3. Verify it's in the correct environment
4. Check assigned roles and health status

## Troubleshooting

### Tentacle not connecting (Polling mode)

```bash
# Check Tentacle logs
sudo journalctl -u tentacle -f

# Test connectivity to Octopus Server
curl -k https://octopus.example.com/api

# Verify Tentacle configuration
sudo /opt/octopus/tentacle/Tentacle show-configuration --instance Tentacle
```

### Registration failed

- Verify `OCTOPUS_API_KEY` has appropriate permissions
- Check `OCTOPUS_SERVER_URL` is accessible from target
- Ensure `OCTOPUS_SPACE_ID` exists
- Verify environment name matches Octopus configuration

### Service won't start

```bash
# Check service status
sudo systemctl status tentacle

# Check for errors
sudo journalctl -u tentacle -n 50

# Restart service
sudo systemctl restart tentacle
```

### Re-register Tentacle

If you need to re-register with different settings:

```bash
# Stop service
sudo systemctl stop tentacle

# Deregister
sudo /opt/octopus/tentacle/Tentacle deregister-from \
  --instance Tentacle \
  --server https://octopus.example.com \
  --apiKey API-XXXXXXXXXX

# Re-run Ansible role
```

## License

MIT

## Author

KoraMaple
