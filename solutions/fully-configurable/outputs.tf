##############################################################################
# Outputs
##############################################################################

output "id" {
  description = "Elasticsearch instance id"
  value       = local.elasticsearch_id
}

output "version" {
  description = "Elasticsearch instance version"
  value       = local.elasticsearch_version
}

output "guid" {
  description = "Elasticsearch instance guid"
  value       = local.elasticsearch_guid
}

output "crn" {
  description = "Elasticsearch instance crn"
  value       = local.elasticsearch_crn
}

output "service_credentials_json" {
  description = "Service credentials json map"
  value       = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].service_credentials_json
  sensitive   = true
}

output "service_credentials_object" {
  description = "Service credentials object"
  value       = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].service_credentials_object
  sensitive   = true
}

output "hostname" {
  description = "Elasticsearch instance hostname"
  value       = local.elasticsearch_hostname
}

output "port" {
  description = "Elasticsearch instance port"
  value       = local.elasticsearch_port
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
  value       = var.enable_kibana_dashboard ? module.code_engine_kibana[0].app[local.code_engine_app_name].endpoint : null
}

output "user_credentials" {
  description = "Kibana/database user credentials for Elasticsearch"
  value = var.enable_kibana_dashboard ? {
    for user in module.elasticsearch[0].users_credentials : user.name => user.password
    if user.name != "kibana_system"
  } : null
  sensitive = true
}
output "cbr_rule_ids" {
  description = "CBR rule ids created to restrict Elasticsearch"
  value       = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].cbr_rule_ids
}

output "adminuser" {
  description = "Database admin user name"
  value       = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].adminuser
}

output "certificate_base64" {
  description = "Database connection certificate"
  value       = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].certificate_base64
  sensitive   = true
}

output "next_steps_text" {
  value       = "Your Database for Elasticsearch instance is ready. You can now take advantage of the flexibility of a semantic search engine with the indexing power of a JSON document database and Vector DB capabilities via a number of built-in features."
  description = "Next steps text"
}

output "next_step_primary_label" {
  value       = "Deployment Details"
  description = "Primary label"
}

output "next_step_primary_url" {
  value       = "https://cloud.ibm.com/services/databases-for-elasticsearch/${local.elasticsearch_crn}"
  description = "Primary URL"
}

output "next_step_secondary_label" {
  value       = "Learn more about Databases for Elasticsearch"
  description = "Secondary label"
}

output "next_step_secondary_url" {
  value       = "https://cloud.ibm.com/docs/databases-for-elasticsearch"
  description = "Secondary URL"
}
