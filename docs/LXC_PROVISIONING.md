# LXC Container Provisioning with Terraform

## Overview

This guide covers provisioning LXC containers on Proxmox using Terraform, alongside the existing VM provisioning capabilities.

## Prerequisites

### 1. Proxmox Configuration

**Container Templates:**
LXC containers require OS templates to be downloaded to Proxmox first.

```bash
# SSH to Proxmox host
ssh root@proxmox-host

# List available templates
pveam available

# Download Ubuntu 22.04 template (recommended)
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Download Debian 12 template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Verify downloaded templates
pveam list local
```

**Storage Configuration:**
- Templates stored in: `/var/lib/vz/template/cache/`
- Container root filesystems: `/var/lib/vz/` or your configured storage
- Ensure storage has sufficient space

**Network Configuration:**
- VLANs must be configured on Proxmox bridge (same as VMs)
- Bridge typically: `vmbr0`
- VLAN tagging supported

### 2. Terraform Provider Requirements

The Proxmox provider supports LXC containers via `proxmox_lxc` resource:

```hcl
resource "proxmox_lxc" "container" {
  # LXC-specific configuration
}
```

### 3. Doppler Secrets

Same secrets as VM provisioning:
- `PROXMOX_API_URL`
- `PROXMOX_TOKEN_ID`
- `PROXMOX_TOKEN_SECRET`
- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_CLIENT_SECRET`
- `TAILSCALE_TAILNET`
- `ANS_SSH_PUBLIC_KEY`

## LXC vs VM Comparison

| Feature | LXC Container | VM (QEMU) |
|---------|---------------|-----------|
| **Boot Time** | 2-5 seconds | 30-60 seconds |
| **Resource Usage** | Lower (shared kernel) | Higher (full OS) |
| **Isolation** | Container-level | Full virtualization |
| **Performance** | Near-native | Slight overhead |
| **Use Cases** | Microservices, web apps | Full OS isolation, Windows |
| **Disk Space** | 500MB - 2GB typical | 10GB+ typical |
| **Memory** | 512MB - 2GB typical | 2GB+ typical |

## Terraform Configuration

### File Structure

```
terraform/
├── providers.tf          # Existing - no changes
├── variables.tf          # Add LXC variables
├── main.tf              # VM configuration
├── lxc.tf               # NEW - LXC configuration
├── tailscale.tf         # Existing - shared
└── outputs.tf           # Add LXC outputs
```

### LXC-Specific Variables

```hcl
# Container type flag
variable "resource_type" {
  description = "Type of resource to create: vm or lxc"
  type        = string
  default     = "vm"
  validation {
    condition     = contains(["vm", "lxc"], var.resource_type)
    error_message = "resource_type must be either 'vm' or 'lxc'"
  }
}

# LXC template
variable "lxc_template" {
  description = "LXC template to use"
  type        = string
  default     = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

# LXC features
variable "lxc_unprivileged" {
  description = "Run container as unprivileged"
  type        = bool
  default     = true
}

variable "lxc_nesting" {
  description = "Enable nesting (Docker in LXC)"
  type        = bool
  default     = false
}
```

### LXC Resource Configuration

```hcl
resource "proxmox_lxc" "container" {
  count = var.resource_type == "lxc" ? 1 : 0
  
  target_node  = var.proxmox_target_node
  hostname     = local.vm_hostname
  ostemplate   = var.lxc_template
  unprivileged = var.lxc_unprivileged
  
  # Resources
  cores  = var.vm_cpu_cores
  memory = var.vm_ram_mb
  swap   = 512
  
  # Root filesystem
  rootfs {
    storage = var.proxmox_storage
    size    = "${var.vm_disk_gb}G"
  }
  
  # Network
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "${var.vm_target_ip}/24"
    gw     = local.gateway
    tag    = var.vlan_tag
  }
  
  # SSH key
  ssh_public_keys = var.ssh_public_key
  
  # Features
  features {
    nesting = var.lxc_nesting
  }
  
  # Start on boot
  onboot = true
  start  = true
}
```

## Key Differences from VMs

### 1. No Cloud-Init
LXC containers don't use cloud-init. Configuration happens via:
- SSH keys injected directly
- Network configured in resource
- Hostname set in resource

### 2. Faster Provisioning
- No boot wait time
- Container starts immediately
- Ansible can connect within seconds

### 3. Privileged vs Unprivileged

**Unprivileged (Recommended - Default):**
```hcl
lxc_unprivileged = true
```
- ✅ Better security
- ✅ User namespace isolation
- ✅ Sufficient for most workloads
- ✅ Can run Docker with nesting enabled
- ✅ Recommended for production

**Privileged (Use with Caution):**
```hcl
lxc_unprivileged = false
```
- ⚠️ Full root access to host
- ⚠️ Less secure - container root = host root
- ⚠️ Only use when absolutely necessary
- Use cases:
  - Legacy applications requiring full privileges
  - Specific kernel features
  - Hardware access requirements

**Security Impact:**
- **Unprivileged**: Container UID 0 (root) maps to unprivileged UID on host (e.g., 100000)
- **Privileged**: Container UID 0 (root) = Host UID 0 (root) - DANGEROUS!

### 4. Nesting for Docker

To run Docker inside LXC:

```hcl
unprivileged = true
features {
  nesting = true
}
```

**Proxmox host configuration required:**
```bash
# Edit container config on Proxmox
nano /etc/pve/lxc/<CTID>.conf

# Add these lines:
lxc.apparmor.profile: unconfined
lxc.cgroup.devices.allow: a
lxc.cap.drop:
```

## Workflow Integration

### Workflow Inputs

Add to `reusable-provision.yml`:

```yaml
inputs:
  resource_type:
    description: 'Resource type: vm or lxc'
    required: false
    default: 'vm'
    type: string
  
  lxc_template:
    description: 'LXC template (if resource_type=lxc)'
    required: false
    default: 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst'
    type: string
  
  lxc_nesting:
    description: 'Enable nesting for Docker in LXC'
    required: false
    default: false
    type: boolean
```

### Terraform Variables

```bash
terraform plan \
  -var="resource_type=lxc" \
  -var="lxc_template=local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst" \
  -var="lxc_nesting=true" \
  # ... other vars
```

## Ansible Compatibility

LXC containers work with existing Ansible roles:
- ✅ `base_setup` - Full compatibility
- ✅ `octopus-tentacle` - Works perfectly
- ✅ `mgmt-docker` - Requires nesting enabled
- ✅ Tailscale - Full support

**No changes needed** to Ansible playbooks.

## Resource Sizing Guidelines

### Lightweight Services
```
CPU: 1 core
RAM: 512MB
Disk: 2GB
Use case: Nginx, simple web apps
```

### Standard Applications
```
CPU: 2 cores
RAM: 2GB
Disk: 8GB
Use case: Node.js apps, Python services
```

### Docker Host
```
CPU: 4 cores
RAM: 4GB
Disk: 20GB
Nesting: true
Use case: Running containers
```

## Limitations

### Cannot Use LXC For:
- ❌ Windows workloads
- ❌ Custom kernels
- ❌ Kernel modules
- ❌ Full OS isolation requirements

### Use VMs Instead When:
- Need different kernel version
- Require full virtualization
- Running Windows
- Need complete isolation

## Migration Path

### VM to LXC
1. Export data from VM
2. Provision LXC with same configuration
3. Restore data
4. Update DNS/networking
5. Destroy VM

### LXC to VM
1. Create VM with same specs
2. Copy data from LXC
3. Reconfigure services
4. Update networking
5. Destroy LXC

## Best Practices

### 1. Template Management
```bash
# Keep templates updated
pveam update
pveam available | grep ubuntu
pveam download local <new-template>
```

### 2. Resource Allocation
- Start small, scale up if needed
- Monitor with Grafana Alloy
- LXC uses less than VMs

### 3. Security
- Use unprivileged containers
- Enable nesting only when needed
- Keep templates updated
- Use Tailscale for networking

### 4. Backup Strategy
```bash
# Proxmox backup
vzdump <CTID> --mode snapshot --storage <backup-storage>
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
pct start <CTID>
journalctl -u pve-container@<CTID>

# Check config
cat /etc/pve/lxc/<CTID>.conf
```

### Docker Won't Run
```bash
# Enable nesting in Terraform
lxc_nesting = true

# Or manually on Proxmox
pct set <CTID> -features nesting=1
```

### Network Issues
```bash
# Inside container
ip addr
ip route
ping 8.8.8.8

# Check Proxmox bridge
brctl show vmbr0
```

### SSH Connection Fails
```bash
# Check SSH service
pct enter <CTID>
systemctl status ssh

# Verify key injection
cat /root/.ssh/authorized_keys
```

## Examples

### Provision Unprivileged LXC (Recommended)
```yaml
uses: ./.github/workflows/reusable-provision.yml
with:
  resource_type: lxc
  app_name: web-app
  vm_target_ip: 192.168.20.100
  cpu_cores: 2
  ram_mb: 2048
  disk_gb: 8
  lxc_template: local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
  lxc_unprivileged: true  # Default - secure
```

### Provision Docker Host LXC (Unprivileged + Nesting)
```yaml
uses: ./.github/workflows/reusable-provision.yml
with:
  resource_type: lxc
  app_name: docker-host
  vm_target_ip: 192.168.20.101
  cpu_cores: 4
  ram_mb: 4096
  disk_gb: 20
  lxc_unprivileged: true  # Secure
  lxc_nesting: true       # For Docker
```

### Provision Privileged LXC (Use with Caution)
```yaml
uses: ./.github/workflows/reusable-provision.yml
with:
  resource_type: lxc
  app_name: legacy-app
  vm_target_ip: 192.168.20.102
  cpu_cores: 2
  ram_mb: 2048
  disk_gb: 10
  lxc_template: local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
  lxc_unprivileged: false  # ⚠️ PRIVILEGED MODE
```

## Next Steps

1. Download LXC templates to Proxmox
2. Create `terraform/lxc.tf`
3. Update `terraform/variables.tf`
4. Modify workflow to support LXC
5. Test provisioning
6. Update documentation

## References

- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Terraform Proxmox Provider - LXC](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/lxc)
- [LXC vs Docker](https://linuxcontainers.org/lxc/introduction/)
