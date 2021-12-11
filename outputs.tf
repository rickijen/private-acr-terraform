
output "container_registry_id" {
  value = "${module.container-registry.container_registry_id}"
}

# Admin user name is the same as registry name
output "container_registry_admin_username" {
  value = "${module.container-registry.container_registry_admin_username}"
}

output "container_registry_name" {
  value = "${module.container-registry.container_registry_admin_username}"
}

output "container_registry_private_dns_zone_domain" {
  value = "${module.container-registry.container_registry_private_dns_zone_domain}"
}
