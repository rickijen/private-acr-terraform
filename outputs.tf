
output "container_registry_id" {
  value = "${module.container-registry.container_registry_id}"
}

output "container_registry_admin_username" {
  value = "${module.container-registry.container_registry_admin_username}"
}

output "container_registry_admin_password" {
  value = "${module.container-registry.container_registry_admin_password}"
  sensitive = true
}

output "container_registry_private_endpoint_ip_addresses" {
  value = "${module.container-registry.container_registry_private_endpoint_ip_addresses}"
}

output "container_registry_private_dns_zone_domain" {
  value = "${module.container-registry.container_registry_private_dns_zone_domain}"
}
