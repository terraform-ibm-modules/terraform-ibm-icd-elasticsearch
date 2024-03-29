variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM cloud api key"
  sensitive   = true
}
variable "existing_resource_group" {
  type        = bool
  description = "Whether to use an existing resource group."
  default     = false
}

variable "resource_group_name" {
  type        = string
  description = "The name of a new or an existing resource group in which to provision the Databases for Elasicsearch in."
}

variable "name" {
  description = "The name of the Elasticsearch instance"
  type        = string
}

variable "region" {
  description = "The region where you want to deploy your instance."
  type        = string
  default     = "us-south"
}

variable "plan" {
  type        = string
  description = "The name of the service plan that you choose for your Elasticsearch instance. The supported plans are - enterprise and platinum"
  default     = "enterprise"
}

variable "elasticsearch_version" {
  description = "The version of the Elasticsearch instance. If no value is passed, the current preferred version of IBM Cloud Databases is used."
  type        = string
  default     = "8.10"
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Elasticsearch instance created by the module, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial for more details"
  default     = []
}

variable "members" {
  type        = number
  description = "The number of members that are allocated. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 3
}

variable "member_memory_mb" {
  type        = number
  description = "The memory per member that is allocated. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 1024
}

variable "member_cpu_count" {
  type        = number
  description = "The dedicated CPU per member that is allocated. For shared CPU, set to 0. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 0
}

variable "member_disk_mb" {
  type        = number
  description = "The disk that is allocated per-member. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling"
  default     = 5120
}

variable "service_credential_names" {
  description = "The map of name, role for service credentials that you want to create for the database"
  type        = map(string)
  default     = {}
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
  description = "The list of users that have access to the database. Multiple blocks are allowed. The user password must be in the range of 10-32 characters. Be warned that in most case using IAM service credentials (via the var.service_credential_names) is sufficient to control access to the Elasticsearch instance. This blocks creates native Elasticsearch database users, more info on that can be found here https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-user-management&interface=ui"
}

variable "tags" {
  type        = list(any)
  description = "The list of tags to be added to the Elasticsearch instance."
  default     = []
}

variable "kms_region" {
  type        = string
  default     = "us-south"
  description = "The region in which KMS instance exists."
}

variable "kms_endpoint_type" {
  type        = string
  description = "The type of endpoint to be used for commincating with the KMS instance. Allowed values are: 'public' or 'private' (default)"
  default     = "private"
  validation {
    condition     = can(regex("public|private", var.kms_endpoint_type))
    error_message = "The kms_endpoint_type value must be 'public' or 'private'."
  }
}

variable "existing_kms_key_crn" {
  type        = string
  description = "The existing root key CRN of the Hyper Protect Crypto Service (HPCS) to use for disk encryption."
  default     = null
}

variable "existing_kms_instance_guid" {
  description = "The GUID of the Hyper Protect Crypto Services instance. The value is used only to create an authorization policy."
  type        = string
  default     = null
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Elasticsearch database instances in the resource group to read the encryption key from the Hyper Protect Crypto Services instance. The HPCS instance is passed in through the var.existing_kms_instance_guid variable."
  default     = false
}

variable "elasticsearch_key_ring_name" {
  type        = string
  default     = "elasticsearch-key-ring"
  description = "The name to give the Key Ring which will be created for the Elasticsearch Key. Not used if supplying an existing Key."
}

variable "elasticsearch_key_name" {
  type        = string
  default     = "elasticsearch-key"
  description = "The name to give the Key which will be created for the Elasticsearch. Not used if supplying an existing Key."
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
  description = "The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. See https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations in the IBM Cloud Docs."
  default     = null
}
