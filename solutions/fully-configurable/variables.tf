##############################################################################
# Input Variables
##############################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API key to deploy resources."
  sensitive   = true
}

variable "existing_resource_group_name" {
  type        = string
  description = "The name of an existing resource group to provision the resources. If not provided the default resource group will be used."
  default     = null
}

variable "prefix" {
  type        = string
  nullable    = true
  description = "The prefix to be added to all resources created by this solution. To skip using a prefix, set this value to null or an empty string. The prefix must begin with a lowercase letter and may contain only lowercase letters, digits, and hyphens '-'. It should not exceed 16 characters, must not end with a hyphen('-'), and can not contain consecutive hyphens ('--'). Example: prod-0205-cos. [Learn more](https://terraform-ibm-modules.github.io/documentation/#/prefix.md)."

  validation {
    # - null and empty string is allowed
    # - Must not contain consecutive hyphens (--): length(regexall("--", var.prefix)) == 0
    # - Starts with a lowercase letter: [a-z]
    # - Contains only lowercase letters (a–z), digits (0–9), and hyphens (-)
    # - Must not end with a hyphen (-): [a-z0-9]
    condition = (var.prefix == null || var.prefix == "" ? true :
      alltrue([
        can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.prefix)),
        length(regexall("--", var.prefix)) == 0
      ])
    )
    error_message = "Prefix must begin with a lowercase letter and may contain only lowercase letters, digits, and hyphens '-'. It must not end with a hyphen('-'), and cannot contain consecutive hyphens ('--')."
  }

  validation {
    # must not exceed 16 characters in length
    condition     = var.prefix == null || var.prefix == "" ? true : length(var.prefix) <= 16
    error_message = "Prefix must not exceed 16 characters."
  }
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

  validation {
    condition     = var.existing_elasticsearch_instance_crn != null && var.region != local.existing_elasticsearch_region ? false : true
    error_message = "The region detected in the 'existing_elasticsearch_instance_crn' value must match the value of the 'region' input variable when passing an existing instance."
  }
}

variable "existing_elasticsearch_instance_crn" {
  type        = string
  default     = null
  description = "The CRN of an existing Databases for Elasticsearch instance. If no value is specified, a new instance is created."
}

variable "elasticsearch_version" {
  description = "The version of the Databases for Elasticsearch instance. If no value is specified, the current preferred version of Databases for Elasticsearch is used."
  type        = string
  default     = null
}

variable "plan" {
  type        = string
  description = "The name of the service plan for your Databases for Elasticsearch instance. Possible values: `enterprise`, `platinum`."
  default     = "platinum"
  nullable    = false
}

variable "enable_elser_model" {
  type        = bool
  description = "Set it to true to install and start the Elastic's Natural Language Processing model. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-elser-embeddings-elasticsearch)"
  default     = false
  nullable    = false
}

variable "elser_model_type" {
  type        = string
  description = "Trained ELSER model to be used for Elastic's Natural Language Processing. Possible values: `.elser_model_1`, `.elser_model_2` and `.elser_model_2_linux-x86_64`. Applies only if also 'plan' is set to 'platinum' and 'enable_elser_model' is enabled. [Learn more](https://www.elastic.co/guide/en/machine-learning/current/ml-nlp-elser.html)"
  default     = ".elser_model_2_linux-x86_64"
  nullable    = false
  validation {
    condition     = contains([".elser_model_1", ".elser_model_2", ".elser_model_2_linux-x86_64"], var.elser_model_type)
    error_message = "The specified elser_model_type is not a valid selection!"
  }
}

##############################################################################
# ICD hosting model properties
##############################################################################

variable "service_endpoints" {
  type        = string
  description = "The type of endpoint of the database instance. Possible values: `public`, `private`, `public-and-private`."
  default     = "private"

  validation {
    condition     = can(regex("^(public|public-and-private|private)$", var.service_endpoints))
    error_message = "Valid values for service_endpoints are 'public', 'public-and-private', and 'private'"
  }
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
  default     = 3
}

variable "member_disk_mb" {
  type        = number
  description = "The disk that is allocated per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)."
  default     = 5120
}

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

variable "service_credential_names" {
  description = "Map of name, role for service credentials that you want to create for the database. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/blob/main/solutions/fully-configurable/DA-types.md#svc-credential-name)"
  type        = map(string)
  default     = {}
}

variable "admin_pass" {
  type        = string
  description = "The password for the database administrator. If no admin password is provided (i.e., it is null), one will be generated automatically. Additional users can be added using a user block."
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
  description = "A list of users that you want to create on the database. Multiple blocks are allowed. The user password must be in the range of 10-32 characters. Be warned that in most case using IAM service credentials (via the var.service_credential_names) is sufficient to control access to the Elasticsearch instance. This blocks creates native Elasticsearch database users. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/blob/main/solutions/fully-configurable/DA-types.md#users)"
}

variable "resource_tags" {
  type        = list(string)
  description = "The list of resource tags to be added to the Databases for Elasticsearch instance."
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Databases for Elasticsearch instance created by the solution. [Learn more](https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial)."
  default     = []
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
# Encryption
##############################################################

variable "kms_encryption_enabled" {
  type        = bool
  description = "Set to true to enable KMS encryption using customer-managed keys. When enabled, you must provide a value for at least one of the following: existing_kms_instance_crn, existing_kms_key_crn, or existing_backup_kms_key_crn. If set to false, IBM-owned encryption is used (i.e., encryption keys managed and held by IBM)."
  default     = false

  validation {
    condition = (!var.kms_encryption_enabled ||
      var.existing_elasticsearch_instance_crn != null ||
      var.existing_kms_instance_crn != null ||
      var.existing_kms_key_crn != null ||
      var.existing_backup_kms_key_crn != null
    )
    error_message = "When 'kms_encryption_enabled' is true, you must provide either 'existing_backup_kms_key_crn', 'existing_kms_instance_crn' (to create a new key) or 'existing_kms_key_crn' (to use an existing key)."
  }

  validation {
    condition     = (var.existing_kms_instance_crn == null && var.existing_kms_key_crn == null && var.existing_backup_kms_key_crn == null) || var.kms_encryption_enabled
    error_message = "When either 'existing_kms_instance_crn', 'existing_kms_key_crn' or 'existing_backup_kms_key_crn' is set then 'kms_encryption_enabled' must be set to true."
  }
}

variable "existing_kms_instance_crn" {
  type        = string
  description = "The CRN of a Key Protect or Hyper Protect Crypto Services instance. Required to create a new encryption key and key ring which will be used to encrypt both deployment data and backups. To use an existing key, pass values for `existing_kms_key_crn` and/or `existing_backup_kms_key_crn`. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null
}

variable "existing_kms_key_crn" {
  type        = string
  description = "The CRN of a Key Protect or Hyper Protect Crypto Services encryption key to encrypt your data. By default this key is used for both deployment data and backups, but this behaviour can be altered using the optional `existing_backup_kms_key_crn` input. If no value is passed a new key will be created in the instance specified in the `existing_kms_instance_crn` input. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null
}

variable "kms_endpoint_type" {
  type        = string
  description = "The type of endpoint to use for communicating with the Key Protect or Hyper Protect Crypto Services instance. Possible values: `public`, `private`. Applies only if `existing_kms_key_crn` is not specified."
  default     = "private"

  validation {
    condition     = can(regex("^(public|private)$", var.kms_endpoint_type))
    error_message = "The kms_endpoint_type value must be 'public' or 'private'."
  }
}

variable "skip_elasticsearch_kms_auth_policy" {
  type        = bool
  description = "Set to true to skip the creation of IAM authorization policies that permits all Databases for Elasticsearch instances in the given resource group 'Reader' access to the Key Protect or Hyper Protect Crypto Services key. This policy is required in order to enable KMS encryption, so only skip creation if there is one already present in your account. No policy is created if `kms_encryption_enabled` is false."
  default     = false
}

variable "ibmcloud_kms_api_key" {
  type        = string
  description = "The IBM Cloud API key that can create a root key and key ring in the key management service (KMS) instance. If not specified, the 'ibmcloud_api_key' variable is used. Specify this key if the instance in `existing_kms_instance_crn` is in an account that's different from the Elastic Search instance. Leave this input empty if the same account owns both instances."
  sensitive   = true
  default     = null
}

variable "key_ring_name" {
  type        = string
  default     = "elasticsearch-key-ring"
  description = "The name for the key ring created for the ElasticSearch key. Applies only if not specifying an existing key. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "key_name" {
  type        = string
  default     = "elasticsearch-key"
  description = "The name for the key created for the ElasticSearch key. Applies only if not specifying an existing key. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "existing_backup_kms_key_crn" {
  type        = string
  description = "The CRN of a Key Protect or Hyper Protect Crypto Services encryption key that you want to use for encrypting the disk that holds deployment backups. Applies only if `kms_encryption_enabled` is true. If no value is passed, the value of `existing_kms_key_crn` is used. If no value is passed for `existing_kms_key_crn`, a new key will be created in the instance specified in the `existing_kms_instance_crn` input. Alternatively set `kms_encryption_enabled` to false to use the IBM Cloud Databases default encryption. Bare in mind that backups encryption is only available in certain regions. See [Bring your own key for backups](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) and [Using the HPCS Key for Backup encryption](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups)."
  default     = null
}

variable "use_default_backup_encryption_key" {
  type        = bool
  description = "When `kms_encryption_enabled` is set to true, backups will be encrypted with either the key specified in `existing_kms_key_crn`, in `existing_backup_kms_key_crn`, or with a new key that will be created in the instance specified in the `existing_kms_instance_crn` input. If you do not want to use your own key for backups encryption, you can set this to `true` to use the IBM Cloud Databases default encryption for backups. Alternatively set `kms_encryption_enabled` to false to use the default encryption for both backups and deployment data."
  default     = false
}

variable "backup_crn" {
  type        = string
  description = "The CRN of a backup resource to restore from. The backup is created by a database deployment with the same service ID. The backup is loaded after provisioning and the new deployment starts up that uses that data. A backup CRN is in the format crn:v1:<…>:backup:. If omitted, the database is provisioned empty."
  default     = null

  validation {
    condition = anytrue([
      var.backup_crn == null,
      can(regex("^crn:.*:backup:", var.backup_crn))
    ])
    error_message = "backup_crn must be null OR starts with 'crn:' and contains ':backup:'"
  }
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
  description = "Optional rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/blob/main/solutions/fully-configurable/DA-types.md#autoscaling)"
  default = {
    disk = {
      capacity_enabled             = false
      free_space_less_than_percent = 10
      io_above_percent             = 90
      io_enabled                   = false
      io_over_period               = "15m"
      rate_increase_percent        = 10
      rate_limit_mb_per_member     = 3670016
      rate_period_seconds          = 900
      rate_units                   = "mb"
    }
    memory = {
      io_above_percent         = 90
      io_enabled               = false
      io_over_period           = "15m"
      rate_increase_percent    = 10
      rate_limit_mb_per_member = 114688
      rate_period_seconds      = 900
      rate_units               = "mb"
    }
  }
}

#############################################################################
# Secrets Manager Service Credentials
#############################################################################

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
      secret_name                                 = string
      service_credentials_source_service_role_crn = string
      secret_labels                               = optional(list(string))
      secret_auto_rotation                        = optional(bool)
      secret_auto_rotation_unit                   = optional(string)
      secret_auto_rotation_interval               = optional(number)
      service_credentials_ttl                     = optional(string)
      service_credential_secret_description       = optional(string)

    }))
  }))
  default     = []
  description = "Service credential secrets configuration for Databases for Elasticsearch. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/blob/main/solutions/fully-configurable/DA-types.md#service-credential-secrets)."

  validation {
    # Service roles CRNs can be found at https://cloud.ibm.com/iam/roles, select the IBM Cloud Database and select the role
    condition = alltrue([
      for group in var.service_credential_secrets : alltrue([
        # crn:v?:bluemix; two non-empty segments; three possibly empty segments; :serviceRole or role: non-empty segment
        for credential in group.service_credentials : can(regex("^crn:v[0-9]:bluemix(:..*){2}(:.*){3}:(serviceRole|role):..*$", credential.service_credentials_source_service_role_crn))
      ])
    ])
    error_message = "service_credentials_source_service_role_crn must be a serviceRole CRN. See https://cloud.ibm.com/iam/roles"
  }

  validation {
    condition = (
      length(var.service_credential_secrets) == 0 ||
      var.existing_secrets_manager_instance_crn != null
    )
    error_message = "`existing_secrets_manager_instance_crn` is required when adding service credentials to a secrets manager secret."
  }
}

variable "skip_elasticsearch_to_secrets_manager_auth_policy" {
  type        = bool
  default     = false
  description = "Whether an IAM authorization policy is created for Secrets Manager instance to create a service credential secrets for Databases for Elasticsearch. If set to false, the Secrets Manager instance passed by the user is granted the Key Manager access to the Elasticsearch instance created by the Deployable Architecture. Set to `true` to use an existing policy. The value of this is ignored if any value for 'existing_secrets_manager_instance_crn' is not passed."
}

variable "admin_pass_secrets_manager_secret_group" {
  type        = string
  description = "The name of a new or existing secrets manager secret group for admin password. To use existing secret group, `use_existing_admin_pass_secrets_manager_secret_group` must be set to `true`. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "elasticsearch-secrets"

  validation {
    condition = (
      var.existing_secrets_manager_instance_crn == null ||
      var.admin_pass_secrets_manager_secret_group != null
    )
    error_message = "`admin_pass_secrets_manager_secret_group` is required when `existing_secrets_manager_instance_crn` is set."
  }
}

variable "use_existing_admin_pass_secrets_manager_secret_group" {
  type        = bool
  description = "Whether to use an existing secrets manager secret group for admin password."
  default     = false
}

variable "admin_pass_secrets_manager_secret_name" {
  type        = string
  description = "The name of a new elasticsearch administrator secret. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "elasticsearch-admin-password"

  validation {
    condition = (
      var.existing_secrets_manager_instance_crn == null ||
      var.admin_pass_secrets_manager_secret_name != null
    )
    error_message = "`admin_pass_secrets_manager_secret_name` is required when `existing_secrets_manager_instance_crn` is set."
  }
}

variable "use_existing_registry_secret" {
  description = "Set to true to use an existing image registry secret instead of creating a new one."
  type        = bool
  default     = false
}

##############################################################
# Kibana Configuration
##############################################################

variable "kibana_code_engine_new_project_name" {
  type        = string
  description = "The Code Engine project name. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "ce-kibana-project"
}

variable "kibana_code_engine_new_app_name" {
  type        = string
  description = "The Code Engine application name. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "ce-kibana-app"
}

variable "existing_code_engine_project_id" {
  type        = string
  description = "Existing code engine project ID to deploy Kibana. If no value is passed, a new code engine project will be created."
  default     = null
}

variable "enable_kibana_dashboard" {
  type        = bool
  description = "Set to true to deploy Kibana in Code Engine. NOTE: By default, the Kibana image will be pulled from the official Elastic registry (docker.elastic.co) and is not certified by IBM, however this can be overridden using the `kibana_registry_namespace_image` and `kibana_image_digest` inputs."
  default     = false
}

variable "use_private_registry" {
  description = "Set to true if the Kibana image is being pulled from a private registry."
  type        = bool
  default     = false
}

variable "kibana_registry_namespace_image" {
  type        = string
  description = "The Kibana image reference in the format of `[registry-url]/[namespace]/[image]`. This value is used only when `enable_kibana_dashboard` is set to true."
  default     = "docker.elastic.co/kibana/kibana"
}

variable "kibana_registry_server" {
  type        = string
  description = "The server URL of the container registry used to pull the Kibana image."
  default     = "https://index.docker.io/v1/"
  validation {
    condition = (
      !(var.use_private_registry && !var.use_existing_registry_secret)
      || (var.kibana_registry_server != null && var.kibana_registry_server != "")
    )
    error_message = "The `kibana_registry_server` must not be null or empty when `use_private_registry` is true and `use_existing_registry_secret` is false."
  }
}

variable "kibana_image_digest" {
  type        = string
  description = "When `enable_kibana_dashboard` is set to true, Kibana is deployed using an image tag compatible with the Elasticsearch version. Alternatively, an image digest in the format `sha256:xxxxx...` can also be specified but it must correspond to a version compatible with the Elasticsearch instance."
  default     = null
  validation {
    condition     = var.kibana_image_digest == null || can(regex("^sha256:", var.kibana_image_digest))
    error_message = "If provided, the value of kibana_image_digest must start with 'sha256:'."
  }
}

variable "kibana_image_port" {
  description = "Specify the port number used to connect to the Kibana service exposed by the container image. Default port is 5601 and it is only applicable if `enable_kibana_dashboard` is true"
  type        = number
  default     = 5601
}

variable "kibana_image_secret" {
  description = "The name of the image registry access secret."
  type        = string
  default     = null
}

variable "kibana_visibility" {
  description = "Specify the visibility of Kibana application in order to define which endpoint is available for receiving the requests. Valid values are 'local_public', 'local_private' and 'local' and it is only applicable if `enable_kibana_dashboard` is true. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/blob/main/solutions/fully-configurable/DA-types.md#options-for-kibana_visibility)."
  type        = string
  default     = "local_private"
  validation {
    condition     = can(regex("local_public|local_private|local", var.kibana_visibility))
    error_message = "Valid values are 'local_public', 'local_private', or 'local'."
  }
}

variable "kibana_registry_username" {
  description = "Username for the for the container registry."
  type        = string
  default     = null
  validation {
    condition = (
      !(var.use_private_registry && !var.use_existing_registry_secret)
      || (var.kibana_registry_username != null && var.kibana_registry_username != "")
    )
    error_message = "The `kibana_registry_username` must not be null or empty when `use_private_registry` is true and `use_existing_registry_secret` is false."
  }
}

variable "kibana_registry_personal_access_token" {
  description = "Pesonal access token for the container registry."
  type        = string
  default     = null
  sensitive   = true
  validation {
    condition = (
      !(var.use_private_registry && !var.use_existing_registry_secret)
      || (var.kibana_registry_personal_access_token != null && var.kibana_registry_personal_access_token != "")
    )
    error_message = "The `kibana_registry_personal_access_token` must not be null or empty when `use_private_registry` is true and `use_existing_registry_secret` is false."
  }
}

variable "kibana_system_secret_name" {
  type        = string
  description = "The Secrets Manager secret name of a new kibana system secret. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "kibana-system-password"

  validation {
    condition = (
      # TODO - do some sensible validation! Add enable_elser_model cross variable validation
      var.existing_secrets_manager_instance_crn == null ||
      var.kibana_system_secret_name != null
    )
    error_message = "`kibana_system_secret_name` is required when `existing_secrets_manager_instance_crn` is set."
  }
}

variable "kibana_app_secret_name" {
  type        = string
  description = "The Secrets Manager secret name of a new kibana application secret. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
  default     = "kibana-app-password"

  validation {
    condition = (
      # TODO - do some sensible validation! Add enable_elser_model cross variable validation
      var.existing_secrets_manager_instance_crn == null ||
      var.kibana_app_secret_name != null
    )
    error_message = "`kibana_app_secret_name` is required when `existing_secrets_manager_instance_crn` is set."
  }
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
  description = "(Optional, list) List of context-based restrictions rules to create. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/fully-configurable/DA-cbr_rules.md)"
  default     = []
}

variable "cbr_code_engine_kibana_project_rules" {
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
  description = "(Optional, list) List of context-based restrictions rules to create for the Kibana dashboard and it is only applicable if `enable_kibana_dashboard` is true. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/solutions/standard/DA-cbr_rules.md)"
  default     = []
}
