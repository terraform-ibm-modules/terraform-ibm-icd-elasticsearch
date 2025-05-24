##############################################################################
# Outputs
##############################################################################

output "id" {
  description = "Elasticsearch instance id"
  value       = local.elasticsearch_id
}

output "guid" {
  description = "Elasticsearch instance guid"
  value       = local.elasticsearch_guid
}

output "version" {
  description = "Elasticsearch instance version"
  value       = local.elasticsearch_version
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

output "kibana_app_login_username" {
  description = "Kibana dashboard login username"
  value       = local.kibana_app_login_username
}

output "kibana_app_login_password" {
  description = "Kibana dashboard login password"
  value       = local.kibana_app_login_password
  sensitive   = true
}

output "kibana_app_endpoint" {
  description = "Code Engine Kibana endpoint URL"
  value       = var.enable_kibana_dashboard ? module.code_engine_kibana[0].app[local.code_engine_app_name].endpoint : null
}
