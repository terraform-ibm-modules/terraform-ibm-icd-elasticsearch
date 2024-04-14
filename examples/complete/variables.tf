variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API Key"
  sensitive   = true
}

variable "region" {
  type        = string
  description = "Region to provision all resources created by this example."
  default     = "us-south"
}

variable "prefix" {
  type        = string
  description = "Prefix to append to all resources created by this example"
  default     = "complete-es-test"
}

variable "elasticsearch_version" {
  type        = string
  description = "Version of elasticsearch to deploy"
  default     = null
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example, if unset a new resource group will be created"
  default     = null
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the Elasticsearch instance created by the module, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial for more details"
  default     = []
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

variable "plan" {
  type        = string
  description = "The name of the service plan that you choose for your Elasticsearch instance"
  default     = "enterprise"
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "Existing Secrets Manager GUID. If not provided an new instance will be provisioned"
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Required if value is passed into var.existing_sm_instance_guid"
  default     = null
}

variable "service_credential_names" {
  description = "Map of name, role for service credentials that you want to create for the database"
  type        = map(string)
  default = {
    "es_admin" : "Administrator",
    "es_operator" : "Operator",
    "es_viewer" : "Viewer",
    "es_editor" : "Editor",
  }
}

variable "admin_pass" {
  type        = string
  default     = null
  sensitive   = true
  description = "The password for the database administrator. If the admin password is null then the admin user ID cannot be accessed. More users can be specified in a user block."
}

variable "users" {
  type = list(object({
    name     = string
    password = string
    type     = string
    role     = optional(string)
  }))
  default     = []
  sensitive   = true
  description = "A list of users that you want to create on the database. Multiple blocks are allowed. The user password must be in the range of 10-32 characters."
}

variable "create_index" {
  description = "Set it to true if index is to be created"
  type = bool
  default = true
}

variable "index_name" {
  description = "The name of the index of the elasticsearch "
  type = string
  default = "terraform-test"
}

variable "number_of_shards" {
  description = "The total number of shards the indexed data is to be divided into"
  type = number
  default = 1
}

variable "number_of_replicas" {
  description = "The total number of replicas of the primary shard in an index"
  type = number
  default = 1
}

variable "force_destroy" {
  description = "Whether an existing index with the same name should be destroyed before creating a new one."
  type = bool
  default = true
}

variable "add_cluster_configuration" {
  description = "Set it to true if cluster configuration is to be added"
  type = bool
  default = true
}

variable "cluster_max_shards_per_node" {
  description = "The maximum number of shards that can be assigned to a single node in a cluster."
  type = number
  default = 10
}

variable "action_auto_create_index" {
  description = "Each string in the list could correspond to an index pattern that triggers automatic index creation"
  type = list(string)
  default = ["my-index-000001,index10,-index1*,+ind*"]
}

variable "auto_scaling" {
  type = object({
    disk = object({
      capacity_enabled             = optional(bool)
      free_space_less_than_percent = optional(number)
      io_above_percent             = optional(number)
      io_enabled                   = optional(bool)
      io_over_period               = optional(string)
      rate_increase_percent        = optional(number)
      rate_limit_mb_per_member     = optional(number)
      rate_period_seconds          = optional(number)
      rate_units                   = optional(string)
    })
    memory = object({
      io_above_percent         = optional(number)
      io_enabled               = optional(bool)
      io_over_period           = optional(string)
      rate_increase_percent    = optional(number)
      rate_limit_mb_per_member = optional(number)
      rate_period_seconds      = optional(number)
      rate_units               = optional(string)
    })
  })
  description = "(Optional) Configure rules to allow your database to automatically increase its resources. Single block of autoscaling is allowed at once."
  default = {
    disk = {
      capacity_enabled : true,
      io_enabled : true
    }
    memory = {
      io_enabled : true,
    }
  }
}
