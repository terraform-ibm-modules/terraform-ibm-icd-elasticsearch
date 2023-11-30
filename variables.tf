##############################################################################
# Input Variables
##############################################################################

variable "region" {
  type        = string
  description = "The region where you want to deploy your instance."
  default     = "us-south"
}

variable "resource_group_id" {
  type        = string
  description = "The resource group ID where the Elasticsearch instance will be created."
}

variable "name" {
  type        = string
  description = "The name to give the Elasticsearch instance."
}

variable "tags" {
  type        = list(string)
  description = "Tags associated with the instance (Optional, array of strings)."
  default     = []
}

variable "service_endpoints" {
  type        = string
  description = "Sets the endpoint of the instance, valid values are 'public', 'private', or 'public-and-private'"
  default     = "public"

  validation {
    condition     = can(regex("public|public-and-private|private", var.service_endpoints))
    error_message = "Valid values for service_endpoints are 'public', 'public-and-private', and 'private'"
  }
}

variable "elasticsearch_version" {
  type        = string
  description = "Version of Elasticsearch to deploy, must be 8.7, 8.10 or 7.17 (Enterprise plan only or Platinum if 8.10 or above). If no value passed, the current ICD preferred version is used."
  default     = null
  validation {
    condition = anytrue([
      var.elasticsearch_version == null,
      var.elasticsearch_version == "8.7",
      var.elasticsearch_version == "8.10",
      var.elasticsearch_version == "7.17",
    ])
    error_message = "Version must be 8.7, 8.10 or 7.17 (Enterprise plan only or Platinum if 8.10 or above). If no value passed, the current ICD preferred version is used."
  }
}

variable "plan" {
  type        = string
  description = "The name of the service plan that you choose for your Elasticsearch instance"
  default     = "enterprise"
  validation {
    condition = anytrue([
      var.plan == "enterprise",
      var.plan == "platinum",
    ])
    error_message = "Only supported plan is enterprise, or platinum if var.elasticsearch_version is set to 8.10 or above"
  }
}

variable "members" {
  type        = number
  description = "Allocated number of members. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 3
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "member_memory_mb" {
  type        = number
  description = "Allocated memory per-member. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 1024
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "member_cpu_count" {
  type        = number
  description = "Allocated dedicated CPU per member. For shared CPU, set to 0. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 0
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

# Note: Disk can be scaled up but not down
variable "member_disk_mb" {
  type        = number
  description = "Allocated disk per-member. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 5120
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
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
    type     = string # "type" is required to generate the connection string for the outputs.
    role     = optional(string)
  }))
  default     = []
  sensitive   = true
  description = "A list of users that you want to create on the database. Multiple blocks are allowed. The user password must be in the range of 10-32 characters. Be warned that in most case using IAM service credentials (via the var.service_credential_names) is sufficient to control access to the Elasticsearch instance. This blocks creates native elasticsearch database users, more info on that can be found here https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-connection-strings&interface=cli#connection-strings-add-users"
}

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
  description = "Optional rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. See https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling in the IBM Cloud Docs."
  default     = null
}

variable "service_credential_names" {
  description = "Map of name, role for service credentials that you want to create for the database"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for name, role in var.service_credential_names : contains(["Administrator", "Operator", "Viewer", "Editor"], role)])
    error_message = "Valid values for service credential roles are 'Administrator', 'Operator', 'Viewer', and `Editor`"
  }
}

##############################################################
# Encryption
##############################################################

variable "kms_encryption_enabled" {
  type        = bool
  description = "Set this to true to control the encryption keys used to encrypt the data that you store in IBM Cloud® Databases. If set to false, the data is encrypted by using randomly generated keys. For more info on Key Protect integration, see https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect. For more info on HPCS integration, see https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs"
  default     = false
}

variable "kms_key_crn" {
  type        = string
  description = "The root key CRN of a Key Management Services like Key Protect or Hyper Protect Crypto Service (HPCS) that you want to use for disk encryption. Only used if var.kms_encryption_enabled is set to true."
  default     = null
  validation {
    condition = anytrue([
      var.kms_key_crn == null,
      can(regex(".*kms.*", var.kms_key_crn)),
      can(regex(".*hs-crypto.*", var.kms_key_crn)),
    ])
    error_message = "Value must be the root key CRN from either the Key Protect or Hyper Protect Crypto Service (HPCS)"
  }
}

variable "backup_encryption_key_crn" {
  type        = string
  description = "The CRN of a Key Protect key, that you want to use for encrypting disk that holds deployment backups. Only used if var.kms_encryption_enabled is set to true. If no value is passed here, the value passed for the 'kms_key_crn' variable is used, unless 'use_default_backup_encryption_key' is set to 'true'. BYOK for backups is available only in US regions us-south and us-east, and eu-de. Only keys in the us-south and eu-de are durable to region failures. To ensure that your backups are available even if a region failure occurs, you must use a key from us-south or eu-de. Take note that Hyper Protect Crypto Services for IBM Cloud® Databases backups is not currently supported, so if no value is passed here, but a HPCS value is passed for var.kms_key_crn, databases backup encryption will use the default encryption keys."
  default     = null
  validation {
    condition     = var.backup_encryption_key_crn == null ? true : length(regexall("^crn:v1:bluemix:public:kms:(us-south|us-east|eu-de):a/[[:xdigit:]]{32}:[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}:key:[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$", var.backup_encryption_key_crn)) > 0
    error_message = "Valid values for backup_encryption_key_crn is null or a Key Protect key CRN from us-south, us-east or eu-de"
  }
}

variable "use_default_backup_encryption_key" {
  type        = bool
  description = "Set to true to use default ICD randomly generated keys."
  default     = false
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Elasticsearch database instances in the resource group to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing_kms_instance_guid variable. In addition, no policy is created if var.kms_encryption_enabled is set to false."
  default     = false
}

variable "existing_kms_instance_guid" {
  description = "The GUID of the Hyper Protect or Key Protect instance in which the key specified in var.kms_key_crn and var.backup_encryption_key_crn is coming from. Only required if var.kms_encryption_enabled is 'true', var.skip_iam_authorization_policy is 'false', and passing a value for var.kms_key_crn and/or var.backup_encryption_key_crn."
  type        = string
  default     = null
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
  }))
  description = "(Optional, list) List of CBR rules to create"
  default     = []
  # Validation happens in the rule module
}
