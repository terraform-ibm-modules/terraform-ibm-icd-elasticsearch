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

output "crn" {
  description = "Elasticsearch instance crn"
  value       = module.elasticsearch.crn
}

output "cbr_rule_ids" {
  description = "CBR rule ids created to restrict Elasticsearch"
  value       = module.elasticsearch.cbr_rule_ids
}

output "service_credentials_json" {
  description = "Service credentials json map"
  value       = module.elasticsearch.service_credentials_json
  sensitive   = true
}

output "service_credentials_object" {
  description = "Service credentials object"
  value       = module.elasticsearch.service_credentials_object
  sensitive   = true
}

output "adminuser" {
  description = "Database admin user name"
  value       = module.elasticsearch.adminuser
}

output "hostname" {
  description = "Database connection hostname"
  value       = module.elasticsearch.hostname
}

output "port" {
  description = "Database connection port"
  value       = module.elasticsearch.port
}

output "certificate_base64" {
  description = "Database connection certificate"
  value       = module.elasticsearch.certificate_base64
  sensitive   = true
}
