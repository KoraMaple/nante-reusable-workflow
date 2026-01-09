output "vm_ids" {
  value = var.resource_type == "vm" ? {
    for key, vm in proxmox_vm_qemu.generic_vm :
    key => vm.vmid
  } : {}
  description = "Map of VM IDs"
}

output "resource_ids" {
  value = var.resource_type == "vm" ? {
    for key, vm in proxmox_vm_qemu.generic_vm :
    key => vm.vmid
  } : (var.resource_type == "lxc" ? {
    for key, container in proxmox_lxc.container :
    key => container.vmid
  } : {})
  description = "Map of resource IDs (VM or LXC)"
}

output "resource_type" {
  value = var.resource_type
  description = "Type of resource created"
}

output "vm_target_ips" {
  value = var.resource_type == "vm" ? {
    for key, instance in local.instance_map :
    key => instance.ip_address
  } : {}
  description = "Map of static IP addresses configured for VMs via cloud-init"
}

output "vm_hostnames" {
  value = local.vm_hostnames
  description = "Map of generated hostnames for VMs or LXC containers"
}