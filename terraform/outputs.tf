output "vm_ip" {
  value = proxmox_vm_qemu.k3s_node.default_ipv4_address
}