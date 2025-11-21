##############################################################################
# Input Variables
##############################################################################

variable "resource_group_id" {
  type        = string
  description = "The resource group ID where the Databases for Elasticsearch instance is created."
}

variable "name" {
  type        = string
  description = "The name of the Databases for Elasticsearch instance."
}

variable "elasticsearch_version" {
  type        = string
  description = "The version of Databases for Elasticsearch to deploy. Possible values: `8.7`, `8.10`, `8.12`, `8.15`, `8.19`, `9.1` which requires an Enterprise Platinum pricing plan. If no value is specified, the current preferred version for IBM Cloud Databases is used."
  default     = null

  validation {
    condition = anytrue([
      var.elasticsearch_version == null,
      var.elasticsearch_version == "8.7",
      var.elasticsearch_version == "8.10",
      var.elasticsearch_version == "8.12",
      var.elasticsearch_version == "8.15",
      var.elasticsearch_version == "8.19",
      var.elasticsearch_version == "9.1",
    ])
    error_message = "Version must be 8.7, 8.10, 8.12, 8.15, 8.19 or 9.1 (Enterprise or Platinum plan if 8.10 or later)."
  }
}

variable "region" {
  type        = string
  description = "The region where you want to deploy your instance."
  default     = "us-south"
}

variable "plan" {
  type        = string
  description = "The pricing plan for the Databases for Elasticsearch instance. Must be `enterprise` or `platinum` if the `elasticsearch_version` variable is set to `8.10` or later."
  default     = "enterprise"

  validation {
    condition = anytrue([
      var.plan == "enterprise",
      var.plan == "platinum",
    ])
    error_message = "Only the Enterprise and Platinum plans are supported if 'elasticsearch_version' is set to 8.10 or later."
  }
}

##############################################################################
# ICD hosting model properties
##############################################################################

variable "members" {
  type        = number
  description = "The number of members that are allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 3
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "cpu_count" {
  type        = number
  description = "Allocated dedicated CPU per member. For shared CPU, set to 0. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 0
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "disk_mb" {
  type        = number
  description = "The disk that is allocated per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 5120
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "member_host_flavor" {
  type        = string
  description = "Allocated host flavor per member. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  default     = null
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "memory_mb" {
  type        = number
  description = "Allocated memory per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 4096
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "admin_pass" {
  type        = string
  description = "The password for the database administrator. If the admin password is null, the admin user ID cannot be accessed. You can specify more users in a user block."
  default     = null
  sensitive   = true
}

variable "users" {
  type = list(object({
    name     = string
    password = string # pragma: allowlist secret
    type     = optional(string)
    role     = optional(string)
  }))
  description = "A list of users that you want to create on the database. Multiple blocks are allowed. The user password must be 10-32 characters. In most cases, you can use IAM service credentials (by specifying `service_credential_names`) to control access to the database instance. This block creates native database users. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-user-management&interface=ui)."
  default     = []
  sensitive   = true
}

variable "service_credential_names" {
  type        = map(string)
  description = "Map of name, role for service credentials that you want to create for the database"
  default     = {}

  validation {
    condition     = alltrue([for name, role in var.service_credential_names : contains(["Administrator", "Operator", "Viewer", "Editor"], role)])
    error_message = "Valid values for service credential roles are 'Administrator', 'Operator', 'Viewer', and `Editor`"
  }
}

variable "service_endpoints" {
  type        = string
  description = "Specify whether you want to enable the public or private endpoints on the instance. Supported values are 'public', 'private' or 'public-and-private'."
  default     = "public"

  validation {
    condition     = can(regex("^(public|public-and-private|private)$", var.service_endpoints))
    error_message = "Valid values for service_endpoints are 'public', 'public-and-private', and 'private'"
  }
}

variable "tags" {
  type        = list(string)
  description = "The list of tags to be added to the Databases for Elasticsearch instance."
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Databases for Elasticsearch instance created by the module. [Learn more](https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial)."
  default     = []

  validation {
    condition = alltrue([
      for tag in var.access_tags : can(regex("[\\w\\-_\\.]+:[\\w\\-_\\.]+", tag)) && length(tag) <= 128
    ])
    error_message = "Tags must match the regular expression \"[\\w\\-_\\.]+:[\\w\\-_\\.]+\", see https://cloud.ibm.com/docs/account?topic=account-tag&interface=ui#limits for more details"
  }
}

variable "version_upgrade_skip_backup" {
  type        = bool
  description = "Whether to skip taking a backup before upgrading the database version. Attention: Skipping a backup is not recommended. Skipping a backup before a version upgrade is dangerous and may result in data loss if the upgrade fails at any stage — there will be no immediate backup to restore from."
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. This is not a property of the resource and does not prevent deletion outside of terraform. The database can not be deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

variable "timeouts_update" {
  type        = string
  description = "A database update may require a longer timeout for the update to complete. The default is 120 minutes. Set this variable to change the `update` value in the `timeouts` block. [Learn more](https://developer.hashicorp.com/terraform/language/resources/syntax#operation-timeouts)."
  default     = "120m"
}

##############################################################
# Auto Scaling
##############################################################

variable "auto_scaling" {
  type = object({
    disk = object({
      capacity_enabled             = optional(bool, false)
      free_space_less_than_percent = optional(number, 10)
      io_above_percent             = optional(number, 90)
      io_enabled                   = optional(bool, false)
      io_over_period               = optional(string, "15m")
      rate_increase_percent        = optional(number, 10)
      rate_limit_mb_per_member     = optional(number, 3670016)
      rate_period_seconds          = optional(number, 900)
      rate_units                   = optional(string, "mb")
    })
    memory = object({
      io_above_percent         = optional(number, 90)
      io_enabled               = optional(bool, false)
      io_over_period           = optional(string, "15m")
      rate_increase_percent    = optional(number, 10)
      rate_limit_mb_per_member = optional(number, 114688)
      rate_period_seconds      = optional(number, 900)
      rate_units               = optional(string, "mb")
    })
  })
  description = "The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations)."
  default     = null
}

##############################################################
# Encryption
##############################################################

variable "use_ibm_owned_encryption_key" {
  type        = bool
  description = "IBM Cloud Databases will secure your deployment's data at rest automatically with an encryption key that IBM hold. Alternatively, you may select your own Key Management System instance and encryption key (Key Protect or Hyper Protect Crypto Services) by setting this to false. If setting to false, a value must be passed for the `kms_key_crn` input."
  default     = true

  validation {
    condition     = var.use_ibm_owned_encryption_key && (var.kms_key_crn != null || var.backup_encryption_key_crn != null) ? false : true
    error_message = "When 'use_ibm_owned_encryption_key' is true, 'kms_key_crn' and 'backup_encryption_key_crn' must both be null."
  }

  validation {
    condition     = var.use_ibm_owned_encryption_key || var.kms_key_crn != null
    error_message = "When setting 'use_ibm_owned_encryption_key' to false, a value must be passed for 'kms_key_crn'."
  }

  validation {
    condition = (
      var.use_ibm_owned_encryption_key ||
      var.backup_encryption_key_crn == null ||
      (!var.use_default_backup_encryption_key && !var.use_same_kms_key_for_backups)
    )
    error_message = "When passing a value for backup_encryption_key_crn, you should set use_same_kms_key_for_backups to false, use_default_backup_encryption_key to false and use_ibm_owned_encryption_key to false."
  }

  validation {
    condition = (
      var.use_ibm_owned_encryption_key ||
      var.backup_encryption_key_crn != null ||
      var.use_same_kms_key_for_backups
    )
    error_message = "When 'use_same_kms_key_for_backups' is set to false, a value needs to be passed for 'backup_encryption_key_crn'."
  }
}

variable "use_default_backup_encryption_key" {
  type        = bool
  description = "When `use_ibm_owned_encryption_key` is set to false, backups will be encrypted with either the key specified in `kms_key_crn`, or in `backup_encryption_key_crn` if a value is passed. If you do not want to use your own key for backups encryption, you can set this to `true` to use the IBM Cloud Databases default encryption for backups. Alternatively set `use_ibm_owned_encryption_key` to true to use the default encryption for both backups and deployment data."
  default     = false
}

variable "kms_key_crn" {
  type        = string
  description = "The CRN of a Key Protect or Hyper Protect Crypto Services encryption key to encrypt your data. Applies only if `use_ibm_owned_encryption_key` is false. By default this key is used for both deployment data and backups, but this behaviour can be altered using the `use_same_kms_key_for_backups` and `backup_encryption_key_crn` inputs. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null

  validation {
    condition = anytrue([
      var.kms_key_crn == null,
      can(regex(".*kms.*", var.kms_key_crn)),
      can(regex(".*hs-crypto.*", var.kms_key_crn)),
    ])
    error_message = "Value must be the KMS key CRN from a Key Protect or Hyper Protect Crypto Services instance."
  }
}

variable "use_same_kms_key_for_backups" {
  type        = bool
  description = "Set this to false if you wan't to use a different key that you own to encrypt backups. When set to false, a value is required for the `backup_encryption_key_crn` input. Alternatively set `use_default_backup_encryption_key` to true to use the IBM Cloud Databases default encryption. Applies only if `use_ibm_owned_encryption_key` is false. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = true
}

variable "backup_encryption_key_crn" {
  type        = string
  description = "The CRN of a Key Protect or Hyper Protect Crypto Services encryption key that you want to use for encrypting the disk that holds deployment backups. Applies only if `use_ibm_owned_encryption_key` is false and `use_same_kms_key_for_backups` is false. If no value is passed, and `use_same_kms_key_for_backups` is true, the value of `kms_key_crn` is used. Alternatively set `use_default_backup_encryption_key` to true to use the IBM Cloud Databases default encryption. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null

  validation {
    condition = anytrue([
      var.backup_encryption_key_crn == null,
      can(regex(".*kms.*", var.backup_encryption_key_crn)),
      can(regex(".*hs-crypto.*", var.backup_encryption_key_crn)),
    ])
    error_message = "Value must be the KMS key CRN from a Key Protect or Hyper Protect Crypto Services instance in one of the supported backup regions."
  }
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of IAM authorization policies that permits all Databases for Elasticsearch instances in the given resource group 'Reader' access to the Key Protect or Hyper Protect Crypto Services key that was provided in the `kms_key_crn` and `backup_encryption_key_crn` inputs. This policy is required in order to enable KMS encryption, so only skip creation if there is one already present in your account. No policy is created if `use_ibm_owned_encryption_key` is true."
  default     = false
}

##############################################################
# Context-based restriction (CBR)
##############################################################

variable "cbr_rules" {
  type = list(object({
    description = string
    account_id  = string
    rule_contexts = list(object({
      attributes = optional(list(object({
        name  = string
        value = string
    }))) }))
    enforcement_mode = string
    operations = optional(list(object({
      api_types = list(object({
        api_type_id = string
      }))
    })))
  }))
  description = "The context-based restrictions rule to create. Only one rule is allowed."
  default     = []
  # Validation happens in the rule module
  validation {
    condition     = length(var.cbr_rules) <= 1
    error_message = "Only one CBR rule is allowed."
  }
}

##############################################################
# Backup
##############################################################

variable "backup_crn" {
  type        = string
  description = "The CRN of a backup resource to restore from. The backup is created by a database deployment with the same service ID. The backup is loaded after both provisioning is complete and the new deployment that uses that data starts. Specify a backup CRN is in the format `crn:v1:<...>:backup:`. If not specified, the database is provisioned empty."
  default     = null

  validation {
    condition = anytrue([
      var.backup_crn == null,
      can(regex("^crn:.*:backup:", var.backup_crn))
    ])
    error_message = "backup_crn must be null OR start with 'crn:' and contain ':backup:'"
  }
}

variable "enable_elser_model" {
  type        = bool
  description = "Set it to true to install and start the Elastic's Natural Language Processing model. Applies only if also 'plan' is set to 'platinum'. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-elser-embeddings-elasticsearch)"
  default     = false

  validation {
    condition     = !(var.enable_elser_model && var.plan != "platinum")
    error_message = "When 'enable_elser_model' is set to true, the 'plan' must be set to 'platinum' in order to enable ELSER model."
  }

  validation {
    condition = !(
      var.enable_elser_model &&
      !(
        (length(var.service_credential_names) > 0 &&
        length([for k, v in var.service_credential_names : k if v == "Administrator"]) > 0) ||
        var.admin_pass != null
      )
    )
    error_message = "When 'enable_elser_model' is set to true, an Administrator role user must be created using the 'service_credential_names' input, or by passing a value for the 'admin_pass' input."
  }

}

variable "elser_model_type" {
  type        = string
  description = "Trained ELSER model to be used for Elastic's Natural Language Processing. Possible values: `.elser_model_1`, `.elser_model_2` and `.elser_model_2_linux-x86_64`. Applies only if also 'plan' is set to 'platinum'. [Learn more](https://www.elastic.co/guide/en/machine-learning/current/ml-nlp-elser.html)"
  default     = ".elser_model_2_linux-x86_64"
  validation {
    condition     = contains([".elser_model_1", ".elser_model_2", ".elser_model_2_linux-x86_64"], var.elser_model_type)
    error_message = "The specified elser_model_type is not a valid selection!"
  }
}
