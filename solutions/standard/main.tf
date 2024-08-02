#######################################################################################################################
# Local Variables
#######################################################################################################################

locals {
  existing_kms_instance_crn_split = var.existing_kms_instance_crn != null ? split(":", var.existing_kms_instance_crn) : null
  existing_kms_instance_guid      = var.existing_kms_instance_crn != null ? element(local.existing_kms_instance_crn_split, length(local.existing_kms_instance_crn_split) - 3) : null
  existing_kms_instance_region    = var.existing_kms_instance_crn != null ? element(local.existing_kms_instance_crn_split, length(local.existing_kms_instance_crn_split) - 5) : null

  elasticsearch_key_name      = var.prefix != null ? "${var.prefix}-${var.elasticsearch_key_name}" : var.elasticsearch_key_name
  elasticsearch_key_ring_name = var.prefix != null ? "${var.prefix}-${var.elasticsearch_key_ring_name}" : var.elasticsearch_key_ring_name

  kms_key_crn                      = var.existing_kms_key_crn != null ? var.existing_kms_key_crn : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].crn
  create_cross_account_auth_policy = !var.skip_iam_authorization_policy && var.ibmcloud_kms_api_key != null
  kms_service_name = local.kms_key_crn != null ? (
    can(regex(".*kms.*", local.kms_key_crn)) ? "kms" : can(regex(".*hs-crypto.*", local.kms_key_crn)) ? "hs-crypto" : null
  ) : null
}

#######################################################################################################################
# Resource Group
#######################################################################################################################

module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.1.6"
  resource_group_name          = var.use_existing_resource_group == false ? (var.prefix != null ? "${var.prefix}-${var.resource_group_name}" : var.resource_group_name) : null
  existing_resource_group_name = var.use_existing_resource_group == true ? var.resource_group_name : null
}

#######################################################################################################################
# KMS root key for Elasticsearch
#######################################################################################################################

data "ibm_iam_account_settings" "iam_account_settings" {
  count = local.create_cross_account_auth_policy ? 1 : 0
}

resource "ibm_iam_authorization_policy" "kms_policy" {
  count                       = local.create_cross_account_auth_policy ? 1 : 0
  provider                    = ibm.kms
  source_service_account      = data.ibm_iam_account_settings.iam_account_settings[0].account_id
  source_service_name         = "databases-for-elasticsearch"
  source_resource_group_id    = module.resource_group.resource_group_id
  target_service_name         = local.kms_service_name
  target_resource_instance_id = local.existing_kms_instance_guid
  roles                       = ["Reader"]
  description                 = "Allow all Elastic Search instances in the resource group ${module.resource_group.resource_group_id} in the account ${data.ibm_iam_account_settings.iam_account_settings[0].account_id} to read from the ${local.kms_service_name} instance GUID ${local.existing_kms_instance_guid}"
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_authorization_policy" {
  depends_on      = [ibm_iam_authorization_policy.kms_policy]
  create_duration = "30s"
}


module "kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = var.existing_kms_key_crn != null ? 0 : 1 # no need to create any KMS resources if passing an existing key
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "4.15.1"
  create_key_protect_instance = false
  region                      = local.existing_kms_instance_region
  existing_kms_instance_crn   = var.existing_kms_instance_crn
  key_ring_endpoint_type      = var.kms_endpoint_type
  key_endpoint_type           = var.kms_endpoint_type
  keys = [
    {
      key_ring_name         = local.elasticsearch_key_ring_name
      existing_key_ring     = false
      force_delete_key_ring = true
      keys = [
        {
          key_name                 = local.elasticsearch_key_name
          standard_key             = false
          rotation_interval_month  = 3
          dual_auth_delete_enabled = false
          force_delete             = true
        }
      ]
    }
  ]
}

#######################################################################################################################
# Elasticsearch
#######################################################################################################################

module "elasticsearch" {
  source                        = "../../modules/fscloud"
  depends_on                    = [time_sleep.wait_for_authorization_policy]
  resource_group_id             = module.resource_group.resource_group_id
  name                          = var.prefix != null ? "${var.prefix}-${var.name}" : var.name
  region                        = var.region
  plan                          = var.plan
  skip_iam_authorization_policy = var.skip_iam_authorization_policy || local.create_cross_account_auth_policy
  elasticsearch_version         = var.elasticsearch_version
  existing_kms_instance_guid    = local.existing_kms_instance_guid
  kms_key_crn                   = local.kms_key_crn
  access_tags                   = var.access_tags
  tags                          = var.tags
  admin_pass                    = var.admin_pass
  users                         = var.users
  members                       = var.members
  member_host_flavor            = var.member_host_flavor
  member_memory_mb              = var.member_memory_mb
  member_disk_mb                = var.member_disk_mb
  member_cpu_count              = var.member_cpu_count
  auto_scaling                  = var.auto_scaling
  service_credential_names      = var.service_credential_names
  enable_elser_model            = var.enable_elser_model
}

#create a service authorization between Secrets Manager and the target service (Elastic Search)
resource "ibm_iam_authorization_policy" "policy" {
  depends_on                  = [module.elasticsearch]
  source_service_name         = "secrets-manager"
  source_resource_instance_id = var.existing_sm_instance_guid
  target_service_name         = "databases-for-elasticsearch"
  target_resource_instance_id = module.elasticsearch.id
  roles                       = ["Key Manager"]
}

# create service credentials secret
module "secret_manager_service_credential" {
  depends_on                              = [ibm_iam_authorization_policy.policy]
  source                                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                                 = "1.3.2"
  for_each                                = var.service_credential_names
  region                                  = var.region
  secrets_manager_guid                    = var.existing_sm_instance_guid
  secret_group_id                         = var.existing_secret_group_id
  secret_name                             = "${each.key}-es-cert"
  secret_description                      = "Elasticsearch Service Credential Certificate for ${each.key}"
  secret_type                             = "service_credentials" #checkov:skip=CKV_SECRET_6
  service_credentials_source_service_crn  = module.elasticsearch.id
  service_credentials_source_service_role = each.value
}
