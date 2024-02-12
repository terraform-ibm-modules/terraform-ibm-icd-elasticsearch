output "instance_name" {
  description = "Name of the IBM Elastic search instance"
  value       = module.elasticsearch.instance_name
}

output "instance_id" {
  description = "ID of the IBM Elastic search instance"
  value       = module.elasticsearch.instance_id
}

output "instance_guid" {
  description = "Global identifier of the IBM Elastic search instance"
  value       = module.elasticsearch.instance_guid
}

output "plan" {
  description = "Plan used to create the IBM Elastic search instance"
  value       = module.elasticsearch.plan
}

output "crn" {
  description = "CRN of the resource instance"
  value       = module.elasticsearch.crn
}