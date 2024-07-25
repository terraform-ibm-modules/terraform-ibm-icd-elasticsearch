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
  description = "The resource group ID where the Databases for Elasticsearch instance is created."
}

variable "name" {
  type        = string
  description = "The name of the Databases for Elasticsearch instance."
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Databases for Elasticsearch instance created by the module. [Learn more](https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial)."
  default     = []
}

variable "tags" {
  type        = list(string)
  description = "The list of tags to be added to the Databases for Elasticsearch instance."
  default     = []
}

variable "service_endpoints" {
  type        = string
  description = "The type of endpoint of the database instance. Possible values: `public`, `private`, `public-and-private`."
  default     = "public"

  validation {
    condition     = can(regex("public|public-and-private|private", var.service_endpoints))
    error_message = "Valid values for service_endpoints are 'public', 'public-and-private', and 'private'"
  }
}

variable "elasticsearch_version" {
  type        = string
  description = "The version of Databases for Elasticsearch to deploy. Possible values: `8.10`, `8.12`, which requires an Enterprise Platinum pricing plan. If no value is specified, the current preferred version for IBM Cloud Databases is used."
  default     = null
  validation {
    condition = anytrue([
      var.elasticsearch_version == null,
      var.elasticsearch_version == "8.10",
      var.elasticsearch_version == "8.12",
    ])
    error_message = "Version must be 8.10 or 8.12 (Enterprise or Platinum plan if 8.10 or later)."
  }
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

variable "members" {
  type        = number
  description = "The number of members that are allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 3
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "member_memory_mb" {
  type        = number
  description = "The memory per member that is allocated. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 4096
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "member_cpu_count" {
  type        = number
  description = "The dedicated CPU per member that is allocated. For shared CPU, set to 0. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 0
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

# Note: Disk can be scaled up but not down
variable "member_disk_mb" {
  type        = number
  description = "The disk that is allocated per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 5120
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "member_host_flavor" {
  type        = string
  description = "The host flavor per member. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  default     = null
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
    password = string           # pragma: allowlist secret
    type     = optional(string) 
    role     = optional(string)
  }))
  default     = []
  sensitive   = true
  description = "The list of users that have access to the database. Multiple blocks are allowed. The user password must be 10-32 characters. In most cases, you can use IAM service credentials (by specifying `service_credential_names`) to control access to the database instance. This block creates native database users. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-user-management&interface=ui)."
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
  description = "The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations)."
  default     = null
}

variable "service_credential_names" {
  description = "The map of name and role for service credentials that you want to create for the database."
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
  description = "Whether to specify the keys used to encrypt data in the database. Specify `true` to identify the encryption keys. If set to `false`, the data is encrypted with randomly generated keys. [Learn more about Key Protect integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect). [Learn more about HPCS integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs)."
  default     = false
}

variable "kms_key_crn" {
  type        = string
  description = "The root key CRN of the Key Protect or Hyper Protect Crypto Services instance to use for disk encryption. Applies only if `kms_encryption_enabled` is true."
  default     = null
  validation {
    condition = anytrue([
      var.kms_key_crn == null,
      can(regex(".*kms.*", var.kms_key_crn)),
      can(regex(".*hs-crypto.*", var.kms_key_crn)),
    ])
    error_message = "Value must be the root key CRN of the Key Protect or Hyper Protect Crypto Services instance."
  }
}

variable "backup_encryption_key_crn" {
  type        = string
  description = "The CRN of a KMS (Key Protect or Hyper Protect Crypto Service) key to use for encrypting the disk that holds deployment backups. Applies only if `kms_encryption_enabled` is true. Limitations exist for regions. For more information, see [Key Protect integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) or [Hyper Protect Crypto Services integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null
  validation {
    condition     = var.backup_encryption_key_crn == null ? true : length(regexall("^crn:v1:bluemix:public:kms:(us-south|us-east|eu-de):a/[[:xdigit:]]{32}:[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}:key:[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$|^crn:v1:bluemix:public:hs-crypto:[a-z-]+:a/[[:xdigit:]]{32}:[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}:key:[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$", var.backup_encryption_key_crn)) > 0
    error_message = "Valid values for backup_encryption_key_crn is null, a Hyper Protect Crypto Service key CRN or a Key Protect key CRN from us-south, us-east or eu-de"
  }
}

variable "use_default_backup_encryption_key" {
  type        = bool
  description = "Whether to use the IBM Cloud Databases generated keys."
  default     = false
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Whether to create an IAM authorization policy that permits all Databases for Elasticsearch instances in the resource group to read the encryption key from the Hyper Protect Crypto Services instance specified in the `existing_kms_instance_guid` variable. If set to `false`, specify a value for the KMS instance in the `existing_kms_instance_guid` variable. No policy is created if `kms_encryption_enabled` is false."
  default     = false
}

variable "existing_kms_instance_guid" {
  description = "The GUID of a Hyper Protect Crypto Services or Key Protect instance for the CRN specified in `kms_key_crn` and `backup_encryption_key_crn`. Applies only if `kms_encryption_enabled` is true, `skip_iam_authorization_policy` is false, and you specify values for `kms_key_crn` or `backup_encryption_key_crn`."
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
  description = "The list of context-based restriction rules to create."
  default     = []
  # Validation happens in the rule module
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
