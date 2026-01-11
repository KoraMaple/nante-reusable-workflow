# Documentation Sanitization Guide

This guide documents the replacements made to prepare the repository for public release.

## IP Address Sanitization

All specific internal IP addresses have been replaced with placeholders:

| Original Pattern | Replacement | Usage |
|-----------------|-------------|-------|
| `192.168.20.10` | `<MINIO_INTERNAL_IP>` or `minio.tailnet` | MinIO server |
| `192.168.20.x` | `<INTERNAL_IP_VLAN20>` | Internal dev network |
| `192.168.10.x` | `<INTERNAL_IP_VLAN10>` | DMZ/production network |
| `192.168.20.1` | `<GATEWAY_VLAN20>` | Default gateway for VLAN 20 |
| `192.168.10.1` | `<GATEWAY_VLAN10>` | Default gateway for VLAN 10 |

## Service Name Sanitization

| Original | Replacement | Description |
|----------|-------------|-------------|
| `pmx` | `<PROXMOX_NODE>` | Proxmox node name |
| `zfs-vm` | `<STORAGE_POOL>` | ZFS storage pool |
| Specific tailnet names | `<YOUR_TAILNET>` | Tailscale network name |
| `ubuntu-2404-template` | `<VM_TEMPLATE>` | Proxmox VM template |

## Configuration Examples

All example configurations now use placeholders. Users should replace with their own values:

```yaml
# Example configuration
proxmox_node: "<PROXMOX_NODE>"        # Your Proxmox node name (e.g., "pve", "proxmox01")
proxmox_storage: "<STORAGE_POOL>"     # Your storage pool (e.g., "local-lvm", "zfs-vm")
vm_template: "<VM_TEMPLATE>"          # Your VM template name
minio_endpoint: "<MINIO_ENDPOINT>"    # Your MinIO endpoint (e.g., "http://minio.internal:9000")
```

## Doppler Configuration

All internal endpoints should be configured in Doppler:

```bash
# Add to your Doppler project:
doppler secrets set MINIO_ENDPOINT="http://<your-minio-host>:9000"
doppler secrets set PROXMOX_API_URL="https://<your-proxmox>:8006/api2/json"
# ... other secrets
```

## Documentation Files Updated

The following files have been sanitized:
- `README.md`
- `docs/USAGE.md`
- `docs/TROUBLESHOOTING.md`
- `docs/DOPPLER_SECRETS.md`
- `docs/FREEIPA_SETUP.md`
- `docs/LXC_PROVISIONING.md`
- `docs/PHASE2_TESTING.md`
- `docs/patroni-ha-cluster.md`
- `docs/patroni-haproxy.md`
- `docs/WORKFLOW_RETRY_GUIDE.md`
- All files in `examples/`
- `terraform/*.tf` comments
- `.github/copilot-instructions.md`

## For Contributors

When adding new documentation:
1. Use placeholders for all internal IP addresses
2. Use descriptive placeholders like `<SERVICE_NAME>` not `<IP>`
3. Provide example values in comments
4. Reference Doppler for actual configuration values

## For Users

When using this repository:
1. Replace all placeholders with your actual values
2. Store sensitive values in Doppler
3. Never commit actual IP addresses or credentials
4. Use Tailscale DNS names where possible (e.g., `minio.tailnet` instead of IPs)
