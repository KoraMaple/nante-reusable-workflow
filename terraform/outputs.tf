output "vm_target_ip" {
  value = proxmox_vm_qemu.generic_vm.default_ipv4_address
}