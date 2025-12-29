# LXC Container Configuration
# This file handles LXC container provisioning as an alternative to VMs

resource "proxmox_lxc" "container" {
  count = var.resource_type == "lxc" ? 1 : 0
  
  target_node  = var.proxmox_target_node
  hostname     = local.vm_hostname
  ostemplate   = var.lxc_template
  unprivileged = var.lxc_unprivileged
  
  # Resource allocation
  cores  = var.vm_cpu_cores
  memory = var.vm_ram_mb
  swap   = 512  # 512MB swap
  
  # Root filesystem
  rootfs {
    storage = var.proxmox_storage
    size    = "${var.vm_disk_gb}"
  }
  
  # Network configuration
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "${var.vm_target_ip}/24"
    gw     = local.gateway
    tag    = var.vlan_tag
  }
  
  # SSH public key for root user
  # Note: LXC containers only support adding SSH keys to root user
  # Ansible will run as root for LXC containers
  ssh_public_keys = trimspace(var.ssh_public_key)
  
  # Container features
  features {
    nesting = var.lxc_nesting  # Required for Docker in LXC
  }
  
  # Start on boot
  onboot = true
  start  = true
  
  # Lifecycle management
  lifecycle {
    ignore_changes = [
      # Ignore changes to these after initial creation
      ssh_public_keys,
    ]
  }
}

# Output container ID
output "lxc_id" {
  value       = var.resource_type == "lxc" ? proxmox_lxc.container[0].vmid : null
  description = "LXC container ID (CTID)"
}

# Output container IP
output "lxc_ip" {
  value       = var.resource_type == "lxc" ? var.vm_target_ip : null
  description = "LXC container IP address"
}

# Output container hostname
output "lxc_hostname" {
  value       = var.resource_type == "lxc" ? local.vm_hostname : null
  description = "LXC container hostname"
}
