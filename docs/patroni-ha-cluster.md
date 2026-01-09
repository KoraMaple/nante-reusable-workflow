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
   - 3 static IP addresses (e.g., 192.168.10.51-53)
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
          "node1": {"ip_address": "192.168.10.51"},
          "node2": {"ip_address": "192.168.10.52"},
          "node3": {"ip_address": "192.168.10.53"}
        }
```

**Note:** The `instances` parameter is a JSON string. Each instance inherits the default `cpu_cores`, `ram_mb`, and `disk_gb` values unless overridden:

```yaml
instances: |
  {
    "node1": {"ip_address": "192.168.10.51"},
    "node2": {
      "ip_address": "192.168.10.52",
      "cpu_cores": "4",
      "ram_mb": "8192"
    },
    "node3": {"ip_address": "192.168.10.53"}
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
3. Run basic Ansible setup (base_setup role)

After provisioning completes, the VMs are ready for Patroni configuration.

### 3. Configure Patroni Cluster

After infrastructure is provisioned, configure the Patroni cluster using Ansible.

**In your caller repository**, create an inventory file `inventory/patroni-cluster.ini`:

```ini
[all:vars]
ansible_user=deploy
ansible_become=yes
ansible_python_interpreter=/usr/bin/python3

# etcd cluster configuration
etcd_cluster_token=patroni-cluster
etcd_cluster_state=new

# Patroni configuration
patroni_scope=postgres-cluster
patroni_namespace=/service/
postgresql_version=15

# CHANGE THESE PASSWORDS IN PRODUCTION!
patroni_superuser_password=changeme_superuser
patroni_admin_password=changeme_admin
patroni_replication_password=changeme_replication

[etcd]
patroni-prod-node1 ansible_host=192.168.10.51 etcd_node_name=etcd1
patroni-prod-node2 ansible_host=192.168.10.52 etcd_node_name=etcd2
patroni-prod-node3 ansible_host=192.168.10.53 etcd_node_name=etcd3

[patroni]
patroni-prod-node1 ansible_host=192.168.10.51 patroni_node_name=patroni1
patroni-prod-node2 ansible_host=192.168.10.52 patroni_node_name=patroni2
patroni-prod-node3 ansible_host=192.168.10.53 patroni_node_name=patroni3

[etcd:vars]
etcd_initial_cluster=etcd1=http://192.168.10.51:2380,etcd2=http://192.168.10.52:2380,etcd3=http://192.168.10.53:2380

[patroni:vars]
etcd_cluster_endpoints=192.168.10.51:2379,192.168.10.52:2379,192.168.10.53:2379
patroni_data_dir=/var/lib/postgresql/15/main
```

### 4. Run Patroni Playbook

**Clone the reusable workflow repository** to access the Ansible roles:

```bash
git clone https://github.com/KoraMaple/nante-reusable-workflow.git
cd nante-reusable-workflow/ansible

# Copy your inventory file
cp /path/to/your/repo/inventory/patroni-cluster.ini inventory/

# Run the playbook
ansible-playbook -i inventory/patroni-cluster.ini patroni-cluster.yml \
  -e "patroni_superuser_password=YOUR_SECURE_PASSWORD" \
  -e "patroni_admin_password=YOUR_SECURE_PASSWORD" \
  -e "patroni_replication_password=YOUR_SECURE_PASSWORD"
```

**Or use Ansible from your own repository** by copying the roles:

```bash
# In your caller repository
mkdir -p ansible/roles
cp -r /path/to/nante-reusable-workflow/ansible/roles/etcd ansible/roles/
cp -r /path/to/nante-reusable-workflow/ansible/roles/patroni ansible/roles/
cp /path/to/nante-reusable-workflow/ansible/patroni-cluster.yml ansible/

# Run from your repo
cd ansible
ansible-playbook -i inventory/patroni-cluster.ini patroni-cluster.yml
```

### 5. Verify Cluster Status

SSH into any node and check the cluster status:

```bash
# Check Patroni cluster
sudo -u postgres patronictl -c /etc/patroni/patroni.yml list

# Check etcd cluster health
ETCDCTL_API=3 etcdctl --endpoints=192.168.10.51:2379,192.168.10.52:2379,192.168.10.53:2379 endpoint health

# Check PostgreSQL replication
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

## Cluster Management

### Connect to PostgreSQL

**Primary node (read-write):**
```bash
psql -h 192.168.10.51 -U admin -d postgres
```

**Any replica (read-only):**
```bash
psql -h 192.168.10.52 -U admin -d postgres
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

To scale the cluster, update the `instances` map in Terraform and re-run:
```bash
terraform apply -var-file=patroni-cluster.tfvars
```

Then update the Ansible inventory and run the playbook for the new nodes.

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
