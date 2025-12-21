variable "vm_target_ip" {
  type        = string
  description = "The static IP for the VM (e.g. 192.168.10.50)"
}

variable "vm_cpu_cores" {
  type        = number
  default     = 2
}

variable "vm_ram_mb" {
  type        = number
  default     = 4096
}

variable "vm_disk_gb" {
  type        = string
  default     = "20G" # Proxmox provider often expects strings for disk size
}

variable "app_name" {
  type        = string
  default     = "k3s"
}

variable "environment" {
  type        = string
  default     = "prod"
}

variable "vlan_tag" {
  type        = number
  description = "The VLAN tag for the network interface"
  default     = 20
}

# These match the TF_VAR_ names we will set in Semaphore
variable "proxmox_api_url" { type = string }
variable "proxmox_api_token_id" { type = string }

variable "proxmox_api_token_secret" { 
  type      = string 
  sensitive = true  # This prevents the secret from printing in logs
}

variable "ssh_public_key" { type = string }
