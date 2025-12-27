terraform {
  backend "s3" {
    # MinIO configuration - values provided via -backend-config in workflow
    # bucket, endpoint, access_key, secret_key are passed at init time
    key                         = "terraform.tfstate"
    region                      = "us-east-1"  # Required but ignored by MinIO
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true  # Required for MinIO
  }
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
  target_node = var.proxmox_target_node
  clone       = var.vm_template
  full_clone  = true
  
  # Use VirtIO SCSI for better performance
  scsihw = "virtio-scsi-pci"
  
  # Enable QEMU guest agent
  agent = 1
  
  cpu {
    cores = tonumber(var.vm_cpu_cores)
  }
  memory = tonumber(var.vm_ram_mb)
  
  # Main OS disk
  disk {
    slot    = "scsi0"
    size    = var.vm_disk_gb
    type    = "disk"
    storage = var.proxmox_storage
  }
  
  # Cloud-init drive - required for IP configuration
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.proxmox_storage
  }
  
  network {
    id       = 0
    model    = "virtio"
    bridge   = "vmbr0"
    tag      = tonumber(var.vlan_tag)
    firewall = false
  }

  # Ensure VM starts if node reboots
  start_at_node_boot = true
  
  # Cloud-Init Configuration
  os_type    = "cloud-init"
  ciuser     = "deploy"
  ciupgrade  = false
  ipconfig0  = "ip=${var.vm_target_ip}/24,gw=${local.gateway}"
  nameserver = "192.168.${var.vlan_tag}.1"
 
  # Important: trimspace ensures no leading/trailing whitespace breaks the key
  sshkeys = trimspace(var.ssh_public_key)
  
  # Ensure correct boot order
  boot = "order=scsi0;ide2;net0"
  
  # Serial console is often required for cloud-init to finish successfully on Proxmox
  serial {
    id   = 0
    type = "socket"
  }
}