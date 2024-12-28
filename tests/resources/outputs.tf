##############################################################################
# Outputs
##############################################################################
output "id" {
  description = "Elasticsearch id"
  value       = module.icd_elasticsearch.id
}

output "version" {
  description = "Enterprise DB instance version"
  value       = module.icd_elasticsearch.version
}

output "adminuser" {
  description = "Database admin user name"
  value       = module.icd_elasticsearch.adminuser
}

output "hostname" {
  description = "Database connection hostname"
  value       = module.icd_elasticsearch.hostname
}

output "port" {
  description = "Database connection port"
  value       = module.icd_elasticsearch.port
}

output "certificate_base64" {
  description = "Database connection certificate"
  value       = module.icd_elasticsearch.certificate_base64
  sensitive   = true
}
