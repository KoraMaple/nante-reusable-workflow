# HAProxy Deployment Guide

## Overview

HAProxy is deployed as a separate LXC container to load balance connections to a Patroni PostgreSQL HA cluster. It must be configured with the IP addresses of the Patroni backend nodes.

## Prerequisites

1. **Patroni Cluster Deployed**: You must have a running Patroni cluster (typically 3 nodes)
2. **Network Access**: HAProxy LXC must be able to reach Patroni nodes on:
   - Port 5432 (PostgreSQL)
   - Port 8008 (Patroni REST API for health checks)

## Deployment

### Step 1: Deploy HAProxy LXC Container

Use the workflow with `resource_type: lxc` and `ansible_roles: haproxy`:

```yaml
resource_type: lxc
ansible_roles: haproxy
lxc_unprivileged: false  # Set to true for unprivileged, requires manual TUN setup
```

### Step 2: Pass Patroni Backend IPs

**CRITICAL**: You must pass the `patroni_backends` variable with your Patroni node IPs.

#### Option 1: Via Workflow Extra Vars (Recommended)

Add to your workflow caller:

```yaml
ansible_extra_vars: |
  patroni_backends=[
    {'name':'patroni-node1','ip':'<INTERNAL_IP_VLAN20>'},
    {'name':'patroni-node2','ip':'<INTERNAL_IP_VLAN20>'},
    {'name':'patroni-node3','ip':'<INTERNAL_IP_VLAN20>'}
  ]
```

#### Option 2: Via Ansible Playbook

If running Ansible directly:

```bash
ansible-playbook -i inventory site.yml \
  --extra-vars "ansible_roles=['haproxy']" \
  --extra-vars "patroni_backends=[{'name':'patroni-node1','ip':'<INTERNAL_IP_VLAN20>'},{'name':'patroni-node2','ip':'<INTERNAL_IP_VLAN20>'},{'name':'patroni-node3','ip':'<INTERNAL_IP_VLAN20>'}]"
```

#### Option 3: Via Group Vars

Create `group_vars/haproxy.yml`:

```yaml
patroni_backends:
  - name: "patroni-node1"
    ip: "<INTERNAL_IP_VLAN20>"
  - name: "patroni-node2"
    ip: "<INTERNAL_IP_VLAN20>"
  - name: "patroni-node3"
    ip: "<INTERNAL_IP_VLAN20>"
```

## Configuration

### Backend Format

Each backend requires:
- `name`: Unique identifier for the backend server
- `ip`: IP address of the Patroni node

```yaml
patroni_backends:
  - name: "patroni-ha-node1-dev"
    ip: "<INTERNAL_IP_VLAN20>"
  - name: "patroni-ha-node2-dev"
    ip: "<INTERNAL_IP_VLAN20>"
  - name: "patroni-ha-node3-dev"
    ip: "<INTERNAL_IP_VLAN20>"
```

### Ports

HAProxy exposes:
- **5000**: PostgreSQL Primary (read-write)
- **5001**: PostgreSQL Replicas (read-only)
- **7000**: HAProxy Stats Dashboard

## Verification

### 1. Check HAProxy Status

```bash
ssh root@<haproxy-ip>
systemctl status haproxy
```

### 2. View HAProxy Stats

Open in browser: `http://<haproxy-ip>:7000/stats`

### 3. Test PostgreSQL Connection

```bash
# Connect to primary (read-write)
psql -h <haproxy-ip> -p 5000 -U postgres

# Connect to replica (read-only)
psql -h <haproxy-ip> -p 5001 -U postgres
```

### 4. Check Backend Health

```bash
echo "show stat" | socat stdio /run/haproxy/admin.sock | grep postgres
```

## Troubleshooting

### HAProxy Not Listening on Ports

**Symptom**: Ports 5000, 5001, 7000 timeout

**Cause**: `patroni_backends` not defined or empty

**Solution**: Ensure you're passing the `patroni_backends` variable with valid Patroni node IPs

### Backend Servers Down

**Symptom**: HAProxy stats show all backends as DOWN

**Possible Causes**:
1. Patroni nodes not reachable from HAProxy LXC
2. Patroni REST API not running on port 8008
3. Firewall blocking connections

**Check Network Connectivity**:
```bash
# From HAProxy LXC
curl http://<INTERNAL_IP_VLAN20>:8008/
curl http://<INTERNAL_IP_VLAN20>:8008/
curl http://<INTERNAL_IP_VLAN20>:8008/
```

### Configuration Validation Failed

**Symptom**: HAProxy fails to start with config error

**Solution**: Check HAProxy logs
```bash
journalctl -u haproxy -n 50
```

## Example Deployment

Complete example for deploying HAProxy for a 3-node Patroni cluster:

```yaml
# In your workflow caller
name: Deploy HAProxy for Patroni
uses: ./.github/workflows/reusable-provision.yml
with:
  app_name: patroni-ha-lb
  resource_type: lxc
  vlan_tag: "20"
  vm_target_ip: "<INTERNAL_IP_VLAN20>"
  cpu_cores: "2"
  ram_mb: "2048"
  disk_gb: "10G"
  ansible_roles: haproxy
  ansible_extra_vars: |
    patroni_backends=[
      {'name':'patroni-ha-node1-dev','ip':'<INTERNAL_IP_VLAN20>'},
      {'name':'patroni-ha-node2-dev','ip':'<INTERNAL_IP_VLAN20>'},
      {'name':'patroni-ha-node3-dev','ip':'<INTERNAL_IP_VLAN20>'}
    ]
  lxc_unprivileged: false
```

## High Availability Options

For production, consider:

1. **Multiple HAProxy Instances**: Deploy 2+ HAProxy nodes
2. **Virtual IP (VIP)**: Use keepalived for failover
3. **DNS Round Robin**: Point DNS to multiple HAProxy IPs
4. **External Load Balancer**: Use cloud provider LB

See `docs/patroni-haproxy.md` for HA setup details.

## Security Considerations

1. **Network Segmentation**: Place HAProxy in DMZ if exposing to apps
2. **Firewall Rules**: Restrict access to ports 5000, 5001, 7000
3. **TLS/SSL**: Consider adding SSL termination at HAProxy
4. **Authentication**: Use PostgreSQL authentication, not HAProxy

## Monitoring

HAProxy stats page provides:
- Backend server status (UP/DOWN)
- Connection counts
- Request rates
- Health check results

Integrate with Prometheus using HAProxy exporter for production monitoring.
