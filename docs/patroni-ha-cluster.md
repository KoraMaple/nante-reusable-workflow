# Patroni HA PostgreSQL Cluster Deployment Guide

This guide explains how to deploy a 3-node Patroni High Availability PostgreSQL cluster with etcd for distributed consensus.

## Architecture Overview

The cluster consists of:
- **3 PostgreSQL nodes** managed by Patroni for automatic failover
- **3 etcd nodes** (co-located on the same VMs) for distributed configuration and leader election
- **Automatic failover** when the primary node fails
- **Streaming replication** between PostgreSQL instances

## Prerequisites

1. **Proxmox Environment**
   - Proxmox host with sufficient resources
   - VM template (Ubuntu 22.04 or 24.04 recommended)
   - Available IP addresses in your VLAN

2. **Network Requirements**
   - 3 static IP addresses (e.g., <INTERNAL_IP_VLAN10>-53)
   - Ports required:
     - PostgreSQL: 5432
     - Patroni REST API: 8008
     - etcd client: 2379
     - etcd peer: 2380

3. **Secrets Configuration**
   Set these as GitHub secrets or environment variables:
   - `PATRONI_SUPERUSER_PASSWORD`
   - `PATRONI_ADMIN_PASSWORD`
   - `PATRONI_REPLICATION_PASSWORD`
   - `PROXMOX_API_TOKEN_ID`
   - `PROXMOX_API_TOKEN_SECRET`
   - `SSH_PUBLIC_KEY`

## Deployment Steps

### 1. Create Caller Workflow in Your Repository

This repository provides **reusable workflows**. In your own repository, create a workflow that calls the reusable provision workflow.

Create `.github/workflows/deploy-patroni-cluster.yml` in your caller repository:

```yaml
name: Deploy Patroni HA Cluster

on:
  workflow_dispatch:

jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: patroni
      environment: prod
      resource_type: vm
      vlan_tag: "10"
      cpu_cores: "2"
      ram_mb: "4096"
      disk_gb: "40G"
      # Multi-instance configuration for 3-node cluster
      instances: |
        {
          "node1": {"ip_address": "<INTERNAL_IP_VLAN10>"},
          "node2": {"ip_address": "<INTERNAL_IP_VLAN10>"},
          "node3": {"ip_address": "<INTERNAL_IP_VLAN10>"}
        }
      ansible_roles: "etcd,patroni"
```

**Note:** The `instances` parameter is a JSON string. Each instance inherits the default `cpu_cores`, `ram_mb`, and `disk_gb` values unless overridden:

```yaml
instances: |
  {
    "node1": {"ip_address": "<INTERNAL_IP_VLAN10>"},
    "node2": {
      "ip_address": "<INTERNAL_IP_VLAN10>",
      "cpu_cores": "4",
      "ram_mb": "8192"
    },
    "node3": {"ip_address": "<INTERNAL_IP_VLAN10>"}
  }
```

### 2. Provision Infrastructure

Trigger the workflow from your caller repository:

```bash
# From GitHub UI: Actions > Deploy Patroni HA Cluster > Run workflow
# Or via gh CLI:
gh workflow run deploy-patroni-cluster.yml
```

The reusable workflow will:
1. Create 3 VMs using Terraform with the specified IPs
2. Wait for VMs to boot
3. Run Ansible configuration:
   - `base_setup` role (Tailscale, Alloy, system config)
   - `ldap-config` role (FreeIPA LDAP enrollment, if credentials available)
   - `etcd` role (distributed consensus cluster)
   - `patroni` role (PostgreSQL HA cluster)

The entire cluster is provisioned and configured in a single workflow run!

### 3. Configure Secrets in Doppler

Ensure these secrets are set in your Doppler project/config:

```bash
# PostgreSQL passwords (required by patroni role)
PATRONI_SUPERUSER_PASSWORD=your_secure_superuser_password
PATRONI_ADMIN_PASSWORD=your_secure_admin_password
PATRONI_REPLICATION_PASSWORD=your_secure_replication_password

# Cluster configuration (optional, defaults shown)
PATRONI_SCOPE=postgres-cluster
PATRONI_NAMESPACE=/service/
POSTGRESQL_VERSION=15
ETCD_CLUSTER_TOKEN=patroni-cluster
```

The Ansible roles will automatically pull these from the environment during workflow execution.

### 4. Verify Cluster Status

SSH into any node and check the cluster status:

```bash
# Check Patroni cluster
sudo -u postgres patronictl -c /etc/patroni/patroni.yml list

# Check etcd cluster health
ETCDCTL_API=3 etcdctl --endpoints=<INTERNAL_IP_VLAN10>:2379,<INTERNAL_IP_VLAN10>:2379,<INTERNAL_IP_VLAN10>:2379 endpoint health

# Check PostgreSQL replication
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

## Cluster Management

### Connect to PostgreSQL

**Primary node (read-write):**
```bash
psql -h <INTERNAL_IP_VLAN10> -U admin -d postgres
```

**Any replica (read-only):**
```bash
psql -h <INTERNAL_IP_VLAN10> -U admin -d postgres
```

### Manual Failover

```bash
# Failover to a specific node
sudo -u postgres patronictl -c /etc/patroni/patroni.yml failover

# Switchover (graceful)
sudo -u postgres patronictl -c /etc/patroni/patroni.yml switchover
```

### Restart a Node

```bash
# Restart Patroni (PostgreSQL will be restarted by Patroni)
sudo systemctl restart patroni

# Restart etcd
sudo systemctl restart etcd
```

### Add/Remove Nodes

To scale the cluster, update the `instances` map in your workflow and re-run:

```yaml
instances: |  
  {
    "node1": {"ip_address": "<INTERNAL_IP_VLAN10>"},
    "node2": {"ip_address": "<INTERNAL_IP_VLAN10>"},
    "node3": {"ip_address": "<INTERNAL_IP_VLAN10>"},
    "node4": {"ip_address": "<INTERNAL_IP_VLAN10>"}  # New node
  }
```

The workflow will provision the new node and configure it with etcd and Patroni roles automatically.

## Monitoring

### Health Checks

- **Patroni REST API**: `http://<node-ip>:8008/health`
- **etcd health**: `etcdctl endpoint health`
- **PostgreSQL**: Standard monitoring tools (pg_stat_replication, etc.)

### Log Locations

- **Patroni logs**: `journalctl -u patroni -f`
- **PostgreSQL logs**: `/var/log/postgresql/postgresql-15-main.log`
- **etcd logs**: `journalctl -u etcd -f`

## Troubleshooting

### Cluster won't start
1. Check etcd is running on all nodes: `systemctl status etcd`
2. Verify etcd cluster health: `etcdctl endpoint health`
3. Check Patroni logs: `journalctl -u patroni -f`

### Split-brain scenario
Patroni uses etcd for distributed consensus, which prevents split-brain. If you suspect issues:
1. Check etcd cluster has quorum (2/3 nodes minimum)
2. Verify network connectivity between nodes
3. Check Patroni can reach etcd: `curl http://localhost:2379/health`

### Node won't rejoin after failure
1. Check if PostgreSQL data is corrupted
2. Patroni will automatically try to use pg_rewind
3. If that fails, you may need to reinitialize the node:
```bash
sudo systemctl stop patroni
sudo rm -rf /var/lib/postgresql/15/main/*
sudo systemctl start patroni
```

## Security Considerations

1. **Change default passwords** in production
2. **Configure pg_hba.conf** to restrict access by IP
3. **Use SSL/TLS** for PostgreSQL connections (not configured by default)
4. **Firewall rules** to restrict access to etcd and Patroni REST API
5. **Regular backups** using pg_basebackup or WAL archiving

## Performance Tuning

The default configuration is suitable for small to medium workloads. For production:

1. **Adjust PostgreSQL parameters** in `roles/patroni/templates/patroni.yml.j2`
2. **Tune etcd** for your workload (usually defaults are fine)
3. **Monitor replication lag**: `SELECT * FROM pg_stat_replication;`
4. **Consider connection pooling** (PgBouncer) for high-connection workloads

## Backup and Recovery

### Backup Strategy

1. **WAL archiving** (recommended for production)
2. **pg_basebackup** for full backups
3. **Patroni callbacks** for automated backup triggers

### Recovery

Patroni handles most recovery scenarios automatically. For disaster recovery:
1. Restore from backup to a new node
2. Configure as a replica
3. Let Patroni handle the rest

## References

- [Patroni Documentation](https://patroni.readthedocs.io/)
- [etcd Documentation](https://etcd.io/docs/)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/current/high-availability.html)
