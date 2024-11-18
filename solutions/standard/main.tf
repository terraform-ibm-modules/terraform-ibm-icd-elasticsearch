#######################################################################################################################
# Local Variables
#######################################################################################################################

locals {
  existing_kms_instance_crn_split = var.existing_kms_instance_crn != null ? split(":", var.existing_kms_instance_crn) : null
  existing_kms_instance_guid      = var.existing_kms_instance_crn != null ? element(local.existing_kms_instance_crn_split, length(local.existing_kms_instance_crn_split) - 3) : null
  existing_kms_instance_region    = var.existing_kms_instance_crn != null ? element(local.existing_kms_instance_crn_split, length(local.existing_kms_instance_crn_split) - 5) : null

  elasticsearch_key_name      = var.prefix != null ? "${var.prefix}-${var.elasticsearch_key_name}" : var.elasticsearch_key_name
  elasticsearch_key_ring_name = var.prefix != null ? "${var.prefix}-${var.elasticsearch_key_ring_name}" : var.elasticsearch_key_ring_name


  existing_db_instance_guid = var.existing_db_instance_crn != null ? element(split(":", var.existing_db_instance_crn), length(split(":", var.existing_db_instance_crn)) - 3) : null
  use_existing_db_instance  = var.existing_db_instance_crn != null

  create_cross_account_auth_policy = !var.skip_iam_authorization_policy && var.ibmcloud_kms_api_key != null && !var.use_ibm_owned_encryption_key
  create_sm_auth_policy            = var.skip_es_sm_auth_policy || var.existing_secrets_manager_instance_crn == null ? 0 : 1

  kms_key_crn        = var.existing_db_instance_crn != null ? null : !var.use_ibm_owned_encryption_key ? var.existing_kms_key_crn != null ? var.existing_kms_key_crn : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].crn : null
  parsed_kms_key_crn = local.kms_key_crn != null ? split(":", local.kms_key_crn) : []
  kms_service        = length(local.parsed_kms_key_crn) > 0 ? local.parsed_kms_key_crn[4] : null
  kms_scope          = length(local.parsed_kms_key_crn) > 0 ? local.parsed_kms_key_crn[6] : null
  kms_account_id     = length(local.parsed_kms_key_crn) > 0 ? split("/", local.kms_scope)[1] : null
  kms_key_id         = length(local.parsed_kms_key_crn) > 0 ? local.parsed_kms_key_crn[9] : null

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
  count                    = local.create_cross_account_auth_policy ? 1 : 0
  provider                 = ibm.kms
  source_service_account   = data.ibm_iam_account_settings.iam_account_settings[0].account_id
  source_service_name      = "databases-for-elasticsearch"
  source_resource_group_id = module.resource_group.resource_group_id
  roles                    = ["Reader"]
  description              = "Allow all Elastic Search instances in the resource group ${module.resource_group.resource_group_id} in the account ${data.ibm_iam_account_settings.iam_account_settings[0].account_id} to read the ${local.kms_service} key ${local.kms_key_id} from the instance GUID ${local.existing_kms_instance_guid}"
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
    value    = local.existing_kms_instance_guid
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
  count           = local.create_cross_account_auth_policy ? 1 : 0
  depends_on      = [ibm_iam_authorization_policy.kms_policy]
  create_duration = "30s"
}

module "kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = var.existing_kms_key_crn != null || local.use_existing_db_instance || var.use_ibm_owned_encryption_key ? 0 : 1 # no need to create any KMS resources if passing an existing key or using IBM owned keys
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "4.16.9"
  create_key_protect_instance = false
  region                      = local.existing_kms_instance_region
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


#######################################################################################################################
# KMS backup encryption key for Elasticsearch
#######################################################################################################################

locals {
  existing_backup_kms_instance_guid   = var.existing_backup_kms_instance_crn != null ? module.backup_kms_instance_crn_parser[0].service_instance : null
  existing_backup_kms_instance_region = var.existing_backup_kms_instance_crn != null ? module.backup_kms_instance_crn_parser[0].region : null

  backup_key_name         = var.prefix != null ? "${var.prefix}-backup-encryption-${var.elasticsearch_key_name}" : "backup-encryption-${var.elasticsearch_key_name}"
  backup_key_ring_name    = var.prefix != null ? "${var.prefix}-backup-encryption-${var.elasticsearch_key_ring_name}" : "backup-encryption-${var.elasticsearch_key_ring_name}"
  backup_kms_key_crn      = var.existing_backup_kms_key_crn != null ? var.existing_backup_kms_key_crn : var.existing_backup_kms_instance_crn != null ? module.backup_kms[0].keys[format("%s.%s", local.backup_key_ring_name, local.backup_key_name)].crn : null
  backup_kms_service_name = var.existing_backup_kms_instance_crn != null ? module.backup_kms_instance_crn_parser[0].service_name : null

  parsed_backup_kms_key_crn = local.backup_kms_key_crn != null ? split(":", local.backup_kms_key_crn) : []
  backup_kms_key_id         = length(local.parsed_backup_kms_key_crn) > 0 ? local.parsed_backup_kms_key_crn[9] : null
}

# If existing KMS intance CRN passed, parse details from it
module "backup_kms_instance_crn_parser" {
  count   = var.existing_backup_kms_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_backup_kms_instance_crn
}

resource "ibm_iam_authorization_policy" "backup_kms_policy_cross_account" {
  count                       = local.existing_backup_kms_instance_guid == local.existing_kms_instance_guid ? 0 : var.existing_backup_kms_key_crn != null ? 0 : var.existing_backup_kms_instance_crn != null ? !var.skip_iam_authorization_policy ? 1 : 0 : 0
  provider                    = ibm.kms
  source_service_account      = local.create_cross_account_auth_policy ? data.ibm_iam_account_settings.iam_account_settings[0].account_id : null
  source_service_name         = "databases-for-elasticsearch"
  source_resource_group_id    = module.resource_group.resource_group_id
  target_service_name         = local.backup_kms_service_name
  target_resource_instance_id = local.existing_backup_kms_instance_guid
  roles                       = ["Reader"]
  description                 = "Allow all Elasticsearch instances in the resource group ${module.resource_group.resource_group_id} to read from the ${local.backup_kms_service_name} instance GUID ${local.existing_backup_kms_instance_guid}"
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_backup_kms_authorization_policy_cross_account" {
  depends_on      = [ibm_iam_authorization_policy.backup_kms_policy_cross_account]
  create_duration = "30s"
}

resource "ibm_iam_authorization_policy" "backup_kms_policy" {
  count                    = !var.skip_iam_authorization_policy && local.backup_kms_key_id != null ? 1 : 0
  source_service_account   = data.ibm_iam_account_settings.iam_account_settings[0].account_id
  source_service_name      = "databases-for-elasticsearch"
  source_resource_group_id = module.resource_group.resource_group_id
  roles                    = ["Reader"]
  description              = "Allow all Elastic Search instances in the resource group ${module.resource_group.resource_group_id} in the account ${data.ibm_iam_account_settings.iam_account_settings[0].account_id} to read the ${local.kms_service} key ${local.kms_key_id} from the instance GUID ${local.existing_kms_instance_guid}"
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
    value    = local.existing_kms_instance_guid
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
  depends_on      = [ibm_iam_authorization_policy.backup_kms_policy]
  create_duration = "30s"
}

module "backup_kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = var.use_ibm_owned_encryption_key ? 0 : var.existing_backup_kms_key_crn != null ? 0 : var.existing_backup_kms_instance_crn != null ? 1 : 0
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "4.16.8"
  create_key_protect_instance = false
  region                      = local.existing_backup_kms_instance_region
  existing_kms_instance_crn   = var.existing_backup_kms_instance_crn
  key_ring_endpoint_type      = var.kms_endpoint_type
  key_endpoint_type           = var.kms_endpoint_type
  keys = [
    {
      key_ring_name         = local.backup_key_ring_name
      existing_key_ring     = false
      force_delete_key_ring = true
      keys = [
        {
          key_name                 = local.backup_key_name
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
  depends_on                    = [time_sleep.wait_for_authorization_policy, time_sleep.wait_for_backup_kms_authorization_policy, time_sleep.wait_for_backup_kms_authorization_policy_cross_account]
  resource_group_id             = module.resource_group.resource_group_id
  name                          = var.prefix != null ? "${var.prefix}-${var.name}" : var.name
  region                        = var.region
  plan                          = var.plan
  skip_iam_authorization_policy = var.skip_iam_authorization_policy || local.create_cross_account_auth_policy
  elasticsearch_version         = var.elasticsearch_version
  existing_kms_instance_guid    = local.existing_kms_instance_guid
  use_ibm_owned_encryption_key  = var.use_ibm_owned_encryption_key
  kms_key_crn                   = local.kms_key_crn
  backup_encryption_key_crn     = local.backup_kms_key_crn
  backup_crn                    = var.backup_crn
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
  version                     = "1.18.14"
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

########################################################################################################################
# Code Engine Kibana Dashboard instance
########################################################################################################################

locals {

  code_engine_project_id   = var.existing_code_engine_project_id != null ? var.existing_code_engine_project_id : null
  code_engine_project_name = local.code_engine_project_id != null ? null : var.prefix != null ? "${var.prefix}-code-engine-kibana-project" : "ce-kibana-project"
  code_engine_app_name     = var.prefix != null ? "${var.prefix}-kibana-app" : "ce-kibana-app"

  es_host         = local.use_existing_db_instance ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].hostname : module.elasticsearch[0].hostname
  es_port         = local.use_existing_db_instance ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].port : module.elasticsearch[0].port
  es_cert         = local.use_existing_db_instance ? data.ibm_database_connection.existing_connection[0].https[0].certificate[0].certificate_base64 : module.elasticsearch[0].certificate_base64
  es_username     = local.use_existing_db_instance ? data.ibm_database.existing_db_instance[0].adminuser : "admin"
  es_password     = local.admin_pass
  es_data         = var.enable_kibana_dashboard ? jsondecode(data.http.es_metadata[0].response_body) : null
  es_full_version = var.enable_kibana_dashboard ? (var.elasticsearch_full_version != null ? var.elasticsearch_full_version : local.es_data.version.number) : null

}

data "http" "es_metadata" {
  count       = var.enable_kibana_dashboard ? 1 : 0
  url         = "https://${local.es_username}:${local.es_password}@${local.es_host}:${local.es_port}"
  ca_cert_pem = base64decode(local.es_cert)
}

module "code_engine_kibana" {
  count               = var.enable_kibana_dashboard ? 1 : 0
  source              = "terraform-ibm-modules/code-engine/ibm"
  version             = "2.0.7"
  resource_group_id   = module.resource_group.resource_group_id
  project_name        = local.code_engine_project_name
  existing_project_id = local.code_engine_project_id
  secrets = {
    "es-secret" = {
      format = "generic"
      data = {
        "ELASTICSEARCH_PASSWORD" = local.es_password
      }
    }
  }

  apps = {
    (local.code_engine_app_name) = {
      image_reference = "docker.elastic.co/kibana/kibana:${local.es_full_version}"
      image_port      = 5601
      run_env_variables = [{
        type  = "literal"
        name  = "ELASTICSEARCH_HOSTS"
        value = "[\"https://${local.es_host}:${local.es_port}\"]"
        },
        {
          type  = "literal"
          name  = "ELASTICSEARCH_USERNAME"
          value = local.es_username
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
      scale_min_instances = 1
      scale_max_instances = 3
    }
  }
}
