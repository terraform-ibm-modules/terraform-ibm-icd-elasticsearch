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

output "kibana_url" {
  description = "Kibana dashboard URL"
  value = var.enable_kibana_dashboard ? (
    var.kibana_public_endpoint ?
    "http://${module.kibana_vsi[0].list[0].floating_ip}:5601" :
    "http://${module.kibana_vsi[0].list[0].ipv4_address}:5601"
  ) : null
}

output "kibana_credentials" {
  description = "Kibana login credentials. Gen2 has no native database users, so this is the same Manager-role service credential used as Kibana's Elasticsearch backend authentication."
  value       = var.enable_kibana_dashboard ? { username = local.kibana_username, password = local.kibana_password } : null
  sensitive   = true
}

output "kibana_ssh_private_key" {
  description = "Generated SSH private key for the Kibana VSI. Null if an existing key was supplied via `kibana_existing_ssh_key_name`."
  value       = var.enable_kibana_dashboard && var.kibana_existing_ssh_key_name == null ? tls_private_key.kibana_ssh_key[0].private_key_pem : null
  sensitive   = true
}
