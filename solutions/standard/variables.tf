variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API key to deploy resources."
  sensitive   = true
}
variable "use_existing_resource_group" {
  type        = bool
  description = "Whether to use an existing resource group."
  default     = false
}

variable "resource_group_name" {
  type        = string
  description = "The name of a new or an existing resource group to provision the Databases for Elasicsearch in. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "prefix" {
  type        = string
  description = "Prefix to add to all resources created by this solution."
  default     = null
}

variable "name" {
  type        = string
  description = "The name of the Databases for Elasticsearch instance. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "elasticsearch"
}

variable "region" {
  description = "The region where you want to deploy your instance."
  type        = string
  default     = "us-south"
}

variable "plan" {
  type        = string
  description = "The name of the service plan for your Databases for Elasticsearch instance. Possible values: `enterprise`, `platinum`."
  default     = "enterprise"
}

variable "elasticsearch_version" {
  description = "The version of the Databases for Elasticsearch instance. If no value is specified, the current preferred version of Databases for Elasticsearch is used."
  type        = string
  default     = null
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Databases for Elasticsearch instance created by the solution. [Learn more](https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial)."
  default     = []
}

variable "members" {
  type        = number
  description = "The number of members that are allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 3
}

variable "member_memory_mb" {
  type        = number
  description = "The memory per member that is allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 4096
}

variable "member_cpu_count" {
  type        = number
  description = "The dedicated CPU per member that is allocated. For shared CPU, set to 0. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 0
}

variable "member_disk_mb" {
  type        = number
  description = "The disk that is allocated per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 5120
}

# Use new hosting model for all DA
variable "member_host_flavor" {
  type        = string
  description = "The host flavor per member. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  default     = "multitenant"
  # Prevent null or "", require multitenant or a machine type
  validation {
    condition     = (length(var.member_host_flavor) > 0)
    error_message = "Member host flavor must be specified. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  }
}

variable "service_credential_names" {
  description = "The map of name and role for service credentials that you want to create for the database. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-types.md)."
  type        = map(string)
  default     = {}
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
    type     = string # "type" is required to generate the connection string for the outputs.
    role     = optional(string)
  }))
  default     = []
  sensitive   = true
  description = "The list of users that have access to the database. Multiple blocks are allowed. The user password must be 10-32 characters. In most cases, you can use IAM service credentials (by specifying `service_credential_names`) to control access to the database instance. This block creates native database users. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-types.md)."
}

variable "tags" {
  type        = list(any)
  description = "The list of tags to be added to the Databases for Elasticsearch instance."
  default     = []
}

variable "ibmcloud_kms_api_key" {
  type        = string
  description = "The IBM Cloud API key that can create a root key and key ring in the key management service (KMS) instance. If not specified, the 'ibmcloud_api_key' variable is used. Specify this key if the instance in `existing_kms_instance_crn` is in an account that's different from the Elastic Search instance. Leave this input empty if the same account owns both instances."
  sensitive   = true
  default     = null
}

variable "kms_endpoint_type" {
  type        = string
  description = "The type of endpoint to use to communicate with the KMS instance. Possible values: `public`, `private`."
  default     = "private"
  validation {
    condition     = can(regex("public|private", var.kms_endpoint_type))
    error_message = "The kms_endpoint_type value must be 'public' or 'private'."
  }
}

variable "existing_kms_key_crn" {
  type        = string
  description = "The CRN of a Hyper Protect Crypto Services or Key Protect root key to use for disk encryption. If not specified, a root key is created in the KMS instance."
  default     = null
}

variable "existing_kms_instance_crn" {
  description = "The CRN of the KMS instance (Hyper Protect Crypto Services or Key Protect). Required only if `existing_kms_key_crn` is not specified. If the KMS instance is in different account you must also provide a value for `ibmcloud_kms_api_key`."
  type        = string
  default     = null
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Elastic Search instances in the resource group to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the `existing_kms_instance_crn` variable. If a value is specified for `ibmcloud_kms_api_key`, the policy is created in the KMS account."
  default     = false
}

variable "elasticsearch_key_ring_name" {
  type        = string
  default     = "elasticsearch-key-ring"
  description = "The name for the key ring created for the Databases for Elasticsearch key. Applies only if not specifying an existing key. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "elasticsearch_key_name" {
  type        = string
  default     = "elasticsearch-key"
  description = "The name for the key created for the Databases for Elasticsearch key. Applies only if not specifying an existing key. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
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
  description = "The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-types.md)."
  default     = null
}
