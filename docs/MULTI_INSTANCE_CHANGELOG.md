# Multi-Instance Support - Changelog

## Overview

The Terraform configuration has been refactored to support deploying multiple VM/LXC instances in a single Terraform run, enabling cluster deployments like Patroni HA PostgreSQL clusters.

## Changes Made

### Terraform Configuration

#### `variables.tf`
- **Modified** `vm_target_ip`: Made optional (default empty string) for backward compatibility
- **Added** `instances`: Map variable for defining multiple instances with individual configurations
- **Added** `instance_count`: Validation variable (1-10 instances)

#### `main.tf`
- **Refactored** `random_id.vm_suffix`: Changed from single resource to `for_each` loop
- **Added** `local.use_multi_instance`: Boolean flag to determine deployment mode
- **Added** `local.instance_map`: Unified map for both single and multi-instance modes
- **Added** `local.vm_hostnames`: Map of generated hostnames per instance
- **Refactored** `proxmox_vm_qemu.generic_vm`: Changed from `count` to `for_each` for multi-instance support
- **Updated** resource references to use `each.key` and `each.value`

#### `lxc.tf`
- **Refactored** `proxmox_lxc.container`: Changed from `count` to `for_each`
- **Updated** all outputs to return maps instead of single values
- **Added** `lxc_ids`, `lxc_ips`, `lxc_hostnames` map outputs

#### `outputs.tf`
- **Replaced** `vm_id` with `vm_ids` (map output)
- **Replaced** `resource_id` with `resource_ids` (map output)
- **Replaced** `vm_target_ip` with `vm_target_ips` (map output)
- **Replaced** `vm_hostname` with `vm_hostnames` (map output)

### Ansible Roles

#### New Role: `etcd`
- **Created** complete etcd role for distributed consensus
- **Files**:
  - `tasks/main.yml`: Installation and configuration tasks
  - `templates/etcd.conf.yml.j2`: etcd configuration template
  - `templates/etcd.service.j2`: systemd service file
  - `handlers/main.yml`: Service restart handlers
  - `defaults/main.yml`: Default variables

#### New Role: `patroni`
- **Created** complete Patroni role for PostgreSQL HA
- **Files**:
  - `tasks/main.yml`: PostgreSQL and Patroni installation
  - `templates/patroni.yml.j2`: Patroni configuration with bootstrap settings
  - `templates/patroni.service.j2`: systemd service file
  - `handlers/main.yml`: Service restart handlers
  - `defaults/main.yml`: Default variables and passwords

### Playbooks

#### `patroni-cluster.yml`
- **Created** main playbook for deploying 3-node Patroni cluster
- **Includes**:
  - Common package installation
  - etcd cluster configuration
  - Patroni PostgreSQL cluster setup
  - Cluster health verification

### Inventory

#### `inventory/patroni-cluster.ini`
- **Created** example inventory for 3-node cluster
- **Defines**:
  - etcd group with 3 nodes
  - patroni group with 3 nodes
  - Cluster-wide variables
  - Node-specific variables

### Documentation

#### `docs/patroni-ha-cluster.md`
- **Created** comprehensive deployment guide
- **Covers**:
  - Architecture overview
  - Prerequisites and network requirements
  - Step-by-step deployment instructions
  - Cluster management commands
  - Monitoring and troubleshooting
  - Security considerations
  - Backup and recovery strategies

#### `docs/terraform-multi-instance.md`
- **Created** detailed Terraform multi-instance documentation
- **Covers**:
  - Single vs multi-instance modes
  - Configuration examples
  - Hostname generation logic
  - Output structure changes
  - Migration guide
  - GitHub Actions integration

#### `docs/patroni-quick-start.md`
- **Created** quick reference guide
- **Includes**:
  - Condensed deployment steps
  - Common commands
  - Troubleshooting tips
  - Testing procedures

### Examples

#### `examples/patroni-cluster.tfvars.example`
- **Created** example Terraform variables file
- **Shows** multi-instance configuration for 3-node cluster

#### `examples/caller-provision-patroni-cluster.yml`
- **Created** example GitHub Actions workflow
- **Demonstrates** provision, configure, and destroy actions

## Breaking Changes

### Outputs Structure
**Before:**
```hcl
output "vm_id" {
  value = 100
}
output "vm_hostname" {
  value = "app-prod-a1b2"
}
```

**After:**
```hcl
output "vm_ids" {
  value = { "node1" = 100, "node2" = 101 }
}
output "vm_hostnames" {
  value = { "node1" = "app-prod-node1", "node2" = "app-prod-node2" }
}
```

### Resource References in State
**Before:**
```
proxmox_vm_qemu.generic_vm[0]
```

**After:**
```
proxmox_vm_qemu.generic_vm["default"]  # single instance
proxmox_vm_qemu.generic_vm["node1"]    # multi-instance
```

## Backward Compatibility

The changes maintain backward compatibility with existing single-instance deployments:

- If `instances` is empty, the configuration uses `vm_target_ip` (single instance mode)
- Single instance mode generates hostnames with random suffix (same as before)
- All existing variables continue to work as defaults

## Migration Path

For existing deployments:

1. **No changes needed** if continuing with single instance
2. **To add nodes**: Define `instances` map with existing IP as one of the nodes
3. **State migration**: May need `terraform state mv` to avoid resource recreation

## Testing Recommendations

1. Test single instance mode to ensure backward compatibility
2. Test multi-instance mode with 2-3 instances
3. Verify outputs are correctly formatted as maps
4. Test Ansible playbook on fresh VMs
5. Verify cluster failover functionality
6. Test with both VM and LXC resource types

## Future Enhancements

Potential improvements for future versions:

- Support for different templates per instance
- Support for different storage pools per instance
- Support for different VLAN tags per instance
- HAProxy role for load balancing
- Automated backup configuration
- Monitoring stack (Prometheus/Grafana) integration
- SSL/TLS configuration for PostgreSQL
- PgBouncer connection pooling role

## Version Information

- **Terraform Provider**: proxmox 2.x
- **PostgreSQL Version**: 15 (configurable)
- **Patroni Version**: Latest from pip
- **etcd Version**: 3.5.11 (configurable)
- **Supported OS**: Ubuntu 22.04/24.04
