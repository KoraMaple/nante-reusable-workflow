# Terraform Multi-Instance Support

The Terraform configuration has been updated to support deploying multiple VM or LXC instances in a single run, enabling cluster deployments.

## Overview

Previously, the Terraform configuration could only create one VM or LXC at a time. Now it supports two modes:

1. **Single Instance Mode** (backward compatible)
2. **Multi-Instance Mode** (for clusters)

## Single Instance Mode

This mode maintains backward compatibility with existing deployments.

```hcl
resource_type  = "vm"
vm_target_ip   = "<INTERNAL_IP_VLAN10>"
vm_cpu_cores   = "2"
vm_ram_mb      = "4096"
vm_disk_gb     = "20G"
app_name       = "myapp"
environment    = "prod"
vlan_tag       = "10"
```

## Multi-Instance Mode

Use the `instances` map to define multiple instances:

```hcl
resource_type = "vm"
app_name      = "patroni"
environment   = "prod"
vlan_tag      = "10"

instances = {
  node1 = {
    ip_address = "<INTERNAL_IP_VLAN10>"
    cpu_cores  = "2"      # optional, defaults to vm_cpu_cores
    ram_mb     = "4096"   # optional, defaults to vm_ram_mb
    disk_gb    = "40G"    # optional, defaults to vm_disk_gb
  }
  node2 = {
    ip_address = "<INTERNAL_IP_VLAN10>"
    cpu_cores  = "4"      # override default
    ram_mb     = "8192"
    disk_gb    = "60G"
  }
  node3 = {
    ip_address = "<INTERNAL_IP_VLAN10>"
    # Uses defaults for cpu_cores, ram_mb, disk_gb
  }
}
```

## Hostname Generation

### Single Instance Mode
Hostnames are generated with a random suffix:
```
${app_name}-${environment}-${random_hex}
# Example: patroni-prod-a1b2
```

### Multi-Instance Mode
Hostnames use the instance key:
```
${app_name}-${environment}-${instance_key}
# Example: patroni-prod-node1, patroni-prod-node2, patroni-prod-node3
```

## Outputs

Outputs have been updated to return maps instead of single values:

### VM Outputs
```hcl
output "vm_ids" {
  # Returns: { "node1" = 100, "node2" = 101, "node3" = 102 }
}

output "vm_hostnames" {
  # Returns: { "node1" = "patroni-prod-node1", ... }
}

output "vm_target_ips" {
  # Returns: { "node1" = "<INTERNAL_IP_VLAN10>", ... }
}
```

### LXC Outputs
```hcl
output "lxc_ids" {
  # Returns: { "node1" = 200, "node2" = 201, "node3" = 202 }
}

output "lxc_hostnames" {
  # Returns: { "node1" = "patroni-prod-node1", ... }
}

output "lxc_ips" {
  # Returns: { "node1" = "<INTERNAL_IP_VLAN10>", ... }
}
```

## Resource Configuration

Each instance in the `instances` map can override default resource settings:

```hcl
# Set defaults for all instances
vm_cpu_cores = "2"
vm_ram_mb    = "4096"
vm_disk_gb   = "20G"

instances = {
  # Small node - uses defaults
  node1 = {
    ip_address = "<INTERNAL_IP_VLAN10>"
  }
  
  # Large node - overrides defaults
  node2 = {
    ip_address = "<INTERNAL_IP_VLAN10>"
    cpu_cores  = "8"
    ram_mb     = "16384"
    disk_gb    = "100G"
  }
}
```

## Using with GitHub Actions

When using GitHub Actions workflows, pass the `instances` parameter as JSON:

```yaml
jobs:
  provision:
    uses: ./.github/workflows/terraform-provision.yml
    with:
      app_name: patroni
      environment: prod
      instances: |
        {
          "node1": {
            "ip_address": "<INTERNAL_IP_VLAN10>",
            "cpu_cores": "2",
            "ram_mb": "4096",
            "disk_gb": "40G"
          },
          "node2": {
            "ip_address": "<INTERNAL_IP_VLAN10>",
            "cpu_cores": "2",
            "ram_mb": "4096",
            "disk_gb": "40G"
          }
        }
```

## Migration from Single to Multi-Instance

If you have existing single-instance deployments and want to add more nodes:

1. **Keep existing node** by adding it to the instances map with the same IP
2. **Add new nodes** with different IPs
3. **Run terraform plan** to see what will be created
4. **Apply changes**

Example:
```hcl
# Before (single instance)
vm_target_ip = "<INTERNAL_IP_VLAN10>"

# After (multi-instance, preserving existing)
instances = {
  existing = {
    ip_address = "<INTERNAL_IP_VLAN10>"  # Same IP as before
  }
  node2 = {
    ip_address = "<INTERNAL_IP_VLAN10>"  # New node
  }
  node3 = {
    ip_address = "<INTERNAL_IP_VLAN10>"  # New node
  }
}
```

**Note:** The hostname will change from `app-env-random` to `app-env-existing`, which will cause Terraform to recreate the resource. To avoid this, you may need to use `terraform state mv` to rename the resource in state.

## Limitations

- Maximum 10 instances per deployment (configurable via `instance_count` validation)
- All instances must be in the same VLAN
- All instances use the same template and storage pool
- Instance keys must be valid Terraform map keys (alphanumeric and underscores)

## Examples

See the following examples for complete configurations:

- `examples/patroni-cluster.tfvars.example` - 3-node Patroni cluster
- `examples/caller-provision-patroni-cluster.yml` - GitHub Actions workflow

## Terraform State

With multi-instance mode, resources are stored in state with keys:

```
# Single instance mode
proxmox_vm_qemu.generic_vm["default"]

# Multi-instance mode
proxmox_vm_qemu.generic_vm["node1"]
proxmox_vm_qemu.generic_vm["node2"]
proxmox_vm_qemu.generic_vm["node3"]
```

This allows Terraform to manage each instance independently.
