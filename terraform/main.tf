terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}
resource "random_id" "vm_suffix" {
  byte_length = 2
}

locals {
  # Generates something like: k3s-prod-a1b2
  vm_hostname = "${var.app_name}-${var.environment}-${random_id.vm_suffix.hex}"
}

locals {
  # This splits the IP provided (e.g., 192.168.10.50) and replaces 
  # the last part with .1 to find your gateway automatically.
  # Alternatively, since you know the VLAN, we can just hardcode the prefix:
  gateway = "192.168.${var.vlan_tag}.1"
}

resource "proxmox_vm_qemu" "generic_vm" {
  name        = "${var.app_name}-vm"
  target_node = "pve"
  clone       = "ubuntu-2404-template"
  full_clone  = true
  
  cores  = var.vm_cpu_cores
  memory = var.vm_ram_mb
  disk {
    slot = 0
    size = var.vm_disk_gb
    type = "scsi"
    storage = "zfs-vm"
  }
  network {
    id = 0
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_tag
  }

  # Cloud-Init Injection
  os_type    = "cloud-init"
  ciuser     = "deploy"
  ipconfig0 = "ip=${var.vm_target_ip}/24,gw=${local.gateway}"
 
  # This pulls from your secret via the GitHub Action
  sshkeys = <<EOF
  ${var.ssh_public_key}
  EOF
}