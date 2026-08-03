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
  description = "Service credential secrets"
  value       = length(local.service_credential_secrets) > 0 ? module.secrets_manager_service_credentials[0].secrets : null
}

output "next_steps_text" {
  value       = "Your IBM Cloud Databases Gen 2 (VPC) for Elasticsearch instance is ready. You can now take advantage of reduced application response time, achieve cost-optimized performance, low latency, high throughput, in a highly available and scalable solution."
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
  value       = "https://cloud.ibm.com/docs/databases-for-elasticsearch-gen2"
  description = "Secondary URL"
}
