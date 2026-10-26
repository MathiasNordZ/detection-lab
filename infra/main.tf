data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
  region   = var.region
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
  region      = var.region
}

resource "openstack_networking_network_v2" "lab" {
  name           = "${var.lab_name}-net"
  admin_state_up = true
  region         = var.region
}

resource "openstack_networking_subnet_v2" "lab" {
  name            = "${var.lab_name}-subnet"
  network_id      = openstack_networking_network_v2.lab.id
  cidr            = var.lab_cidr
  ip_version      = 4
  dns_nameservers = ["1.1.1.1", "9.9.9.9"]
  region          = var.region
}

resource "openstack_networking_router_v2" "lab" {
  name                = "${var.lab_name}-router"
  external_network_id = data.openstack_networking_network_v2.external.id
  region              = var.region
}

resource "openstack_networking_router_interface_v2" "lab" {
  router_id = openstack_networking_router_v2.lab.id
  subnet_id = openstack_networking_subnet_v2.lab.id
  region    = var.region
}

resource "openstack_networking_secgroup_v2" "lab" {
  name        = "${var.lab_name}-lab"
  description = "Internal traffic for the isolated detection lab."
  region      = var.region
}

resource "openstack_networking_secgroup_rule_v2" "lab_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = null
  remote_ip_prefix  = var.lab_cidr
  security_group_id = openstack_networking_secgroup_v2.lab.id
  region            = var.region
}

resource "openstack_networking_secgroup_rule_v2" "admin_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.trusted_cidr
  security_group_id = openstack_networking_secgroup_v2.admin.id
  region            = var.region
}

resource "openstack_networking_secgroup_v2" "admin" {
  name        = "${var.lab_name}-admin"
  description = "Restricted administrator access to lab control surfaces."
  region      = var.region
}

resource "openstack_networking_secgroup_rule_v2" "admin_web" {
  for_each          = toset(["443", "8443", "8888"])
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.value)
  port_range_max    = tonumber(each.value)
  remote_ip_prefix  = var.trusted_cidr
  security_group_id = openstack_networking_secgroup_v2.admin.id
  region            = var.region
}

locals {
  hosts = {
    soc      = { flavor = var.flavor_soc, fixed_ip = cidrhost(var.lab_cidr, 10), groups = [openstack_networking_secgroup_v2.lab.name, openstack_networking_secgroup_v2.admin.name], disk = var.soc_disk_gb }
    attacker = { flavor = var.flavor_attacker, fixed_ip = cidrhost(var.lab_cidr, 20), groups = [openstack_networking_secgroup_v2.lab.name, openstack_networking_secgroup_v2.admin.name], disk = 30 }
    target   = { flavor = var.flavor_target, fixed_ip = cidrhost(var.lab_cidr, 30), groups = [openstack_networking_secgroup_v2.lab.name], disk = 30 }
  }
}

resource "openstack_compute_instance_v2" "host" {
  for_each        = local.hosts
  name            = "${var.lab_name}-${each.key}"
  flavor_name     = each.value.flavor
  key_pair        = var.keypair_name
  security_groups = each.value.groups
  region          = var.region

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = each.value.disk
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid        = openstack_networking_network_v2.lab.id
    fixed_ip_v4 = each.value.fixed_ip
  }

  metadata = {
    role = each.key
    lab  = var.lab_name
  }

  depends_on = [openstack_networking_router_interface_v2.lab]
}

resource "openstack_networking_floatingip_v2" "soc" {
  pool    = var.external_network_name
  region  = var.region
}

resource "openstack_networking_floatingip_v2" "attacker" {
  pool   = var.external_network_name
  region = var.region
}

resource "openstack_compute_floatingip_associate_v2" "soc" {
  floating_ip = openstack_networking_floatingip_v2.soc.address
  instance_id = openstack_compute_instance_v2.host["soc"].id
  fixed_ip    = local.hosts.soc.fixed_ip
  region      = var.region
}

resource "openstack_compute_floatingip_associate_v2" "attacker" {
  floating_ip = openstack_networking_floatingip_v2.attacker.address
  instance_id = openstack_compute_instance_v2.host["attacker"].id
  fixed_ip    = local.hosts.attacker.fixed_ip
  region      = var.region
}
