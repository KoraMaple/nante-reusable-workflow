# LXC Container Configuration
# This file handles LXC container provisioning as an alternative to VMs

resource "proxmox_lxc" "container" {
  for_each = var.resource_type == "lxc" ? local.instance_map : {}
  
  target_node  = var.proxmox_target_node
  hostname     = local.vm_hostnames[each.key]
  ostemplate   = var.lxc_template
  unprivileged = var.lxc_unprivileged
  
  # Resource allocation
  cores  = coalesce(each.value.cpu_cores, var.vm_cpu_cores)
  memory = coalesce(each.value.ram_mb, var.vm_ram_mb)
  swap   = 512  # 512MB swap
  
  # Root filesystem
  rootfs {
    storage = var.proxmox_storage
    size    = coalesce(each.value.disk_gb, var.vm_disk_gb)
  }
  
  # Network configuration
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "${each.value.ip_address}/24"
    gw     = local.gateway
    tag    = var.vlan_tag
  }
  
  # DNS configuration
  # LXC containers don't inherit DNS from host, must be explicitly set
  nameserver = "8.8.8.8"
  searchdomain = "tail09bdcf.ts.net"
  
  # SSH public key for root user
  # Note: LXC containers only support adding SSH keys to root user
  # Ansible will run as root for LXC containers
  ssh_public_keys = trimspace(var.ssh_public_key)
  
  # Container features
  features {
    nesting = var.lxc_nesting              # Required for Docker in LXC
    # Note: keyctl is only needed for unprivileged containers with Tailscale
    # For privileged containers, Tailscale works without keyctl
    # keyctl requires root@pam permissions to set, so we omit it for privileged containers
  }
  
  # Start on boot
  onboot = true
  start  = true  # Auto-start after creation
  
  # NOTE: For unprivileged containers with Tailscale, TUN device must be manually configured
  # After Terraform creates the container, run these commands on the Proxmox host:
  #   pct stop <VMID>
  #   echo 'lxc.cgroup2.devices.allow: c 10:200 rwm' >> /etc/pve/lxc/<VMID>.conf
  #   echo 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> /etc/pve/lxc/<VMID>.conf
  #   pct start <VMID>
  #
  # For privileged containers (lxc_unprivileged=false), TUN device works automatically.
  # No manual configuration needed.
  
  # Lifecycle management
  lifecycle {
    ignore_changes = [
      # Ignore changes to these after initial creation
      ssh_public_keys,
    ]
  }
  
  # Note: Rocky Linux LXC containers may take 2-3 minutes to fully boot and start SSH
  # The workflow includes extended wait time (3 minutes) for LXC containers
}

# Output container IDs
output "lxc_ids" {
  value = var.resource_type == "lxc" ? {
    for key, container in proxmox_lxc.container :
    key => container.vmid
  } : {}
  description = "Map of LXC container IDs (CTID)"
}

# Output container IPs
output "lxc_ips" {
  value = var.resource_type == "lxc" ? {
    for key, instance in local.instance_map :
    key => instance.ip_address
  } : {}
  description = "Map of LXC container IP addresses"
}

# Output container hostnames
output "lxc_hostnames" {
  value = var.resource_type == "lxc" ? local.vm_hostnames : {}
  description = "Map of LXC container hostnames"
}

# Output single container ID (for single-instance mode)
output "lxc_id" {
  value = var.resource_type == "lxc" && var.instance_count == 1 ? values(proxmox_lxc.container)[0].vmid : null
  description = "Single LXC container ID (only for single-instance deployments)"
}

# Output single container hostname (for single-instance mode)
output "lxc_hostname" {
  value = var.resource_type == "lxc" && var.instance_count == 1 ? values(local.vm_hostnames)[0] : ""
  description = "Single LXC container hostname (only for single-instance deployments)"
}
