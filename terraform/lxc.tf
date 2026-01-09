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
    keyctl  = var.lxc_unprivileged ? true : false  # Required for Tailscale (only works with unprivileged)
  }
  
  # Start on boot
  onboot = true
  start  = false  # Don't auto-start - we need to configure TUN first
  
  # NOTE: TUN device must be manually configured for Tailscale to work
  # After Terraform creates the container, run these commands on the Proxmox host:
  #   pct stop <VMID>
  #   echo 'lxc.cgroup2.devices.allow: c 10:200 rwm' >> /etc/pve/lxc/<VMID>.conf
  #   echo 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> /etc/pve/lxc/<VMID>.conf
  #   pct start <VMID>
  
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
