# mgmt-docker Role

Ansible role for onboarding existing Docker management servers into the observability stack.

## Purpose

This role is designed for servers that:
- Already have Docker installed
- Run multiple containerized applications
- Need monitoring and log aggregation

## What It Does

1. **Installs Grafana Alloy** (from `base_setup` role dependency)
2. **Configures Docker monitoring**:
   - Docker socket metrics
   - Container resource usage (cAdvisor-style)
   - Container logs collection
3. **Adds Alloy user to docker group** for socket access
4. **Collects system metrics and logs** (standard node_exporter)

## Requirements

- Docker must be pre-installed on the target host
- Alloy will be installed by the `base_setup` role
- Target host must have network access to OpenObserve

## Dependencies

This role depends on `base_setup` role, which:
- Installs Grafana Alloy
- Creates the alloy user and service
- Sets up basic system monitoring

## Variables

| Variable | Description | Default | Source |
|----------|-------------|---------|--------|
| `oo_host` | OpenObserve host/IP | - | Doppler `OO_HOST` |
| `oo_user` | OpenObserve username | - | Doppler `OO_USER` |
| `oo_pass` | OpenObserve password | - | Doppler `OO_PASS` |
| `target_hostname` | Hostname for metric labels | `inventory_hostname` | Playbook |

## Metrics Collected

- **System metrics**: CPU, memory, disk, network (node_exporter)
- **Docker socket metrics**: Container status, network, volumes
- **Container stats**: CPU, memory, network per container (cAdvisor)

## Logs Collected

- **System logs**: `/var/log/*.log`, `/var/log/syslog`
- **Docker container logs**: All container stdout/stderr via Docker socket

## Usage

### Via reusable-onboard workflow

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@develop
    with:
      target_ip: "192.168.20.50"
      ssh_user: "deploy"
      target_hostname: "docker-mgmt"
      app_role: "mgmt-docker"
    secrets: inherit
```

### Direct Ansible

```yaml
- hosts: docker_servers
  become: yes
  roles:
    - base_setup
    - mgmt-docker
  vars:
    target_hostname: "docker-mgmt"
```

## Security Notes

- Alloy user is added to `docker` group for socket access
- This grants read access to Docker socket (equivalent to root)
- Ensure Alloy service is properly secured
- OpenObserve credentials are passed via environment variables

## Troubleshooting

### Alloy can't access Docker socket

Check group membership:
```bash
groups alloy
# Should include: alloy docker
```

Restart Alloy after group change:
```bash
sudo systemctl restart alloy
```

### No container logs appearing

Verify Docker socket access:
```bash
sudo -u alloy docker ps
```

Check Alloy logs:
```bash
sudo journalctl -u alloy -f
```

### Metrics not appearing in OpenObserve

Test connectivity:
```bash
curl -v http://OO_HOST:9090/api/v1/write
curl -v http://OO_HOST:3100/loki/api/v1/push
```

Check Alloy config:
```bash
sudo alloy fmt /etc/alloy/config.alloy
```
