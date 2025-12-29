output "vm_id" {
  value = var.resource_type == "vm" ? proxmox_vm_qemu.generic_vm[0].vmid : null
}

output "resource_id" {
  value = var.resource_type == "vm" ? proxmox_vm_qemu.generic_vm[0].vmid : (var.resource_type == "lxc" ? proxmox_lxc.container[0].vmid : null)
  description = "ID of the created resource (VM or LXC)"
}

output "resource_type" {
  value = var.resource_type
  description = "Type of resource created"
}

output "vm_target_ip" {
  value = var.resource_type == "vm" ? var.vm_target_ip : null
  description = "The static IP address configured for the VM via cloud-init"
}