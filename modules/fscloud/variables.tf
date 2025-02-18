##############################################################################
# Input Variables
##############################################################################

variable "resource_group_id" {
  type        = string
  description = "The resource group ID where the Elasticsearch instance will be created."
}

variable "name" {
  type        = string
  description = "Name given to the Elasticsearch instance"
}

variable "elasticsearch_version" {
  type        = string
  description = "Version of the Elasticsearch instance. If no value is passed, the current preferred version of IBM Cloud Databases is used."
  default     = null
}

variable "region" {
  type        = string
  description = "The region where you want to deploy your instance. Must be the same region as the Hyper Protect Crypto Services instance."
  default     = "us-south"
}

variable "plan" {
  type        = string
  description = "The name of the service plan that you choose for your Elasticsearch instance"
  default     = "enterprise"
}

##############################################################################
# ICD hosting model properties
##############################################################################

variable "members" {
  type        = number
  description = "Allocated number of members. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 3
}

variable "member_cpu_count" {
  type        = number
  description = "Allocated dedicated CPU per member. For shared CPU, set to 0. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 0
}

variable "member_disk_mb" {
  type        = number
  description = "Allocated disk per-member. [Learn more}(https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 5120
}

variable "member_host_flavor" {
  type        = string
  description = "Allocated host flavor per member. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  default     = null
}

variable "member_memory_mb" {
  type        = number
  description = "Allocated memory per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 4096
}

variable "admin_pass" {
  type        = string
  description = "The password for the database administrator. If the admin password is null then the admin user ID cannot be accessed. More users can be specified in a user block."
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
  description = "A list of users that you want to create on the database. Multiple blocks are allowed. The user password must be in the range of 10-32 characters. Be warned that in most case using IAM service credentials (via the var.service_credential_names) is sufficient to control access to the Elasticsearch instance. This blocks creates native Elasticsearch database users, more info on that can be found here https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-user-management&interface=ui"
  default     = []
  sensitive   = true
}

variable "service_credential_names" {
  type        = map(string)
  description = "Map of name, role for service credentials that you want to create for the database"
  default     = {}
}

variable "tags" {
  type        = list(any)
  description = "Optional list of tags to be added to the Elasticsearch instance."
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Elasticsearch instance created by the module, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial for more details"
  default     = []
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
  description = "Optional rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. See https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations in the IBM Cloud Docs."
  default     = null
}

##############################################################
# Encryption
##############################################################

variable "use_ibm_owned_encryption_key" {
  type        = bool
  description = "Set to true to use the default IBM Cloud® Databases randomly generated keys for disk and backups encryption. To control the encryption keys, use the `kms_key_crn` and `backup_encryption_key_crn` inputs."
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
  description = "Set this to false if you wan't to use a different key that you own to encrypt backups. When set to false, a value is required for the `backup_encryption_key_crn` input. Alternatiely set `use_default_backup_encryption_key` to true to use the IBM Cloud Databases default encryption. Applies only if `use_ibm_owned_encryption_key` is false. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = true
}

variable "backup_encryption_key_crn" {
  type        = string
  description = "The CRN of a Key Protect or Hyper Protect Crypto Services encryption key that you want to use for encrypting the disk that holds deployment backups. Applies only if `use_ibm_owned_encryption_key` is false and `use_same_kms_key_for_backups` is false. If no value is passed, and `use_same_kms_key_for_backups` is true, the value of `kms_key_crn` is used. Alternatively set `use_default_backup_encryption_key` to true to use the IBM Cloud Databases default encryption. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null
}

variable "use_default_backup_encryption_key" {
  type        = bool
  description = "When `use_ibm_owned_encryption_key` is set to false, backups will be encrypted with either the key specified in `kms_key_crn`, or in `backup_encryption_key_crn` if a value is passed. If you do not want to use your own key for backups encryption, you can set this to `true` to use the IBM Cloud Databases default encryption for backups. Alternatively set `use_ibm_owned_encryption_key` to true to use the default encryption for both backups and deployment data."
  default     = false
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
  description = "(Optional, list) List of context-based restrictions rules to create."
  default     = []
}

##############################################################
# Backup
##############################################################

variable "backup_crn" {
  type        = string
  description = "The CRN of a backup resource to restore from. The backup is created by a database deployment with the same service ID. The backup is loaded after provisioning and the new deployment starts up that uses that data. A backup CRN is in the format crn:v1:<…>:backup:. If omitted, the database is provisioned empty."
  default     = null
}

variable "enable_elser_model" {
  type        = bool
  description = "Set it to true to install and start the Elastic's Natural Language Processing model. Applies only if also 'plan' is set to 'platinum'. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-elser-embeddings-elasticsearch)"
  default     = false
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
