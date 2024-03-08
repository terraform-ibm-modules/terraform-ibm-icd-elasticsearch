##############################################################################
# Outputs
##############################################################################

output "id" {
  description = "Elasticsearch instance id"
  value       = var.elasticsearch_db_backup_crn == null ? module.icd_elasticsearch[0].id : null
}

output "restored_elasticsearch_db_id" {
  description = "Restored Elasticsearch instance id"
  value       = module.restored_elasticsearch_db.id
}

output "restored_elasticsearch_db_version" {
  description = "Restored Elasticsearch instance version"
  value       = module.restored_elasticsearch_db.version
}
