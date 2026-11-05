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

variable "plan" {
  type        = string
  description = "The name of the service plan that you choose for your Elasticsearch instance. Use `enterprise-gen2` to restore a Gen2 backup."
  default     = "enterprise"
}

variable "prefix" {
  type        = string
  description = "Prefix to append to all resources created by this example"
  default     = "backup"
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example, if unset a new resource group will be created"
  default     = null
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the elasticsearch instance created by the module, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial for more details"
  default     = []
}

variable "elasticsearch_version" {
  type        = string
  description = "Version of the elasticsearch instance. If no value passed, the current ICD preferred version is used."
  default     = null
}

variable "disk_mb" {
  type        = number
  description = "Allocated disk per member. Gen2 requires 10240 or more, classic requires 5120 or more. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling)"
  default     = 12288
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

variable "existing_database_crn" {
  type        = string
  description = "The existing CRN of a backup resource to restore from."
  default     = null
}
