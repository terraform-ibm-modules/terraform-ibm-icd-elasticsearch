##############################################################################
# Outputs
##############################################################################

output "id" {
  description = "Elasticsearch instance id"
  value       = local.use_existing_elasticsearch ? data.ibm_database.existing_elasticsearch[0].id : module.elasticsearch.id
}

output "guid" {
  description = "Elasticsearch instance guid"
  value       = local.use_existing_elasticsearch ? data.ibm_database.existing_elasticsearch[0].guid : module.elasticsearch.guid
}

output "version" {
  description = "Elasticsearch instance version"
  value       = local.use_existing_elasticsearch ? data.ibm_database.existing_elasticsearch[0].version : module.elasticsearch.version
}

output "crn" {
  description = "Elasticsearch instance crn"
  value       = local.use_existing_elasticsearch ? data.ibm_database.existing_elasticsearch[0].resource_crn : module.elasticsearch.crn
}

output "cbr_rule_ids" {
  description = "CBR rule ids created to restrict Elasticsearch"
  value       = local.use_existing_elasticsearch ? null : module.elasticsearch.cbr_rule_ids
}

output "service_credentials_json" {
  description = "Service credentials json map"
  value       = local.use_existing_elasticsearch ? null : module.elasticsearch.service_credentials_json
  sensitive   = true
}

output "service_credentials_object" {
  description = "Service credentials object"
  value       = local.use_existing_elasticsearch ? null : module.elasticsearch.service_credentials_object
  sensitive   = true
}

output "hostname" {
  description = "Elasticsearch instance hostname"
  value       = local.use_existing_elasticsearch ? data.ibm_database_connection.existing_connection[0].amqps[0].hosts[0].hostname : module.elasticsearch.hostname
}

output "port" {
  description = "Elasticsearch instance port"
  value       = local.use_existing_elasticsearch ? data.ibm_database_connection.existing_connection[0].amqps[0].hosts[0].port : module.elasticsearch.port
}
