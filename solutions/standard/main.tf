#######################################################################################################################
# Local Variables
#######################################################################################################################

locals {
  existing_kms_instance_crn_split = var.existing_kms_instance_crn != null ? split(":", var.existing_kms_instance_crn) : null
  existing_kms_instance_guid      = var.existing_kms_instance_crn != null ? element(local.existing_kms_instance_crn_split, length(local.existing_kms_instance_crn_split) - 3) : null
  existing_kms_instance_region    = var.existing_kms_instance_crn != null ? element(local.existing_kms_instance_crn_split, length(local.existing_kms_instance_crn_split) - 5) : null

  elasticsearch_key_name      = var.prefix != null ? "${var.prefix}-${var.elasticsearch_key_name}" : var.elasticsearch_key_name
  elasticsearch_key_ring_name = var.prefix != null ? "${var.prefix}-${var.elasticsearch_key_ring_name}" : var.elasticsearch_key_ring_name


  kms_key_crn = var.existing_db_instance_crn != null ? null : (var.existing_kms_key_crn != null ? var.existing_kms_key_crn : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].crn)

  existing_db_instance_guid = var.existing_db_instance_crn != null ? element(split(":", var.existing_db_instance_crn), length(split(":", var.existing_db_instance_crn)) - 3) : null
  use_existing_db_instance  = var.existing_db_instance_crn != null

  create_cross_account_auth_policy = !var.skip_iam_authorization_policy && var.ibmcloud_kms_api_key != null
  create_sm_auth_policy            = var.skip_es_sm_auth_policy || var.existing_secrets_manager_instance_crn == null ? 0 : 1
  kms_service_name = local.kms_key_crn != null ? (
    can(regex(".*kms.*", local.kms_key_crn)) ? "kms" : can(regex(".*hs-crypto.*", local.kms_key_crn)) ? "hs-crypto" : null
  ) : null

  elasticsearch_guid = local.use_existing_db_instance ? data.ibm_database.existing_db_instance[0].guid : module.elasticsearch[0].guid
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
  count           = local.create_cross_account_auth_policy ? 1 : 0
  depends_on      = [ibm_iam_authorization_policy.kms_policy]
  create_duration = "30s"
}

module "kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = var.existing_kms_key_crn != null || local.use_existing_db_instance ? 0 : 1 # no need to create any KMS resources if passing an existing key
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "4.15.13"
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
  count                         = local.use_existing_db_instance ? 0 : 1
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
  admin_pass                    = local.admin_pass
  users                         = var.users
  members                       = var.members
  member_host_flavor            = var.member_host_flavor
  member_memory_mb              = var.member_memory_mb
  member_disk_mb                = var.member_disk_mb
  member_cpu_count              = var.member_cpu_count
  auto_scaling                  = var.auto_scaling
  service_credential_names      = var.service_credential_names
  enable_elser_model            = var.enable_elser_model
  elser_model_type              = var.elser_model_type
}

resource "random_password" "admin_password" {
  count            = var.admin_pass == null ? 1 : 0
  length           = 32
  special          = true
  override_special = "-_"
  min_numeric      = 1
}

# create a service authorization between Secrets Manager and the target service (Elastic Search)
resource "ibm_iam_authorization_policy" "secrets_manager_key_manager" {
  count                       = local.create_sm_auth_policy
  depends_on                  = [module.elasticsearch]
  source_service_name         = "secrets-manager"
  source_resource_instance_id = local.existing_secrets_manager_instance_guid
  target_service_name         = "databases-for-elasticsearch"
  target_resource_instance_id = local.elasticsearch_guid
  roles                       = ["Key Manager"]
  description                 = "Allow Secrets Manager with instance id ${local.existing_secrets_manager_instance_guid} to manage key for the databases-for-elasticsearch instance"
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_es_authorization_policy" {
  count           = local.create_sm_auth_policy
  depends_on      = [ibm_iam_authorization_policy.secrets_manager_key_manager]
  create_duration = "30s"
}

locals {
  service_credential_secrets = [
    for service_credentials in var.service_credential_secrets : {
      secret_group_name        = service_credentials.secret_group_name
      secret_group_description = service_credentials.secret_group_description
      existing_secret_group    = service_credentials.existing_secret_group
      secrets = [
        for secret in service_credentials.service_credentials : {
          secret_name                             = secret.secret_name
          secret_labels                           = secret.secret_labels
          secret_auto_rotation                    = secret.secret_auto_rotation
          secret_auto_rotation_unit               = secret.secret_auto_rotation_unit
          secret_auto_rotation_interval           = secret.secret_auto_rotation_interval
          service_credentials_ttl                 = secret.service_credentials_ttl
          service_credential_secret_description   = secret.service_credential_secret_description
          service_credentials_source_service_role = secret.service_credentials_source_service_role
          service_credentials_source_service_crn  = local.use_existing_db_instance ? data.ibm_database.existing_db_instance[0].id : module.elasticsearch[0].crn
          secret_type                             = "service_credentials" #checkov:skip=CKV_SECRET_6
        }
      ]
    }
  ]

  admin_pass = var.admin_pass == null ? random_password.admin_password[0].result : var.admin_pass
  admin_pass_secret = [{
    secret_group_name     = var.prefix != null && var.admin_pass_sm_secret_group != null ? "${var.prefix}-${var.admin_pass_sm_secret_group}" : var.admin_pass_sm_secret_group
    existing_secret_group = var.use_existing_admin_pass_sm_secret_group
    secrets = [{
      secret_name             = var.prefix != null && var.admin_pass_sm_secret_name != null ? "${var.prefix}-${var.admin_pass_sm_secret_name}" : var.admin_pass_sm_secret_name
      secret_type             = "arbitrary"
      secret_payload_password = local.admin_pass
      }
    ]
  }]
  secrets = concat(local.service_credential_secrets, local.admin_pass_secret)

  existing_secrets_manager_instance_crn_split = var.existing_secrets_manager_instance_crn != null ? split(":", var.existing_secrets_manager_instance_crn) : null
  existing_secrets_manager_instance_guid      = var.existing_secrets_manager_instance_crn != null ? element(local.existing_secrets_manager_instance_crn_split, length(local.existing_secrets_manager_instance_crn_split) - 3) : null
  existing_secrets_manager_instance_region    = var.existing_secrets_manager_instance_crn != null ? element(local.existing_secrets_manager_instance_crn_split, length(local.existing_secrets_manager_instance_crn_split) - 5) : null

  # tflint-ignore: terraform_unused_declarations
  validate_sm_crn = length(local.service_credential_secrets) > 0 && var.existing_secrets_manager_instance_crn == null ? tobool("`existing_secrets_manager_instance_crn` is required when adding service credentials to a secrets manager secret.") : false
  # tflint-ignore: terraform_unused_declarations
  validate_sm_sg = var.existing_secrets_manager_instance_crn != null && var.admin_pass_sm_secret_group == null ? tobool("`admin_pass_sm_secret_group` is required when `existing_secrets_manager_instance_crn` is set.") : false
  # tflint-ignore: terraform_unused_declarations
  validate_sm_sn = var.existing_secrets_manager_instance_crn != null && var.admin_pass_sm_secret_name == null ? tobool("`admin_pass_sm_secret_name` is required when `existing_secrets_manager_instance_crn` is set.") : false
}

module "secrets_manager_service_credentials" {
  count                       = var.existing_secrets_manager_instance_crn == null ? 0 : 1
  depends_on                  = [time_sleep.wait_for_es_authorization_policy]
  source                      = "terraform-ibm-modules/secrets-manager/ibm//modules/secrets"
  version                     = "1.18.6"
  existing_sm_instance_guid   = local.existing_secrets_manager_instance_guid
  existing_sm_instance_region = local.existing_secrets_manager_instance_region
  endpoint_type               = var.existing_secrets_manager_endpoint_type
  secrets                     = local.secrets
}

# this extra block is needed when passing in an existing ES instance - the database data block
# requires a name and resource_id to retrieve the data
data "ibm_resource_instance" "existing_instance_resource" {
  count      = local.use_existing_db_instance ? 1 : 0
  identifier = local.existing_db_instance_guid
}

data "ibm_database" "existing_db_instance" {
  count             = local.use_existing_db_instance ? 1 : 0
  name              = data.ibm_resource_instance.existing_instance_resource[0].name
  resource_group_id = data.ibm_resource_instance.existing_instance_resource[0].resource_group_id
  location          = var.region
  service           = "databases-for-elasticsearch"
}

data "ibm_database_connection" "existing_connection" {
  count         = local.use_existing_db_instance ? 1 : 0
  endpoint_type = "private"
  deployment_id = data.ibm_database.existing_db_instance[0].id
  user_id       = data.ibm_database.existing_db_instance[0].adminuser
  user_type     = "database"
}
