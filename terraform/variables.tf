variable "vm_target_ip" {
  type        = string
  description = "The static IP for the VM (e.g. 192.168.10.50 for VLAN 10, 192.168.20.50 for VLAN 20)"

  validation {
    condition = (
      can(regex("^192\\.168\\.(10|20)\\.[0-9]{1,3}$", var.vm_target_ip)) &&
      tonumber(split(".", var.vm_target_ip)[3]) >= 10 &&
      tonumber(split(".", var.vm_target_ip)[3]) <= 254
    )
    error_message = "IP must match 192.168.10.x or 192.168.20.x pattern where x is between 10 and 254. VLAN 10 = DMZ/production, VLAN 20 = internal dev."
  }
}

variable "vm_cpu_cores" {
  type        = string
  default     = "2"
  description = "Number of CPU cores (passed as string from GitHub Actions)"
}

variable "vm_ram_mb" {
  type        = string
  default     = "4096"
  description = "RAM in MB (passed as string from GitHub Actions)"
}

variable "vm_disk_gb" {
  type        = string
  default     = "20G" # Proxmox provider often expects strings for disk size
}

variable "app_name" {
  type        = string
  default     = "app"
}

variable "environment" {
  type        = string
  default     = "dev"
}

variable "vlan_tag" {
  type        = string
  description = "The VLAN tag for the network interface. Tag 20 = internal dev, Tag 10 = DMZ/production"
  default     = "20"

  validation {
    condition     = contains(["10", "20"], var.vlan_tag)
    error_message = "VLAN tag must be either '10' (DMZ/production) or '20' (internal dev)."
  }
}

# These match the TF_VAR_ names we will set in Semaphore
variable "proxmox_api_url" { type = string }
variable "proxmox_api_token_id" { type = string }

variable "proxmox_api_token_secret" { 
  type      = string 
  sensitive = true  # This prevents the secret from printing in logs
}

variable "ssh_public_key" { 
  type = string
  sensitive = true 
}

# Infrastructure configuration - can be overridden per deployment
variable "proxmox_target_node" {
  type        = string
  default     = "pmx"
  description = "Proxmox node to deploy VM on"
}

variable "proxmox_storage" {
  type        = string
  default     = "zfs-vm"
  description = "Storage pool for VM disks"
}

variable "vm_template" {
  type        = string
  default     = "ubuntu-2404-template"
  description = "VM template to clone from"
}
