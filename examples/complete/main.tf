locals {
  sm_guid   = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid
  sm_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
}

##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source = "git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git?ref=v1.1.4"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Key Protect All Inclusive
##############################################################################

module "key_protect_all_inclusive" {
  source            = "terraform-ibm-modules/key-protect-all-inclusive/ibm"
  version           = "4.4.2"
  resource_group_id = module.resource_group.resource_group_id
  # Only us-south, eu-de backup encryption keys are supported. See https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok for details.
  # Note: Database instance and Key Protect must be created on the same region.
  region                    = var.region
  key_protect_instance_name = "${var.prefix}-kp"
  resource_tags             = var.resource_tags
  key_map                   = { "icd" = ["${var.prefix}-elasticsearch"] }
}

##############################################################################
# Elasticsearch
##############################################################################

module "icd_elasticsearch" {
  source                     = "../../"
  resource_group_id          = module.resource_group.resource_group_id
  name                       = "${var.prefix}-elasticsearch"
  region                     = var.region
  plan                       = var.plan
  kms_encryption_enabled     = true
  access_tags                = var.access_tags
  admin_pass                 = var.admin_pass
  users                      = var.users
  existing_kms_instance_guid = module.key_protect_all_inclusive.key_protect_guid
  service_credential_names   = var.service_credential_names
  elasticsearch_version      = var.elasticsearch_version
  kms_key_crn                = module.key_protect_all_inclusive.keys["icd.${var.prefix}-elasticsearch"].crn
  tags                       = var.resource_tags
  auto_scaling               = var.auto_scaling
}

# wait 15 secs to allow IAM credential access to kick in before configuring instance
# without the wait, you can intermittently get "Error 401 (Unauthorized)"
resource "time_sleep" "wait" {
  depends_on      = [module.icd_elasticsearch]
  create_duration = "15s"
}

resource "elasticsearch_index" "test" {
  depends_on         = [time_sleep.wait]
  name               = "terraform-test"
  number_of_shards   = 1
  number_of_replicas = 1
}

resource "elasticsearch_cluster_settings" "global" {
  depends_on                  = [time_sleep.wait]
  cluster_max_shards_per_node = 10
  action_auto_create_index    = "my-index-000001,index10,-index1*,+ind*"
}

##############################################################################
## Secrets Manager layer
##############################################################################

# Create Secrets Manager Instance (if not using existing one)
resource "ibm_resource_instance" "secrets_manager" {
  count             = var.existing_sm_instance_guid == null ? 1 : 0
  name              = "${var.prefix}-sm" #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  service           = "secrets-manager"
  service_endpoints = "public-and-private"
  plan              = "trial"
  location          = var.region
  resource_group_id = module.resource_group.resource_group_id

  timeouts {
    create = "30m" # Extending provisioning time to 30 minutes
  }
}

# Add a Secrets Group to the secret manager instance
module "secrets_manager_secrets_group" {
  source               = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version              = "1.1.3"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_group_name        = "${var.prefix}-es-secrets"
  secret_group_description = "service secret-group" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

# Add service credentials to secret manager as a username/password secret type in the created secret group
module "secrets_manager_service_credentials_user_pass" {
  source                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                 = "1.1.1"
  for_each                = var.service_credential_names
  region                  = local.sm_region
  secrets_manager_guid    = local.sm_guid
  secret_group_id         = module.secrets_manager_secrets_group.secret_group_id
  secret_name             = "${var.prefix}-${each.key}-credentials"
  secret_description      = "Elasticsearch Service Credentials for ${each.key}"
  secret_username         = module.icd_elasticsearch.service_credentials_object.credentials[each.key].username
  secret_payload_password = module.icd_elasticsearch.service_credentials_object.credentials[each.key].password
  secret_type             = "username_password" #checkov:skip=CKV_SECRET_6
}

# Add secrets manager certificate to secret manager as a certificate secret type in the created secret group
module "secrets_manager_service_credentials_cert" {
  source                    = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                   = "1.1.1"
  region                    = local.sm_region
  secrets_manager_guid      = local.sm_guid
  secret_group_id           = module.secrets_manager_secrets_group.secret_group_id
  secret_name               = "${var.prefix}-es-cert"
  secret_description        = "Elasticsearch Service Credential Certificate"
  imported_cert_certificate = base64decode(module.icd_elasticsearch.service_credentials_object.certificate)
  secret_type               = "imported_cert" #checkov:skip=CKV_SECRET_6
}
