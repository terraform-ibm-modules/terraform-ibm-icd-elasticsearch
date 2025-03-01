##############################################################################
# Locals
##############################################################################

locals {
  sm_guid   = var.existing_sm_instance_guid == null ? module.secrets_manager[0].secrets_manager_guid : var.existing_sm_instance_guid
  sm_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
  service_credential_names = {
    "es_admin" : "Administrator",
    "es_operator" : "Operator",
    "es_viewer" : "Viewer",
    "es_editor" : "Editor",
  }
}

##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source = "git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git?ref=v1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Key Protect All Inclusive
##############################################################################

locals {
  data_key_name    = "${var.prefix}-elasticsearch"
  backups_key_name = "${var.prefix}-elasticsearch-backups"
}

module "key_protect_all_inclusive" {
  source            = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version           = "4.20.0"
  resource_group_id = module.resource_group.resource_group_id
  # Only us-south, us-east and eu-de backup encryption keys are supported. See https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok for details.
  # Note: Database instance and Key Protect must be created on the same region.
  region                    = var.region
  key_protect_instance_name = "${var.prefix}-kp"
  resource_tags             = var.resource_tags
  keys = [
    {
      key_ring_name = "icd"
      keys = [
        {
          key_name     = local.data_key_name
          force_delete = true
        },
        {
          key_name     = local.backups_key_name
          force_delete = true
        }
      ]
    }
  ]
}

##############################################################################
# Elasticsearch
##############################################################################

module "icd_elasticsearch" {
  source                   = "../../"
  resource_group_id        = module.resource_group.resource_group_id
  name                     = "${var.prefix}-elasticsearch"
  region                   = var.region
  plan                     = var.plan
  access_tags              = var.access_tags
  admin_pass               = var.admin_pass
  users                    = var.users
  service_credential_names = local.service_credential_names
  elasticsearch_version    = var.elasticsearch_version
  tags                     = var.resource_tags
  auto_scaling             = var.auto_scaling
  member_host_flavor       = "multitenant"
  member_memory_mb         = 4096

  # Example of how to use different KMS keys for data and backups
  use_ibm_owned_encryption_key = false
  use_same_kms_key_for_backups = false
  kms_key_crn                  = module.key_protect_all_inclusive.keys["icd.${local.backups_key_name}"].crn
  backup_encryption_key_crn    = module.key_protect_all_inclusive.keys["icd.${local.data_key_name}"].crn
}


##############################################################################
## Secrets Manager layer
##############################################################################

# Create Secrets Manager Instance (if not using existing one)
module "secrets_manager" {
  count                = var.existing_sm_instance_guid == null ? 1 : 0
  source               = "terraform-ibm-modules/secrets-manager/ibm"
  version              = "1.24.2"
  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  secrets_manager_name = "${var.prefix}-secrets-manager"
  sm_service_plan      = "trial"
  allowed_network      = "public-and-private"
  sm_tags              = var.resource_tags
}

# Add a Secrets Group to the secret manager instance
module "secrets_manager_secrets_group" {
  source               = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version              = "1.2.2"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_group_name        = "${var.prefix}-es-secrets"
  secret_group_description = "service secret-group" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

# Add service credentials to secret manager as a username/password secret type in the created secret group
module "secrets_manager_service_credentials_user_pass" {
  source                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                 = "1.7.0"
  for_each                = local.service_credential_names
  region                  = local.sm_region
  secrets_manager_guid    = local.sm_guid
  secret_group_id         = module.secrets_manager_secrets_group.secret_group_id
  secret_name             = "${var.prefix}-${each.key}-credentials"
  secret_description      = "Elasticsearch Service Credentials for ${each.key}"
  secret_username         = module.icd_elasticsearch.service_credentials_object.credentials[each.key].username
  secret_payload_password = module.icd_elasticsearch.service_credentials_object.credentials[each.key].password
  secret_type             = "username_password" #checkov:skip=CKV_SECRET_6
}

# Add Elasticsearch certificate to secret manager as a certificate secret type in the created secret group
module "secrets_manager_service_credentials_cert" {
  source                    = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                   = "1.7.0"
  region                    = local.sm_region
  secrets_manager_guid      = local.sm_guid
  secret_group_id           = module.secrets_manager_secrets_group.secret_group_id
  secret_name               = "${var.prefix}-es-cert"
  secret_description        = "Elasticsearch Service Credential Certificate"
  imported_cert_certificate = base64decode(module.icd_elasticsearch.service_credentials_object.certificate)
  secret_type               = "imported_cert" #checkov:skip=CKV_SECRET_6
}
