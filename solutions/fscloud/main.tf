module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.1.4"
  resource_group_name          = var.existing_resource_group == false ? var.resource_group_name : null
  existing_resource_group_name = var.existing_resource_group == true ? var.resource_group_name : null
}

module elasticsearch {
  source                        = "../../modules/fscloud"
  resource_group_id             = module.resource_group.resource_group_id
  name                          = var.name
  region                        = var.region
  plan                          = var.plan
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  elasticsearch_version         = var.elasticsearch_version
  existing_kms_instance_guid    = var.existing_kms_instance_guid
  kms_key_crn                   = var.kms_key_crn
  cbr_rules                     = var.cbr_rules
  access_tags                   = var.access_tags
  tags                          = var.tags
  members                       = var.members
  member_memory_mb              = var.member_memory_mb
  admin_pass                    = var.admin_pass
  users                         = var.users
  member_disk_mb                = var.member_disk_mb
  member_cpu_count              = var.member_cpu_count
  auto_scaling                  = var.auto_scaling
  service_credential_names      = var.service_credential_names
}