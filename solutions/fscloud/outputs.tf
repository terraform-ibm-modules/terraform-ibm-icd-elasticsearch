output "id" {
  description = "Elasticsearch instance id"
  value       = module.elasticsearch.id
}

output "crn" {
  description = "CRN of the resource instance"
  value       = module.elasticsearch.crn
}
