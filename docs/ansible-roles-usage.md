# Ansible Roles Usage Guide

This guide explains how to use the `ansible_roles` parameter in reusable workflows to apply multiple Ansible roles in a single workflow run.

## Overview

The reusable workflows (`reusable-provision.yml` and `reusable-onboard.yml`) now support applying multiple Ansible roles through the `ansible_roles` parameter. This allows you to configure infrastructure with multiple capabilities in a single deployment.

## Default Behavior

### Roles That Always Run

1. **`base_setup`** - Runs by default on all VMs/LXCs unless `mgmt-docker` is specified
   - Sets hostname
   - Installs essential packages
   - Configures Tailscale VPN
   - Installs Grafana Alloy for observability
   - Installs Octopus Tentacle (if configured)

2. **`ldap-config`** - Runs automatically if FreeIPA credentials are available
   - Enrolls VM/LXC with FreeIPA LDAP
   - Configures SSSD for centralized authentication

### Special Cases

- **`mgmt-docker`** - Replaces `base_setup` entirely (has its own complete Alloy config)
- **`freeipa`** - Skips `ldap-config` (FreeIPA server doesn't enroll with itself)

## Usage Examples

### Single Role Deployment

Deploy a VM with nginx:

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: webserver
      environment: prod
      vlan_tag: "10"
      vm_target_ip: "192.168.10.50"
      ansible_roles: "nginx"
```

**Roles applied:** `base_setup` → `ldap-config` → `nginx`

### Multiple Roles Deployment

Deploy a VM with both nginx and custom application:

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: appserver
      environment: prod
      vlan_tag: "10"
      vm_target_ip: "192.168.10.51"
      ansible_roles: "nginx,myapp"
```

**Roles applied:** `base_setup` → `ldap-config` → `nginx` → `myapp`

### Docker Host with Monitoring

Deploy a Docker host with container monitoring:

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: docker-host
      environment: prod
      vlan_tag: "10"
      vm_target_ip: "192.168.10.52"
      ansible_roles: "mgmt-docker"
```

**Roles applied:** `mgmt-docker` → `ldap-config`

Note: `base_setup` is skipped because `mgmt-docker` provides its own complete setup.

### Multi-Instance with Different Roles

Deploy 3 VMs with different role configurations:

```yaml
jobs:
  provision-web:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: web
      environment: prod
      vlan_tag: "10"
      vm_target_ip: "192.168.10.60"
      ansible_roles: "nginx"

  provision-app:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: app
      environment: prod
      vlan_tag: "10"
      vm_target_ip: "192.168.10.61"
      ansible_roles: "myapp,redis"

  provision-docker:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: docker
      environment: prod
      vlan_tag: "10"
      vm_target_ip: "192.168.10.62"
      ansible_roles: "mgmt-docker"
```

### No Additional Roles (Base Setup Only)

Deploy a VM with only base configuration:

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: basevm
      environment: dev
      vlan_tag: "20"
      vm_target_ip: "192.168.20.50"
      # ansible_roles is empty - only base_setup and ldap-config run
```

**Roles applied:** `base_setup` → `ldap-config`

## Role Execution Order

Roles are always applied in this order:

1. **`base_setup`** (unless `mgmt-docker` is specified)
2. **`ldap-config`** (if FreeIPA credentials available and not `freeipa` role)
3. **Custom roles** (from `ansible_roles` parameter, in order specified)

## Available Roles

### Infrastructure Roles
- **`base_setup`** - Core system configuration (automatic)
- **`mgmt-docker`** - Docker host with monitoring (replaces base_setup)
- **`ldap-config`** - LDAP client enrollment (automatic)

### Application Roles
- **`nginx`** - Web server
- **`freeipa`** - Identity management server
- **`etcd`** - Distributed key-value store
- **`patroni`** - PostgreSQL HA cluster
- **`octopus-tentacle`** - Octopus Deploy agent (included in base_setup)

### Future Roles
- **`k3s-cluster`** - Kubernetes cluster
- **`app-deploy`** - Application deployment

## Using with Onboard Workflow

The `reusable-onboard.yml` workflow also supports `ansible_roles`:

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@develop
    secrets: inherit
    with:
      target_ip: "192.168.10.100"
      ssh_user: "deploy"
      target_hostname: "existing-server"
      ansible_roles: "nginx,myapp"
```

## Direct Ansible Usage

If running Ansible directly (not through workflows):

```bash
# Single role
ansible-playbook -i "192.168.10.50," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp" \
  --extra-vars 'ansible_roles=["nginx"]'

# Multiple roles
ansible-playbook -i "192.168.10.50," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp" \
  --extra-vars 'ansible_roles=["nginx","mgmt-docker"]'

# No custom roles (base setup only)
ansible-playbook -i "192.168.10.50," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp"
```

## Best Practices

1. **Order Matters**: List roles in dependency order (e.g., database before application)
2. **Use mgmt-docker for Docker Hosts**: Don't combine `base_setup` with `mgmt-docker`
3. **Keep Roles Focused**: Each role should have a single responsibility
4. **Test Individually**: Test each role independently before combining
5. **Document Dependencies**: If your role depends on another, document it in the role's README

## Troubleshooting

### Role Not Found
```
ERROR! the role 'myrole' was not found
```
**Solution:** Ensure the role exists in `ansible/roles/` directory

### Role Runs Twice
If you see a role executing twice, check:
- Is it in `ansible_roles` AND hardcoded in `site.yml`?
- Remove it from one location

### Base Setup Skipped Unexpectedly
If `base_setup` isn't running:
- Check if `mgmt-docker` is in your `ansible_roles` list
- `mgmt-docker` replaces `base_setup` by design

### LDAP Config Not Running
If `ldap-config` isn't running:
- Verify FreeIPA credentials are in Doppler
- Check if `freeipa` role is in `ansible_roles` (it skips ldap-config)

## Migration from app_role_name

**Old approach (deprecated):**
```yaml
with:
  app_name: webserver
  # app_name was used as the role name
```

**New approach:**
```yaml
with:
  app_name: webserver  # Just the application identifier
  ansible_roles: "nginx"  # Explicit role specification
```

This separation allows:
- Multiple roles per deployment
- Clear distinction between app name and roles
- Better flexibility in infrastructure configuration
