##############################################################################
# Outputs
##############################################################################

output "id" {
  description = "Elasticsearch id"
  value       = module.icd_elasticsearch.id
}

output "guid" {
  description = "Elasticsearch instance guid"
  value       = module.icd_elasticsearch.guid
}

output "version" {
  description = "Elasticsearch version"
  value       = module.icd_elasticsearch.version
}

output "crn" {
  description = "Elasticsearch instance crn"
  value       = module.icd_elasticsearch.crn
}

output "service_credentials_json" {
  description = "Service credentials json map"
  value       = module.icd_elasticsearch.service_credentials_json
  sensitive   = true
}

output "service_credentials_object" {
  description = "Service credentials object"
  value       = module.icd_elasticsearch.service_credentials_object
  sensitive   = true
}

output "hostname" {
  description = "Elasticsearch instance hostname"
  value       = module.icd_elasticsearch.hostname
}

output "port" {
  description = "Elasticsearch instance port"
  value       = module.icd_elasticsearch.port
}