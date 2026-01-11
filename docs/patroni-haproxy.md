# HAProxy Load Balancer for Patroni Cluster

## Overview

HAProxy provides a single entry point for client connections to the Patroni PostgreSQL cluster, automatically routing traffic to the primary node for writes and distributing read queries across replicas.

## Architecture

```
Client Applications
       ↓
   HAProxy (any node)
       ↓
   ┌─────────────────────┐
   │                     │
Primary (RW)      Replicas (RO)
Port 5000         Port 5001
   │                     │
   └─────────────────────┘
         Patroni Cluster
```

## Ports

- **5000**: Primary connection (read-write)
- **5001**: Replica connections (read-only)
- **7000**: HAProxy stats dashboard

## Installation

HAProxy can be installed on:
1. **All Patroni nodes** (recommended) - provides redundancy
2. **Dedicated load balancer node** - separate from database nodes
3. **One Patroni node** - simplest but single point of failure

### Option 1: Install on All Patroni Nodes (Recommended)

Add `haproxy` to your `ansible_roles` list:

```yaml
ansible_roles: "etcd,patroni,haproxy"
```

This installs HAProxy on each database node. Clients can connect to any node's IP on port 5000/5001.

### Option 2: Dedicated Load Balancer

Deploy a separate VM and run:

```yaml
ansible_roles: "haproxy"
```

Pass the Patroni cluster IPs via extra vars.

## Usage

### Connecting to PostgreSQL

**Primary (read-write):**
```bash
psql -h <haproxy-host> -p 5000 -U postgres -d postgres
```

**Replicas (read-only):**
```bash
psql -h <haproxy-host> -p 5001 -U postgres -d postgres
```

### Application Connection Strings

**Python (psycopg2):**
```python
# Write connection
conn = psycopg2.connect(
    host="haproxy-host",
    port=5000,
    user="postgres",
    password="your_password",
    database="your_db"
)

# Read connection
read_conn = psycopg2.connect(
    host="haproxy-host",
    port=5001,
    user="postgres",
    password="your_password",
    database="your_db"
)
```

**JDBC:**
```
jdbc:postgresql://haproxy-host:5000/your_db
```

### Monitoring

Access HAProxy stats dashboard:
```
http://<haproxy-host>:7000/stats
```

Shows:
- Active connections per backend
- Health check status
- Current primary/replica status
- Traffic statistics

## Health Checks

HAProxy uses Patroni's REST API for health checks:

- **Primary check**: `GET http://node:8008/` - Returns 200 only on primary
- **Replica check**: `GET http://node:8008/replica` - Returns 200 on replicas

If the primary fails:
1. Patroni elects a new primary
2. HAProxy detects the change within 3 seconds
3. Traffic automatically routes to new primary

## High Availability

### Multiple HAProxy Instances

When HAProxy runs on all nodes, use:

1. **DNS Round Robin**: Create DNS record pointing to all IPs
2. **Application-level failover**: Try multiple IPs in connection string
3. **Keepalived VIP** (advanced): Single floating IP

### Example: Application Failover

```python
HAPROXY_HOSTS = ["<INTERNAL_IP_VLAN20>", "<INTERNAL_IP_VLAN20>", "<INTERNAL_IP_VLAN20>"]

for host in HAPROXY_HOSTS:
    try:
        conn = psycopg2.connect(host=host, port=5000, ...)
        break
    except:
        continue
```

## Configuration

HAProxy configuration is in `/etc/haproxy/haproxy.cfg`:

```haproxy
# Primary backend
listen postgres_primary
    bind *:5000
    option httpchk
    server node1 <INTERNAL_IP_VLAN20>:5432 check port 8008
    server node2 <INTERNAL_IP_VLAN20>:5432 check port 8008
    server node3 <INTERNAL_IP_VLAN20>:5432 check port 8008
```

## Troubleshooting

### Check HAProxy Status
```bash
systemctl status haproxy
journalctl -u haproxy -f
```

### Test Health Checks
```bash
# Check primary endpoint
curl http://<INTERNAL_IP_VLAN20>:8008/

# Check replica endpoint
curl http://<INTERNAL_IP_VLAN20>:8008/replica
```

### Verify Backend Status
```bash
echo "show stat" | socat stdio /run/haproxy/admin.sock
```

## Alternative: VIP Manager

For a floating IP approach instead of HAProxy, see [vip-manager documentation](https://github.com/cybertec-postgresql/vip-manager).

VIP Manager provides a single IP that moves with the primary, but doesn't support read replica load balancing.

## Best Practices

1. **Use connection pooling** (PgBouncer) between HAProxy and PostgreSQL
2. **Monitor HAProxy stats** for connection distribution
3. **Set appropriate timeouts** in application connection strings
4. **Use read replicas** for reporting and analytics queries
5. **Deploy HAProxy on all nodes** for redundancy
