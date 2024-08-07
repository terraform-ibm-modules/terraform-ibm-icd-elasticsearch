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

output "hostname" {
  description = "Elasticsearch instance hostname"
  value       = module.elasticsearch.hostname
}

output "port" {
  description = "Elasticsearch instance port"
  value       = module.elasticsearch.port
}

output "service_credential_secrets" {
  description = "Service credential secrets"
  value       = module.secrets_manager_service_credentials.secrets
}

output "service_credential_secret_groups" {
  description = "Service credential secret groups"
  value       = module.secrets_manager_service_credentials.secret_groups
}
