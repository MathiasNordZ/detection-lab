output "soc_floating_ip" {
  value = openstack_networking_floatingip_v2.soc.address
}

output "attacker_floating_ip" {
  value = openstack_networking_floatingip_v2.attacker.address
}

output "fixed_ips" {
  value = { for name, host in local.hosts : name => host.fixed_ip }
}

output "dashboard_url" {
  value = "https://${openstack_networking_floatingip_v2.soc.address}"
}

output "iris_url" {
  value = "https://${openstack_networking_floatingip_v2.soc.address}:8443"
}

output "caldera_url" {
  value = "http://${openstack_networking_floatingip_v2.attacker.address}:8888"
}
