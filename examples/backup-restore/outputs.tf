##############################################################################
# Outputs
##############################################################################
output "restored_icd_elasticsearch_id" {
  description = "Restored elasticsearch instance id"
  value       = module.restored_icd_elasticsearch.id
}

output "restored_icd_elasticsearch_version" {
  description = "Restored elasticsearch instance version"
  value       = module.restored_icd_elasticsearch.version
}
