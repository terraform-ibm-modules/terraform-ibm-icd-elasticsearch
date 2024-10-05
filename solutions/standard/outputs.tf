##############################################################################
# Outputs
##############################################################################

output "id" {
  description = "Elasticsearch instance id"
  value       = local.use_existing_db_instance ? data.ibm_database.existing_db_instance[0].id : module.elasticsearch[0].id
}

output "guid" {
  description = "Elasticsearch instance guid"
  value       = local.elasticsearch_guid
}

output "version" {
  description = "Elasticsearch instance version"
  value       = local.use_existing_db_instance ? data.ibm_database.existing_db_instance[0].version : module.elasticsearch[0].version
}

output "crn" {
  description = "Elasticsearch instance crn"
  value       = local.use_existing_db_instance ? var.existing_db_instance_crn : module.elasticsearch[0].crn
}

output "cbr_rule_ids" {
  description = "CBR rule ids created to restrict Elasticsearch"
  value       = local.use_existing_db_instance ? null : module.elasticsearch[0].cbr_rule_ids
}

output "service_credentials_json" {
  description = "Service credentials json map"
  value       = local.use_existing_db_instance ? null : module.elasticsearch[0].service_credentials_json
  sensitive   = true
}

output "service_credentials_object" {
  description = "Service credentials object"
  value       = local.use_existing_db_instance ? null : module.elasticsearch[0].service_credentials_object
  sensitive   = true
}

output "hostname" {
  description = "Elasticsearch instance hostname"
  value       = local.use_existing_db_instance ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].hostname : module.elasticsearch[0].hostname
}

output "port" {
  description = "Elasticsearch instance port"
  value       = local.use_existing_db_instance ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].port : module.elasticsearch[0].port
}

output "secrets_manager_secrets" {
  description = "Elasticsearch related secrets stored inside secrets manager"
  value       = length(local.service_credential_secrets) > 0 ? module.secrets_manager_service_credentials[0] : null
}

output "admin_pass" {
  description = "Elasticsearch administrator password"
  value       = local.admin_pass
  sensitive   = true
}

output "kibana_app_endpoint" {
  description = "Code Engine Kibana endpoint URL"
  value       = module.code_engine_kibana.app
  sensitive   = true
}
