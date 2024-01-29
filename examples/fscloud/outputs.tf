##############################################################################
# Outputs
##############################################################################
output "id" {
  description = "Elasticsearch instance id"
  value       = module.elasticsearch.id
}

output "guid" {
  description = "Elasticsearch instance guid"
  value       = module.elasticsearch.guid
}

output "version" {
  description = "Elasticsearch instance version"
  value       = module.elasticsearch.version
}

output "hostname" {
  description = "Database hostname. Only contains value when var.service_credential_names or var.users are set."
  value       = module.elasticsearch.hostname
}

output "port" {
  description = "Database port. Only contains value when var.service_credential_names or var.users are set."
  value       = module.elasticsearch.port
}
