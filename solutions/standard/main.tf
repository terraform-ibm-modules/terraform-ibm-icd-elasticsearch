#######################################################################################################################
# Resource Group
#######################################################################################################################

module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.1.6"
  resource_group_name          = var.use_existing_resource_group == false ? ((var.prefix != null && var.prefix != "") ? "${var.prefix}-${var.resource_group_name}" : var.resource_group_name) : null
  existing_resource_group_name = var.use_existing_resource_group == true ? var.resource_group_name : null
}

#######################################################################################################################
# KMS related variable validation
# (approach based on https://github.com/hashicorp/terraform/issues/25609#issuecomment-1057614400)
#
# TODO: Replace with terraform cross variable validation: https://github.ibm.com/GoldenEye/issues/issues/10836
#######################################################################################################################

locals {
  # tflint-ignore: terraform_unused_declarations
  validate_kms_1 = var.existing_elasticsearch_instance_crn != null ? true : var.use_ibm_owned_encryption_key && (var.existing_kms_instance_crn != null || var.existing_kms_key_crn != null || var.existing_backup_kms_key_crn != null) ? tobool("When setting values for 'existing_kms_instance_crn', 'existing_kms_key_crn' or 'existing_backup_kms_key_crn', the 'use_ibm_owned_encryption_key' input must be set to false.") : true
  # tflint-ignore: terraform_unused_declarations
  validate_kms_2 = var.existing_elasticsearch_instance_crn != null ? true : !var.use_ibm_owned_encryption_key && (var.existing_kms_instance_crn == null && var.existing_kms_key_crn == null) ? tobool("When 'use_ibm_owned_encryption_key' is false, a value is required for either 'existing_kms_instance_crn' (to create a new key), or 'existing_kms_key_crn' to use an existing key.") : true
}

#######################################################################################################################
# KMS encryption key
#######################################################################################################################

locals {
  create_new_kms_key          = var.existing_elasticsearch_instance_crn == null && !var.use_ibm_owned_encryption_key && var.existing_kms_key_crn == null ? 1 : 0 # no need to create any KMS resources if using existing Elasticsearch, passing an existing key, or using IBM owned keys
  elasticsearch_key_name      = (var.prefix != null && var.prefix != "") ? "${var.prefix}-${var.elasticsearch_key_name}" : var.elasticsearch_key_name
  elasticsearch_key_ring_name = (var.prefix != null && var.prefix != "") ? "${var.prefix}-${var.elasticsearch_key_ring_name}" : var.elasticsearch_key_ring_name
}


module "kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = local.create_new_kms_key
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "4.20.0"
  create_key_protect_instance = false
  region                      = local.kms_region
  existing_kms_instance_crn   = var.existing_kms_instance_crn
  key_ring_endpoint_type      = var.kms_endpoint_type
  key_endpoint_type           = var.kms_endpoint_type
  keys = [
    {
      key_ring_name     = local.elasticsearch_key_ring_name
      existing_key_ring = false
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

########################################################################################################################
# Parse KMS info from given CRNs
########################################################################################################################

module "kms_instance_crn_parser" {
  count   = var.existing_kms_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_kms_instance_crn
}

module "kms_key_crn_parser" {
  count   = var.existing_kms_key_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_kms_key_crn
}

module "kms_backup_key_crn_parser" {
  count   = var.existing_backup_kms_key_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_backup_kms_key_crn
}

#######################################################################################################################
# KMS IAM Authorization Policies
#   - only created if user passes a value for 'ibmcloud_kms_api_key' (used when KMS is in different account to Elasticsearch)
#   - if no value passed for 'ibmcloud_kms_api_key', the auth policy is created by the Elasticsearch module
#######################################################################################################################

# Lookup account ID
data "ibm_iam_account_settings" "iam_account_settings" {
}

locals {
  account_id                                  = data.ibm_iam_account_settings.iam_account_settings.account_id
  create_cross_account_kms_auth_policy        = var.existing_elasticsearch_instance_crn == null && !var.skip_es_kms_auth_policy && var.ibmcloud_kms_api_key != null && !var.use_ibm_owned_encryption_key
  create_cross_account_backup_kms_auth_policy = var.existing_elasticsearch_instance_crn == null && !var.skip_es_kms_auth_policy && var.ibmcloud_kms_api_key != null && !var.use_ibm_owned_encryption_key && var.existing_backup_kms_key_crn != null

  # If KMS encryption enabled (and existing ES instance is not being passed), parse details from the existing key if being passed, otherwise get it from the key that the DA creates
  kms_account_id    = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].account_id : module.kms_instance_crn_parser[0].account_id
  kms_service       = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].service_name : module.kms_instance_crn_parser[0].service_name
  kms_instance_guid = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].service_instance : module.kms_instance_crn_parser[0].service_instance
  kms_key_crn       = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_kms_key_crn != null ? var.existing_kms_key_crn : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].crn
  kms_key_id        = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].resource : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].key_id
  kms_region        = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].region : module.kms_instance_crn_parser[0].region

  # If creating KMS cross account policy for backups, parse backup key details from passed in key CRN
  backup_kms_account_id    = local.create_cross_account_backup_kms_auth_policy ? module.kms_backup_key_crn_parser[0].account_id : local.kms_account_id
  backup_kms_service       = local.create_cross_account_backup_kms_auth_policy ? module.kms_backup_key_crn_parser[0].service_name : local.kms_service
  backup_kms_instance_guid = local.create_cross_account_backup_kms_auth_policy ? module.kms_backup_key_crn_parser[0].service_instance : local.kms_instance_guid
  backup_kms_key_id        = local.create_cross_account_backup_kms_auth_policy ? module.kms_backup_key_crn_parser[0].resource : local.kms_key_id

  backup_kms_key_crn = var.existing_elasticsearch_instance_crn != null || var.use_ibm_owned_encryption_key ? null : var.existing_backup_kms_key_crn
  # Always use same key for backups unless user explicially passed a value for 'existing_backup_kms_key_crn'
  use_same_kms_key_for_backups = var.existing_backup_kms_key_crn == null ? true : false
}

# Create auth policy (scoped to exact KMS key)
resource "ibm_iam_authorization_policy" "kms_policy" {
  count                    = local.create_cross_account_kms_auth_policy ? 1 : 0
  provider                 = ibm.kms
  source_service_account   = local.account_id
  source_service_name      = "databases-for-elasticsearch"
  source_resource_group_id = module.resource_group.resource_group_id
  roles                    = ["Reader"]
  description              = "Allow all Elastic Search instances in the resource group ${module.resource_group.resource_group_id} in the account ${local.account_id} to read the ${local.kms_service} key ${local.kms_key_id} from the instance GUID ${local.kms_instance_guid}"
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = local.kms_service
  }
  resource_attributes {
    name     = "accountId"
    operator = "stringEquals"
    value    = local.kms_account_id
  }
  resource_attributes {
    name     = "serviceInstance"
    operator = "stringEquals"
    value    = local.kms_instance_guid
  }
  resource_attributes {
    name     = "resourceType"
    operator = "stringEquals"
    value    = "key"
  }
  resource_attributes {
    name     = "resource"
    operator = "stringEquals"
    value    = local.kms_key_id
  }
  # Scope of policy now includes the key, so ensure to create new policy before
  # destroying old one to prevent any disruption to every day services.
  lifecycle {
    create_before_destroy = true
  }
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_authorization_policy" {
  count           = local.create_cross_account_kms_auth_policy ? 1 : 0
  depends_on      = [ibm_iam_authorization_policy.kms_policy]
  create_duration = "30s"
}

# Create auth policy (scoped to exact KMS key for backups)
resource "ibm_iam_authorization_policy" "backup_kms_policy" {
  count                    = local.create_cross_account_backup_kms_auth_policy ? 1 : 0
  provider                 = ibm.kms
  source_service_account   = local.account_id
  source_service_name      = "databases-for-elasticsearch"
  source_resource_group_id = module.resource_group.resource_group_id
  roles                    = ["Reader"]
  description              = "Allow all Elastic Search instances in the resource group ${module.resource_group.resource_group_id} in the account ${local.account_id} to read the ${local.backup_kms_service} key ${local.backup_kms_key_id} from the instance GUID ${local.backup_kms_instance_guid}"
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = local.backup_kms_service
  }
  resource_attributes {
    name     = "accountId"
    operator = "stringEquals"
    value    = local.backup_kms_account_id
  }
  resource_attributes {
    name     = "serviceInstance"
    operator = "stringEquals"
    value    = local.backup_kms_instance_guid
  }
  resource_attributes {
    name     = "resourceType"
    operator = "stringEquals"
    value    = "key"
  }
  resource_attributes {
    name     = "resource"
    operator = "stringEquals"
    value    = local.backup_kms_key_id
  }
  # Scope of policy now includes the key, so ensure to create new policy before
  # destroying old one to prevent any disruption to every day services.
  lifecycle {
    create_before_destroy = true
  }
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_backup_kms_authorization_policy" {
  count           = local.create_cross_account_backup_kms_auth_policy ? 1 : 0
  depends_on      = [ibm_iam_authorization_policy.backup_kms_policy]
  create_duration = "30s"
}

#######################################################################################################################
# Elasticsearch admin password
#######################################################################################################################

resource "random_password" "admin_password" {
  count            = var.admin_pass == null ? 1 : 0
  length           = 32
  special          = true
  override_special = "-_"
  min_numeric      = 1
}

locals {
  # _- are invalid first characters
  # if - replace first char with J
  # elseif _ replace first char with K
  # else use asis
  generated_admin_password = startswith(random_password.admin_password[0].result, "-") ? "J${substr(random_password.admin_password[0].result, 1, -1)}" : startswith(random_password.admin_password[0].result, "_") ? "K${substr(random_password.admin_password[0].result, 1, -1)}" : random_password.admin_password[0].result

  # admin password to use
  admin_pass = var.admin_pass == null ? local.generated_admin_password : var.admin_pass
}

#######################################################################################################################
# Elasticsearch
#######################################################################################################################

# Look up existing instance details if user passes one
module "es_instance_crn_parser" {
  count   = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_elasticsearch_instance_crn
}

# Existing instance local vars
locals {
  existing_elasticsearch_guid   = var.existing_elasticsearch_instance_crn != null ? module.es_instance_crn_parser[0].service_instance : null
  existing_elasticsearch_region = var.existing_elasticsearch_instance_crn != null ? module.es_instance_crn_parser[0].region : null

  # Validate the region input matches region detected in existing instance CRN (approach based on https://github.com/hashicorp/terraform/issues/25609#issuecomment-1057614400)
  # tflint-ignore: terraform_unused_declarations
  validate_existing_instance_region = var.existing_elasticsearch_instance_crn != null && var.region != local.existing_elasticsearch_region ? tobool("The region detected in the 'existing_elasticsearch_instance_crn' value must match the value of the 'region' input variable when passing an existing instance.") : true
}

# Do a data lookup on the resource GUID to get more info that is needed for the 'ibm_database' data lookup below
data "ibm_resource_instance" "existing_instance_resource" {
  count      = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  identifier = local.existing_elasticsearch_guid
}

# Lookup details of existing instance
data "ibm_database" "existing_db_instance" {
  count             = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  name              = data.ibm_resource_instance.existing_instance_resource[0].name
  resource_group_id = data.ibm_resource_instance.existing_instance_resource[0].resource_group_id
  location          = var.region
  service           = "databases-for-elasticsearch"
}

# Lookup existing instance connection details
data "ibm_database_connection" "existing_connection" {
  count         = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  endpoint_type = "private"
  deployment_id = data.ibm_database.existing_db_instance[0].id
  user_id       = data.ibm_database.existing_db_instance[0].adminuser
  user_type     = "database"
}

# Create new instance
module "elasticsearch" {
  count                             = var.existing_elasticsearch_instance_crn != null ? 0 : 1
  source                            = "../../modules/fscloud"
  depends_on                        = [time_sleep.wait_for_authorization_policy, time_sleep.wait_for_backup_kms_authorization_policy]
  resource_group_id                 = module.resource_group.resource_group_id
  name                              = (var.prefix != null && var.prefix != "") ? "${var.prefix}-${var.name}" : var.name
  region                            = var.region
  plan                              = var.plan
  skip_iam_authorization_policy     = var.skip_es_kms_auth_policy
  elasticsearch_version             = var.elasticsearch_version
  use_ibm_owned_encryption_key      = var.use_ibm_owned_encryption_key
  kms_key_crn                       = local.kms_key_crn
  backup_encryption_key_crn         = local.backup_kms_key_crn
  use_same_kms_key_for_backups      = local.use_same_kms_key_for_backups
  use_default_backup_encryption_key = var.use_default_backup_encryption_key
  backup_crn                        = var.backup_crn
  access_tags                       = var.access_tags
  tags                              = var.tags
  admin_pass                        = local.admin_pass
  users                             = var.users
  members                           = var.members
  member_host_flavor                = var.member_host_flavor
  member_memory_mb                  = var.member_memory_mb
  member_disk_mb                    = var.member_disk_mb
  member_cpu_count                  = var.member_cpu_count
  auto_scaling                      = var.auto_scaling
  service_credential_names          = var.service_credential_names
  enable_elser_model                = var.enable_elser_model
  elser_model_type                  = var.elser_model_type
  cbr_rules                         = var.cbr_rules
}

locals {
  elasticsearch_guid     = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].guid : module.elasticsearch[0].guid
  elasticsearch_id       = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].id : module.elasticsearch[0].id
  elasticsearch_version  = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].version : module.elasticsearch[0].version
  elasticsearch_crn      = var.existing_elasticsearch_instance_crn != null ? var.existing_elasticsearch_instance_crn : module.elasticsearch[0].crn
  elasticsearch_hostname = var.existing_elasticsearch_instance_crn != null ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].hostname : module.elasticsearch[0].hostname
  elasticsearch_port     = var.existing_elasticsearch_instance_crn != null ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].port : module.elasticsearch[0].port
  elasticsearch_cert     = var.existing_elasticsearch_instance_crn != null ? data.ibm_database_connection.existing_connection[0].https[0].certificate[0].certificate_base64 : module.elasticsearch[0].certificate_base64
  elasticsearch_username = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].adminuser : "admin"
}

#######################################################################################################################
# Secrets management
#######################################################################################################################

locals {
  ## Variable validation (approach based on https://github.com/hashicorp/terraform/issues/25609#issuecomment-1057614400)
  # tflint-ignore: terraform_unused_declarations
  validate_sm_crn = length(local.service_credential_secrets) > 0 && var.existing_secrets_manager_instance_crn == null ? tobool("`existing_secrets_manager_instance_crn` is required when adding service credentials to a secrets manager secret.") : false
  # tflint-ignore: terraform_unused_declarations
  validate_sm_sg = var.existing_secrets_manager_instance_crn != null && var.admin_pass_secrets_manager_secret_group == null ? tobool("`admin_pass_secrets_manager_secret_group` is required when `existing_secrets_manager_instance_crn` is set.") : false
  # tflint-ignore: terraform_unused_declarations
  validate_sm_sn = var.existing_secrets_manager_instance_crn != null && var.admin_pass_secrets_manager_secret_name == null ? tobool("`admin_pass_secrets_manager_secret_name` is required when `existing_secrets_manager_instance_crn` is set.") : false

  create_sm_auth_policy = var.skip_elasticsearch_to_secrets_manager_auth_policy || var.existing_secrets_manager_instance_crn == null ? 0 : 1
}

# Parse the Secrets Manager CRN
module "sm_instance_crn_parser" {
  count   = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_secrets_manager_instance_crn
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
  # Build the structure of the service credential type secret
  service_credential_secrets = [
    for service_credentials in var.service_credential_secrets : {
      secret_group_name        = service_credentials.secret_group_name
      secret_group_description = service_credentials.secret_group_description
      existing_secret_group    = service_credentials.existing_secret_group
      secrets = [
        for secret in service_credentials.service_credentials : {
          secret_name                                 = secret.secret_name
          secret_labels                               = secret.secret_labels
          secret_auto_rotation                        = secret.secret_auto_rotation
          secret_auto_rotation_unit                   = secret.secret_auto_rotation_unit
          secret_auto_rotation_interval               = secret.secret_auto_rotation_interval
          service_credentials_ttl                     = secret.service_credentials_ttl
          service_credential_secret_description       = secret.service_credential_secret_description
          service_credentials_source_service_role_crn = secret.service_credentials_source_service_role_crn
          service_credentials_source_service_crn      = local.elasticsearch_crn
          secret_type                                 = "service_credentials" #checkov:skip=CKV_SECRET_6
        }
      ]
    }
  ]

  # Build the structure of the arbitrary credential type secret for admin password
  admin_pass_secret = [{
    secret_group_name     = (var.prefix != null && var.prefix != "") && var.admin_pass_secrets_manager_secret_group != null ? "${var.prefix}-${var.admin_pass_secrets_manager_secret_group}" : var.admin_pass_secrets_manager_secret_group
    existing_secret_group = var.use_existing_admin_pass_secrets_manager_secret_group
    secrets = [{
      secret_name             = (var.prefix != null && var.prefix != "") && var.admin_pass_secrets_manager_secret_name != null ? "${var.prefix}-${var.admin_pass_secrets_manager_secret_name}" : var.admin_pass_secrets_manager_secret_name
      secret_type             = "arbitrary"
      secret_payload_password = local.admin_pass
      }
    ]
  }]

  # Concatinate into 1 secrets object
  secrets = concat(local.service_credential_secrets, local.admin_pass_secret)
  # Parse Secrets Manager details from the CRN
  existing_secrets_manager_instance_guid   = var.existing_secrets_manager_instance_crn != null ? module.sm_instance_crn_parser[0].service_instance : null
  existing_secrets_manager_instance_region = var.existing_secrets_manager_instance_crn != null ? module.sm_instance_crn_parser[0].region : null
}

# Create secret(s)
module "secrets_manager_service_credentials" {
  count                       = var.existing_secrets_manager_instance_crn == null ? 0 : 1
  depends_on                  = [time_sleep.wait_for_es_authorization_policy]
  source                      = "terraform-ibm-modules/secrets-manager/ibm//modules/secrets"
  version                     = "1.24.3"
  existing_sm_instance_guid   = local.existing_secrets_manager_instance_guid
  existing_sm_instance_region = local.existing_secrets_manager_instance_region
  endpoint_type               = var.existing_secrets_manager_endpoint_type
  secrets                     = local.secrets
}

########################################################################################################################
# Code Engine Kibana Dashboard instance
########################################################################################################################

locals {
  default_code_engine_project_name = (var.kibana_code_engine_new_project_name != null && var.kibana_code_engine_new_project_name != "") ? var.kibana_code_engine_new_project_name : "ce-kibana-project"
  default_code_engine_app_name     = (var.kibana_code_engine_new_app_name != null && var.kibana_code_engine_new_app_name != "") ? var.kibana_code_engine_new_app_name : "ce-kibana-app"
  code_engine_project_id           = var.existing_code_engine_project_id != null ? var.existing_code_engine_project_id : null
  code_engine_project_name = local.code_engine_project_id != null ? null : (var.prefix != null && var.prefix != "") ? "${var.prefix}-${var.kibana_code_engine_new_project_name}" : var.kibana_code_engine_new_project_name
  code_engine_app_name             = (var.prefix != null && var.prefix != "") ? "${var.prefix}-${local.default_code_engine_app_name}" : local.default_code_engine_app_name
  kibana_version                   = var.enable_kibana_dashboard ? jsondecode(data.http.es_metadata[0].response_body).version.number : null
}

data "http" "es_metadata" {
  count       = var.enable_kibana_dashboard ? 1 : 0
  url         = "https://${local.elasticsearch_username}:${local.admin_pass}@${local.elasticsearch_hostname}:${local.elasticsearch_port}"
  ca_cert_pem = base64decode(local.elasticsearch_cert)
}

module "code_engine_kibana" {
  count               = var.enable_kibana_dashboard ? 1 : 0
  source              = "terraform-ibm-modules/code-engine/ibm"
  version             = "3.2.0"
  resource_group_id   = module.resource_group.resource_group_id
  project_name        = local.code_engine_project_name
  existing_project_id = local.code_engine_project_id
  secrets = {
    "es-secret" = {
      format = "generic"
      data = {
        "ELASTICSEARCH_PASSWORD" = local.admin_pass
      }
    }
  }

  apps = {
    (local.code_engine_app_name) = {
      image_reference = var.kibana_image_digest != null ? "${var.kibana_registry_namespace_image}@${var.kibana_image_digest}" : "${var.kibana_registry_namespace_image}:${local.kibana_version}"
      image_port      = var.kibana_image_port
      run_env_variables = [{
        type  = "literal"
        name  = "ELASTICSEARCH_HOSTS"
        value = "[\"https://${local.elasticsearch_hostname}:${local.elasticsearch_port}\"]"
        },
        {
          type  = "literal"
          name  = "ELASTICSEARCH_USERNAME"
          value = local.elasticsearch_username
        },
        {
          type      = "secret_key_reference"
          name      = "ELASTICSEARCH_PASSWORD"
          key       = "ELASTICSEARCH_PASSWORD"
          reference = "es-secret"
        },
        {
          type  = "literal"
          name  = "ELASTICSEARCH_SSL_ENABLED"
          value = "true"
        },
        {
          type  = "literal"
          name  = "SERVER_HOST"
          value = "0.0.0.0"
        },
        {
          type  = "literal"
          name  = "ELASTICSEARCH_SSL_VERIFICATIONMODE"
          value = "none"
        }
      ]
      scale_min_instances     = 1
      scale_max_instances     = 3
      managed_domain_mappings = var.kibana_visibility
    }
  }
}
