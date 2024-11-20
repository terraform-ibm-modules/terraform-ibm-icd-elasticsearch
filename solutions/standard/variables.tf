##############################################################################
# DA extra
##############################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API key to deploy resources."
  sensitive   = true
}

variable "ibmcloud_kms_api_key" {
  type        = string
  description = "The IBM Cloud API key that can create a root key and key ring in the key management service (KMS) instance. If not specified, the 'ibmcloud_api_key' variable is used. Specify this key if the instance in `existing_kms_instance_crn` is in an account that's different from the Elastic Search instance. Leave this input empty if the same account owns both instances."
  sensitive   = true
  default     = null
}

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid visibility option. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}

variable "prefix" {
  type        = string
  description = "Prefix to add to all resources created by this solution."
  default     = null
}

##############################################################################
# Input Variables
##############################################################################

variable "resource_group_name" {
  type        = string
  description = "The name of a new or an existing resource group to provision the Databases for Elasicsearch in. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "use_existing_resource_group" {
  type        = bool
  description = "Whether to use an existing resource group."
  default     = false
}

variable "name" {
  type        = string
  description = "The name of the Databases for Elasticsearch instance. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "elasticsearch"
}

variable "elasticsearch_version" {
  type        = string
  description = "The version of the Databases for Elasticsearch instance. If no value is specified, the current preferred version of Databases for Elasticsearch is used."
  default     = null
}

variable "region" {
  type        = string
  description = "The region where you want to deploy your instance."
  default     = "us-south"
}

variable "plan" {
  type        = string
  description = "The name of the service plan for your Databases for Elasticsearch instance. Possible values: `enterprise`, `platinum`."
  default     = "platinum"
}

variable "existing_db_instance_crn" {
  type        = string
  default     = null
  description = "The CRN of an existing Databases for Elasticsearch instance. If no value is specified, a new instance is created."
}

variable "enable_elser_model" {
  type        = bool
  description = "Set it to true to install and start the Elastic's Natural Language Processing model. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-elser-embeddings-elasticsearch)"
  default     = false
}

variable "elser_model_type" {
  type        = string
  description = "Trained ELSER model to be used for Elastic's Natural Language Processing. Possible values: `.elser_model_1`, `.elser_model_2` and `.elser_model_2_linux-x86_64`. [Learn more](https://www.elastic.co/guide/en/machine-learning/current/ml-nlp-elser.html)"
  default     = ".elser_model_2_linux-x86_64"
  validation {
    condition     = contains([".elser_model_1", ".elser_model_2", ".elser_model_2_linux-x86_64"], var.elser_model_type)
    error_message = "The specified elser_model_type is not a valid selection!"
  }
}

##############################################################################
# ICD hosting model properties
##############################################################################


variable "members" {
  type        = number
  description = "The number of members that are allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 3
}

variable "member_cpu_count" {
  type        = number
  description = "The dedicated CPU per member that is allocated. For shared CPU, set to 0. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 3
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
  default     = "b3c.4x16.encrypted"
  # Prevent null or "", require multitenant or a machine type
  validation {
    condition     = (length(var.member_host_flavor) > 0)
    error_message = "Member host flavor must be specified. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  }
}

variable "member_memory_mb" {
  type        = number
  description = "The memory per member that is allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 4096
}

variable "admin_pass" {
  type        = string
  description = "The password for the database administrator. If the admin password is null, then it is created automatically. You must set 'existing_secrets_manager_instance_crn' to store admin pass into secrets manager. You can specify more users in a user block."
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
  description = "The list of users that have access to the database. Multiple blocks are allowed. The user password must be 10-32 characters. In most cases, you can use IAM service credentials (by specifying `service_credential_names`) to control access to the database instance. This block creates native database users. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-types.md)."
  default     = []
  sensitive   = true
}

variable "service_credential_names" {
  type        = map(string)
  description = "The map of name and role for service credentials that you want to create for the database. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-types.md)."
  default     = {}
}

variable "tags" {
  type        = list(any)
  description = "The list of tags to be added to the Databases for Elasticsearch instance."
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Databases for Elasticsearch instance created by the solution. [Learn more](https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial)."
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
  description = "The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-types.md)."
  default     = null
}

##############################################################
# Encryption
##############################################################

variable "existing_kms_key_crn" {
  type        = string
  description = "The CRN of a Hyper Protect Crypto Services or Key Protect root key to use for disk encryption. If not specified, a root key is created in the KMS instance."
  default     = null
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Whether to create an IAM authorization policy that permits all Databases for Elasticsearch instances in the resource group to read the encryption key from the Hyper Protect Crypto Services instance specified in the `existing_kms_instance_crn` variable."
  default     = false
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

variable "existing_kms_instance_crn" {
  type        = string
  description = "The CRN of a Hyper Protect Crypto Services or Key Protect instance in the same account as the Databases for Elasticsearch instance. This value is used to create an authorization policy if `skip_iam_authorization_policy` is false. If not specified, a root key is created."
  default     = null
}

##############################################################
# DA KMS extras
##############################################################

variable "elasticsearch_key_ring_name" {
  type        = string
  default     = "elasticsearch-key-ring"
  description = "The name for the key ring created for the ElasticSearch key. Applies only if not specifying an existing key or using IBM owned keys. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "use_ibm_owned_encryption_key" {
  type        = bool
  description = "Set to true to use the default IBM Cloud® Databases randomly generated keys for disk and backups encryption."
  default     = false
}

variable "elasticsearch_key_name" {
  type        = string
  default     = "elasticsearch-key"
  description = "The name for the key created for the ElasticSearch key. Applies only if not specifying an existing key or using IBM owned keys. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

##############################################################################
## Secrets Manager Service Credentials
##############################################################################

variable "existing_secrets_manager_instance_crn" {
  type        = string
  default     = null
  description = "The CRN of existing secrets manager to use to create service credential secrets for Databases for Elasticsearch instance."
}

variable "existing_secrets_manager_endpoint_type" {
  type        = string
  description = "The endpoint type to use if `existing_secrets_manager_instance_crn` is specified. Possible values: public, private."
  default     = "private"
  validation {
    condition     = contains(["public", "private"], var.existing_secrets_manager_endpoint_type)
    error_message = "Only \"public\" and \"private\" are allowed values for 'existing_secrets_endpoint_type'."
  }
}

variable "service_credential_secrets" {
  type = list(object({
    secret_group_name        = string
    secret_group_description = optional(string)
    existing_secret_group    = optional(bool)
    service_credentials = list(object({
      secret_name                             = string
      service_credentials_source_service_role = string
      secret_labels                           = optional(list(string))
      secret_auto_rotation                    = optional(bool)
      secret_auto_rotation_unit               = optional(string)
      secret_auto_rotation_interval           = optional(number)
      service_credentials_ttl                 = optional(string)
      service_credential_secret_description   = optional(string)

    }))
  }))
  default     = []
  description = "Service credential secrets configuration for Databases for Elasticsearch. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-elasticsearch/tree/main/solutions/instance/DA-types.md#service-credential-secrets)."

  validation {
    condition = alltrue([
      for group in var.service_credential_secrets : alltrue([
        for credential in group.service_credentials : contains(
          ["Writer", "Reader", "Manager", "None"], credential.service_credentials_source_service_role
        )
      ])
    ])
    error_message = "service_credentials_source_service_role role must be one of 'Writer', 'Reader', 'Manager', and 'None'."

  }
}

variable "skip_es_sm_auth_policy" {
  type        = bool
  default     = false
  description = "Whether an IAM authorization policy is created for Secrets Manager instance to create a service credential secrets for Databases for Elasticsearch. Set to `true` to use an existing policy."
}

variable "admin_pass_sm_secret_group" {
  type        = string
  description = "The name of a new or existing secrets manager secret group for admin password. To use existing secret group, `use_existing_admin_pass_sm_secret_group` must be set to `true`. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "elasticsearch-secrets"
}

variable "use_existing_admin_pass_sm_secret_group" {
  type        = bool
  description = "Whether to use an existing secrets manager secret group for admin password."
  default     = false
}

variable "admin_pass_sm_secret_name" {
  type        = string
  description = "The name of a new elasticsearch administrator secret. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "elasticsearch-admin-password"
}

##############################################################
# Kibana Configuration
##############################################################

variable "existing_code_engine_project_id" {
  description = "Existing code engine project ID to deploy Kibana. If no value is passed, a new code engine project will be created."
  type        = string
  default     = null
}

variable "enable_kibana_dashboard" {
  type        = bool
  description = "Set to true to deploy Kibana in Code Engine. NOTE: By default, the Kibana image will be pulled from the official Elastic registry (docker.elastic.co) and is not certified by IBM, however this can be overridden using the `kibana_image_reference` input."
  default     = false
}

variable "elasticsearch_full_version" {
  description = "(Optional) Full version of the Elasticsearch instance in the format `x.x.x` to deploy Kibana dashboard. Value is only used if `enable_kibana_dashboard` is true and if no value is passed for `kibana_image_reference`. If no value is passed, data lookup will fetch the full version using the Elasticsearch API, see https://github.com/elastic/kibana?tab=readme-ov-file#version-compatibility-with-elasticsearch"
  type        = string
  default     = null
}

variable "kibana_image_reference" {
  description = "The docker image reference to use for Kibana if `enable_kibana_dashboard` is set to true. If no value is set, it will pull the image from the official Elastic registry (https://www.docker.elastic.co). Ensure to use a version that is compatible with the Elasticsearch version being used."
  type        = string
  default     = null
}
