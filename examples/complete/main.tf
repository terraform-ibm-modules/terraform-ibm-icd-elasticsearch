##############################################################################
# Locals
##############################################################################

locals {
  secrets_manager_guid   = var.existing_sm_instance_guid == null ? module.secrets_manager[0].secrets_manager_guid : var.existing_sm_instance_guid
  secrets_manager_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
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
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.3.0"
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
  version           = "5.1.18"
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
  source = "../../"
  # remove the above line and uncomment the below 2 lines to consume the module from the registry
  # source            = "terraform-ibm-modules/icd-elasticsearch/ibm"
  # version           = "X.Y.Z" # Replace "X.Y.Z" with a release version to lock into a specific release
  resource_group_id     = module.resource_group.resource_group_id
  name                  = "${var.prefix}-elasticsearch"
  elasticsearch_version = var.elasticsearch_version
  admin_pass            = var.admin_pass
  users                 = var.users
  region                = var.region
  plan                  = var.plan
  access_tags           = var.access_tags
  tags                  = var.resource_tags
  deletion_protection   = false
  auto_scaling          = var.auto_scaling
  # Example of how to use different KMS keys for data and backups
  use_ibm_owned_encryption_key = false
  use_same_kms_key_for_backups = false
  kms_key_crn                  = module.key_protect_all_inclusive.keys["icd.${local.backups_key_name}"].crn
  service_credential_names     = local.service_credential_names
  member_host_flavor           = "multitenant"
  memory_mb                    = 4096
  backup_encryption_key_crn    = module.key_protect_all_inclusive.keys["icd.${local.data_key_name}"].crn
}

##############################################################################
## Secrets Manager layer
##############################################################################

# Create Secrets Manager Instance (if not using existing one)
module "secrets_manager" {
  count                = var.existing_sm_instance_guid == null ? 1 : 0
  source               = "terraform-ibm-modules/secrets-manager/ibm"
  version              = "2.7.2"
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
  version              = "1.3.13"
  region               = local.secrets_manager_region
  secrets_manager_guid = local.secrets_manager_guid
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_group_name        = "${var.prefix}-es-secrets"
  secret_group_description = "service secret-group" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

# Add service credentials to secret manager as a username/password secret type in the created secret group
module "secrets_manager_service_credentials_user_pass" {
  source                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                 = "1.7.0"
  for_each                = local.service_credential_names
  region                  = local.secrets_manager_region
  secrets_manager_guid    = local.secrets_manager_guid
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
  region                    = local.secrets_manager_region
  secrets_manager_guid      = local.secrets_manager_guid
  secret_group_id           = module.secrets_manager_secrets_group.secret_group_id
  secret_name               = "${var.prefix}-es-cert"
  secret_description        = "Elasticsearch Service Credential Certificate"
  imported_cert_certificate = base64decode(module.icd_elasticsearch.service_credentials_object.certificate)
  secret_type               = "imported_cert" #checkov:skip=CKV_SECRET_6
}
