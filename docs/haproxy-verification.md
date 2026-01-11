# HAProxy Role Verification Checklist

## Pre-Deployment Checks

### Required Variables
All these variables are automatically set by `site.yml`:

- ✅ `target_hostname` - Set from `vm_hostnames_json` or inventory hostname
- ✅ `ansible_play_hosts` - Built-in Ansible variable (list of all hosts)
- ✅ `ansible_default_ipv4.address` - Built-in Ansible fact
- ✅ `hostvars[host]['target_hostname']` - Available from set_fact in site.yml

### Configuration Validation

The HAProxy configuration template will generate:

```haproxy
# For 3-node cluster (<INTERNAL_IP_VLAN20>, <INTERNAL_IP_VLAN20>, <INTERNAL_IP_VLAN20>)
listen postgres_primary
    bind *:5000
    server patroni-prod-node1 <INTERNAL_IP_VLAN20>:5432 check port 8008
    server patroni-prod-node2 <INTERNAL_IP_VLAN20>:5432 check port 8008
    server patroni-prod-node3 <INTERNAL_IP_VLAN20>:5432 check port 8008

listen postgres_replicas
    bind *:5001
    server patroni-prod-node1 <INTERNAL_IP_VLAN20>:5432 check port 8008
    server patroni-prod-node2 <INTERNAL_IP_VLAN20>:5432 check port 8008
    server patroni-prod-node3 <INTERNAL_IP_VLAN20>:5432 check port 8008
```

## Deployment Steps

### 1. Add HAProxy to Roles

```yaml
ansible_roles: "etcd,patroni,haproxy"
```

### 2. Expected Ansible Output

```
TASK [haproxy : Check if required ports are available]
ok: [<INTERNAL_IP_VLAN20>] => (item=5000)
ok: [<INTERNAL_IP_VLAN20>] => (item=5000)
ok: [<INTERNAL_IP_VLAN20>] => (item=5000)

TASK [haproxy : Install HAProxy]
changed: [<INTERNAL_IP_VLAN20>]
changed: [<INTERNAL_IP_VLAN20>]
changed: [<INTERNAL_IP_VLAN20>]

TASK [haproxy : Create HAProxy configuration]
changed: [<INTERNAL_IP_VLAN20>]
changed: [<INTERNAL_IP_VLAN20>]
changed: [<INTERNAL_IP_VLAN20>]

TASK [haproxy : Enable and start HAProxy service]
changed: [<INTERNAL_IP_VLAN20>]
changed: [<INTERNAL_IP_VLAN20>]
changed: [<INTERNAL_IP_VLAN20>]

TASK [haproxy : Verify HAProxy is listening on ports]
ok: [<INTERNAL_IP_VLAN20>] => (item=5000)
ok: [<INTERNAL_IP_VLAN20>] => (item=5000)
ok: [<INTERNAL_IP_VLAN20>] => (item=5000)

TASK [haproxy : Display HAProxy connection info]
ok: [<INTERNAL_IP_VLAN20>] => {
    "msg": [
        "===================================================================",
        "HAProxy PostgreSQL Load Balancer Configured",
        "===================================================================",
        "Primary (read-write): <INTERNAL_IP_VLAN20>:5000",
        "Replicas (read-only): <INTERNAL_IP_VLAN20>:5001",
        "HAProxy Stats: http://<INTERNAL_IP_VLAN20>:7000/stats",
        "",
        "Connect to PostgreSQL:",
        "  psql -h <INTERNAL_IP_VLAN20> -p 5000 -U postgres",
        "==================================================================="
    ]
}
```

## Post-Deployment Verification

### On Each Node

**1. Check HAProxy service status:**
```bash
systemctl status haproxy
```
Expected: `Active: active (running)`

**2. Verify ports are listening:**
```bash
ss -tlnp | grep haproxy
```
Expected output:
```
LISTEN 0  128  *:5000  *:*  users:(("haproxy",pid=XXXX))
LISTEN 0  128  *:5001  *:*  users:(("haproxy",pid=XXXX))
LISTEN 0  128  *:7000  *:*  users:(("haproxy",pid=XXXX))
```

**3. Check HAProxy configuration syntax:**
```bash
haproxy -c -f /etc/haproxy/haproxy.cfg
```
Expected: `Configuration file is valid`

**4. View HAProxy stats:**
```bash
curl http://localhost:7000/stats
```
Or open in browser: `http://<INTERNAL_IP_VLAN20>:7000/stats`

**5. Test health check endpoints:**
```bash
# Check Patroni primary endpoint
curl http://<INTERNAL_IP_VLAN20>:8008/
curl http://<INTERNAL_IP_VLAN20>:8008/
curl http://<INTERNAL_IP_VLAN20>:8008/

# Check Patroni replica endpoint
curl http://<INTERNAL_IP_VLAN20>:8008/replica
curl http://<INTERNAL_IP_VLAN20>:8008/replica
curl http://<INTERNAL_IP_VLAN20>:8008/replica
```

Expected: HTTP 200 from primary, 200 from replicas

### Connection Tests

**1. Test primary connection (read-write):**
```bash
psql -h <INTERNAL_IP_VLAN20> -p 5000 -U postgres -c "SELECT pg_is_in_recovery();"
```
Expected: `f` (false - not in recovery, this is primary)

**2. Test replica connection (read-only):**
```bash
psql -h <INTERNAL_IP_VLAN20> -p 5001 -U postgres -c "SELECT pg_is_in_recovery();"
```
Expected: `t` (true - in recovery, this is replica) or `f` if connected to primary

**3. Test write through HAProxy:**
```bash
psql -h <INTERNAL_IP_VLAN20> -p 5000 -U postgres -c "CREATE TABLE test_haproxy (id int);"
psql -h <INTERNAL_IP_VLAN20> -p 5000 -U postgres -c "DROP TABLE test_haproxy;"
```
Expected: Success

## Troubleshooting

### Issue: HAProxy won't start

**Check logs:**
```bash
journalctl -u haproxy -n 50 --no-pager
```

**Common causes:**
1. Port already in use (5000, 5001, or 7000)
2. Configuration syntax error
3. Patroni not running (health checks fail)

### Issue: Health checks failing

**Check Patroni REST API:**
```bash
curl -v http://<INTERNAL_IP_VLAN20>:8008/
```

If this fails, Patroni is not running or not listening on port 8008.

**Check HAProxy backend status:**
```bash
echo "show stat" | socat stdio /run/haproxy/admin.sock | grep postgres
```

Look for `UP` status on backends.

### Issue: Can't connect to PostgreSQL through HAProxy

**1. Verify PostgreSQL is listening:**
```bash
ss -tlnp | grep 5432
```

**2. Test direct PostgreSQL connection:**
```bash
psql -h <INTERNAL_IP_VLAN20> -p 5432 -U postgres
```

**3. Check HAProxy is routing correctly:**
```bash
# View current connections
echo "show sess" | socat stdio /run/haproxy/admin.sock
```

### Issue: Configuration validation fails

The role uses `validate: haproxy -c -f %s` which tests the config before applying.

If validation fails, check:
1. Jinja2 template syntax
2. Variable availability (target_hostname, ansible_play_hosts)
3. HAProxy configuration syntax

## Expected Behavior

### Normal Operation

- HAProxy checks Patroni REST API every 3 seconds
- If primary fails health check 3 times (9 seconds), it's marked down
- Traffic automatically routes to new primary
- Replica connections load balance across all healthy replicas

### Failover Scenario

1. Primary node fails
2. Patroni elects new primary (typically 30 seconds)
3. HAProxy detects new primary via health check (within 9 seconds)
4. All write traffic routes to new primary
5. Old primary (if recovered) becomes replica

Total failover time: ~40 seconds

## Success Criteria

✅ HAProxy service is active on all nodes
✅ Ports 5000, 5001, 7000 are listening
✅ Configuration file validates successfully
✅ Stats page is accessible
✅ Can connect to PostgreSQL via port 5000
✅ Health checks show all backends UP
✅ Patroni REST API responds correctly

## Integration with Patroni

HAProxy health checks use Patroni's built-in REST API:

- `GET /` - Returns 200 only on primary node
- `GET /replica` - Returns 200 on replica nodes
- `GET /health` - Returns 200 if Patroni is running

This ensures HAProxy always routes to the correct node based on Patroni's cluster state.
