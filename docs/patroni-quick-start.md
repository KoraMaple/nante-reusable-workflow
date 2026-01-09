# Patroni HA Cluster - Quick Start Guide

This is a condensed guide for quickly deploying a 3-node Patroni PostgreSQL HA cluster using the reusable workflows.

## Prerequisites

- Proxmox environment with Ubuntu template
- 3 available static IPs (e.g., 192.168.10.51-53)
- Your own GitHub repository (caller repo)
- Doppler secrets configured in your caller repo

## Quick Deploy

### 1. Create Workflow in Your Repo

In your caller repository, create `.github/workflows/deploy-patroni.yml`:

```yaml
name: Deploy Patroni Cluster

on:
  workflow_dispatch:

jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    secrets: inherit
    with:
      app_name: patroni
      environment: prod
      vlan_tag: "10"
      cpu_cores: "2"
      ram_mb: "4096"
      disk_gb: "40G"
      instances: |
        {
          "node1": {"ip_address": "192.168.10.51"},
          "node2": {"ip_address": "192.168.10.52"},
          "node3": {"ip_address": "192.168.10.53"}
        }
```

### 2. Trigger Provisioning

```bash
gh workflow run deploy-patroni.yml
```

This creates 3 VMs with basic setup.

### 3. Create Inventory File

In your caller repo, create `inventory/patroni-cluster.ini`:

```ini
[all:vars]
ansible_user=deploy
etcd_cluster_token=patroni-cluster
patroni_scope=postgres-cluster
postgresql_version=15

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
```

### 4. Run Patroni Configuration

```bash
# Clone reusable workflow repo for Ansible roles
git clone https://github.com/KoraMaple/nante-reusable-workflow.git
cd nante-reusable-workflow/ansible

# Copy your inventory
cp /path/to/your/repo/inventory/patroni-cluster.ini inventory/

# Run playbook
ansible-playbook -i inventory/patroni-cluster.ini patroni-cluster.yml \
  -e "patroni_superuser_password=SECURE_PASSWORD" \
  -e "patroni_admin_password=SECURE_PASSWORD" \
  -e "patroni_replication_password=SECURE_PASSWORD"
```

### 5. Verify

```bash
# SSH to any node
ssh deploy@192.168.10.51

# Check cluster status
sudo -u postgres patronictl -c /etc/patroni/patroni.yml list

# Expected output:
# + Cluster: postgres-cluster (7123456789012345678) -----+----+-----------+
# | Member    | Host          | Role    | State   | TL | Lag in MB |
# +-----------+---------------+---------+---------+----+-----------+
# | patroni1  | 192.168.10.51 | Leader  | running |  1 |           |
# | patroni2  | 192.168.10.52 | Replica | running |  1 |         0 |
# | patroni3  | 192.168.10.53 | Replica | running |  1 |         0 |
# +-----------+---------------+---------+---------+----+-----------+
```

## Connect to PostgreSQL

```bash
# Connect to primary (read-write)
psql -h 192.168.10.51 -U admin -d postgres

# Connect to replica (read-only)
psql -h 192.168.10.52 -U admin -d postgres
```

## Test Failover

```bash
# Stop primary node
ssh deploy@192.168.10.51
sudo systemctl stop patroni

# Check cluster - a new leader should be elected
ssh deploy@192.168.10.52
sudo -u postgres patronictl -c /etc/patroni/patroni.yml list

# Restart original primary - it becomes a replica
ssh deploy@192.168.10.51
sudo systemctl start patroni
```

## Common Commands

```bash
# Check cluster status
sudo -u postgres patronictl -c /etc/patroni/patroni.yml list

# Manual switchover
sudo -u postgres patronictl -c /etc/patroni/patroni.yml switchover

# Check etcd health
ETCDCTL_API=3 etcdctl --endpoints=192.168.10.51:2379,192.168.10.52:2379,192.168.10.53:2379 endpoint health

# View Patroni logs
journalctl -u patroni -f

# View PostgreSQL logs
journalctl -u patroni -f | grep postgres

# Check replication status
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

## Ports Used

- **5432**: PostgreSQL
- **8008**: Patroni REST API
- **2379**: etcd client
- **2380**: etcd peer

## Troubleshooting

**Cluster won't start:**
```bash
# Check etcd on all nodes
systemctl status etcd

# Check Patroni logs
journalctl -u patroni -n 50
```

**Node won't rejoin:**
```bash
# Reinitialize the node
sudo systemctl stop patroni
sudo rm -rf /var/lib/postgresql/15/main/*
sudo systemctl start patroni
```

**Check connectivity:**
```bash
# Test etcd from each node
curl http://192.168.10.51:2379/health
curl http://192.168.10.52:2379/health
curl http://192.168.10.53:2379/health

# Test Patroni API
curl http://192.168.10.51:8008/health
```

## Next Steps

- Configure backups (pg_basebackup, WAL archiving)
- Set up monitoring (Prometheus, Grafana)
- Configure SSL/TLS for PostgreSQL
- Add connection pooling (PgBouncer)
- Review security settings

## Full Documentation

See `docs/patroni-ha-cluster.md` for complete documentation.
