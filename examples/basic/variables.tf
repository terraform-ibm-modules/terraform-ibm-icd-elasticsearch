variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API Key"
  sensitive   = true
}

variable "region" {
  type        = string
  description = "Region to provision all resources created by this example"
  default     = "us-south"
}

variable "prefix" {
  type        = string
  description = "Prefix to append to all resources created by this example"
  default     = "elastic"
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example, if unset a new resource group will be created"
  default     = null
}

variable "elasticsearch_version" {
  type        = string
  description = "Version of elasticsearch to deploy"
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

variable "member_host_flavor" {
  type        = string
  description = "Allocated host flavor per member. For more information, see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor"
  default     = null
}

variable "member_memory_mb" {
  type        = number
  description = "Allocated memory per-member."
  default     = 4096
}
