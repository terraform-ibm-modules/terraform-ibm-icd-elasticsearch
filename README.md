## ICD Elasticsearch Module

[![Graduated (Supported)](https://img.shields.io/badge/Status-Graduated%20(Supported)-brightgreen)](https://terraform-ibm-modules.github.io/documentation/#/badge-status)
[![latest release](https://img.shields.io/github/v/release/terraform-ibm-modules/terraform-ibm-icd-elasticsearch?logo=GitHub&sort=semver)](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/releases/latest)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)


<!-- BEGIN OVERVIEW HOOK -->
## Overview
* [terraform-ibm-icd-elasticsearch](#terraform-ibm-icd-elasticsearch)
* [Examples](./examples)
    * [Basic example](./examples/basic)
    * [Complete example with autoscaling, BYOK encryption, service credentials creation, index creation and updates to cluster-wide settings](./examples/complete)
* [Contributing](#contributing)

## terraform-ibm-icd-elasticsearch
<!-- END OVERVIEW HOOK -->


This module implements an instance of the IBM Cloud Databases for Elasticsearch service.

### Usage

<!--
Add an example of the use of the module in the following code block.

Use real values instead of "var.<var_name>" or other placeholder values
unless real values don't help users know what to change.
-->

```hcl
provider "ibm" {
  ibmcloud_api_key = "XXXXXXXXXXXXXX"
  region           = "us-south"
}

module "icd_elasticsearch" {
  source            = "terraform-ibm-modules/icd-elasticsearch/ibm"
  version           = "X.X.X"  # Replace "X.X.X" with a release version to lock into a specific release
  resource_group_id = "xxXXxxXXxXxXXXXxxXxxxXXXXxXXXXX"
  region            = "us-south"
}
```

### Required IAM access policies

You need the following permissions to run this module.

- Account Management
    - **Databases for Elasticsearch** service
        - `Editor` role access

<!-- Below content is automatically populated via pre-commit hook -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.56.1, < 2.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cbr_rule"></a> [cbr\_rule](#module\_cbr\_rule) | terraform-ibm-modules/cbr/ibm//modules/cbr-rule-module | 1.9.0 |

### Resources

| Name | Type |
|------|------|
| [ibm_database.elasticsearch](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/database) | resource |
| [ibm_iam_authorization_policy.policy](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_resource_key.service_credentials](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/resource_key) | resource |
| [time_sleep.wait_for_authorization_policy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [ibm_database_connection.database_connection](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/data-sources/database_connection) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_pass"></a> [admin\_pass](#input\_admin\_pass) | The password for the database administrator. If the admin password is null then the admin user ID cannot be accessed. More users can be specified in a user block. The admin password must be in the range of 10-32 characters. | `string` | `null` | no |
| <a name="input_auto_scaling"></a> [auto\_scaling](#input\_auto\_scaling) | Optional rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. See https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling in the IBM Cloud Docs. | <pre>object({<br>    disk = object({<br>      capacity_enabled             = optional(bool, false)<br>      free_space_less_than_percent = optional(number, 10)<br>      io_above_percent             = optional(number, 90)<br>      io_enabled                   = optional(bool, false)<br>      io_over_period               = optional(string, "15m")<br>      rate_increase_percent        = optional(number, 10)<br>      rate_limit_mb_per_member     = optional(number, 3670016)<br>      rate_period_seconds          = optional(number, 900)<br>      rate_units                   = optional(string, "mb")<br>    })<br>    memory = object({<br>      io_above_percent         = optional(number, 90)<br>      io_enabled               = optional(bool, false)<br>      io_over_period           = optional(string, "15m")<br>      rate_increase_percent    = optional(number, 10)<br>      rate_limit_mb_per_member = optional(number, 114688)<br>      rate_period_seconds      = optional(number, 900)<br>      rate_units               = optional(string, "mb")<br>    })<br>  })</pre> | `null` | no |
| <a name="input_backup_encryption_key_crn"></a> [backup\_encryption\_key\_crn](#input\_backup\_encryption\_key\_crn) | The CRN of a Key Protect key, that you want to use for encrypting disk that holds deployment backups. Only used if var.kms\_encryption\_enabled is set to true. If no value passed, the value passed for the 'kms\_key\_crn' variable will be used. BYOK for backups is available only in US regions us-south and us-east, and eu-de. Only keys in the us-south and eu-de are durable to region failures. To ensure that your backups are available even if a region failure occurs, you must use a key from us-south or eu-de. Take note that Hyper Protect Crypto Services for IBM Cloud® Databases backups is not currently supported, so if no value is passed here, but a HPCS value is passed for var.kms\_key\_crn, databases backup encryption will use the default encryption keys. | `string` | `null` | no |
| <a name="input_cbr_rules"></a> [cbr\_rules](#input\_cbr\_rules) | (Optional, list) List of CBR rules to create | <pre>list(object({<br>    description = string<br>    account_id  = string<br>    rule_contexts = list(object({<br>      attributes = optional(list(object({<br>        name  = string<br>        value = string<br>    }))) }))<br>    enforcement_mode = string<br>  }))</pre> | `[]` | no |
| <a name="input_elasticsearch_version"></a> [elasticsearch\_version](#input\_elasticsearch\_version) | Version of Elasticsearch to deploy | `string` | `null` | no |
| <a name="input_existing_kms_instance_guid"></a> [existing\_kms\_instance\_guid](#input\_existing\_kms\_instance\_guid) | The GUID of the Hyper Protect or Key Protect instance in which the key specified in var.kms\_key\_crn and var.backup\_encryption\_key\_crn is coming from. Only required if var.kms\_encryption\_enabled is 'true', var.skip\_iam\_authorization\_policy is 'false', and passing a value for var.kms\_key\_crn and/or var.backup\_encryption\_key\_crn. | `string` | `null` | no |
| <a name="input_kms_encryption_enabled"></a> [kms\_encryption\_enabled](#input\_kms\_encryption\_enabled) | Set this to true to control the encryption keys used to encrypt the data that you store in IBM Cloud® Databases. If set to false, the data is encrypted by using randomly generated keys. For more info on Key Protect integration, see https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect. For more info on HPCS integration, see https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs | `bool` | `false` | no |
| <a name="input_kms_key_crn"></a> [kms\_key\_crn](#input\_kms\_key\_crn) | The root key CRN of a Key Management Services like Key Protect or Hyper Protect Crypto Service (HPCS) that you want to use for disk encryption. Only used if var.kms\_encryption\_enabled is set to true. | `string` | `null` | no |
| <a name="input_member_cpu_count"></a> [member\_cpu\_count](#input\_member\_cpu\_count) | Allocated dedicated CPU per member. For shared CPU, set to 0. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling | `number` | `0` | no |
| <a name="input_member_disk_mb"></a> [member\_disk\_mb](#input\_member\_disk\_mb) | Allocated disk per-member. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling | `number` | `5120` | no |
| <a name="input_member_memory_mb"></a> [member\_memory\_mb](#input\_member\_memory\_mb) | Allocated memory per-member. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling | `number` | `1024` | no |
| <a name="input_members"></a> [members](#input\_members) | Allocated number of members. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling | `number` | `3` | no |
| <a name="input_name"></a> [name](#input\_name) | The name to give the Elasticsearch instance. | `string` | n/a | yes |
| <a name="input_plan"></a> [plan](#input\_plan) | The name of the service plan that you choose for your Elasticsearch instance | `string` | `"standard"` | no |
| <a name="input_plan_validation"></a> [plan\_validation](#input\_plan\_validation) | Enable or disable validating the database parameters for elasticsearch during the plan phase | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where you want to deploy your instance. | `string` | `"us-south"` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | The resource group ID where the Elasticsearch instance will be created. | `string` | n/a | yes |
| <a name="input_service_credential_names"></a> [service\_credential\_names](#input\_service\_credential\_names) | Map of name, role for service credentials that you want to create for the database | `map(string)` | `{}` | no |
| <a name="input_service_endpoints"></a> [service\_endpoints](#input\_service\_endpoints) | Sets the endpoint of the instance, valid values are 'public', 'private', or 'public-and-private' | `string` | `"public"` | no |
| <a name="input_skip_iam_authorization_policy"></a> [skip\_iam\_authorization\_policy](#input\_skip\_iam\_authorization\_policy) | Set to true to skip the creation of an IAM authorization policy that permits all Elasticsearch database instances in the resource group to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing\_kms\_instance\_guid variable. In addition, no policy is created if var.kms\_encryption\_enabled is set to false. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags associated with the instance (Optional, array of strings). | `list(string)` | `[]` | no |
| <a name="input_users"></a> [users](#input\_users) | A list of users that you want to create on the database. Multiple blocks are allowed. The user password must be in the range of 10-32 characters. Be warned that in most case using IAM service credentials (via the var.service\_credential\_names) is sufficient to control access to the Elasticsearch instance. This blocks creates native elasticsearch database users, more info on that can be found here https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-connection-strings&interface=cli#connection-strings-add-users | <pre>list(object({<br>    name     = string<br>    password = string # pragma: allowlist secret<br>    type     = string # "type" is required to generate the connection string for the outputs.<br>    role     = optional(string)<br>  }))</pre> | `[]` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_cbr_rule_ids"></a> [cbr\_rule\_ids](#output\_cbr\_rule\_ids) | CBR rule ids created to restrict Elasticsearch |
| <a name="output_crn"></a> [crn](#output\_crn) | Elasticsearch instance crn |
| <a name="output_guid"></a> [guid](#output\_guid) | Elasticsearch instance guid |
| <a name="output_hostname"></a> [hostname](#output\_hostname) | Database hostname. Only contains value when var.service\_credential\_names or var.users are set. |
| <a name="output_id"></a> [id](#output\_id) | Elasticsearch id |
| <a name="output_port"></a> [port](#output\_port) | Database port. Only contains value when var.service\_credential\_names or var.users are set. |
| <a name="output_service_credentials_json"></a> [service\_credentials\_json](#output\_service\_credentials\_json) | Service credentials json map |
| <a name="output_service_credentials_object"></a> [service\_credentials\_object](#output\_service\_credentials\_object) | Service credentials object |
| <a name="output_version"></a> [version](#output\_version) | Elasticsearch version |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- Leave this section as is so that your module has a link to local development environment set up steps for contributors to follow -->
## Contributing

You can report issues and request features for this module in GitHub issues in the module repo. See [Report an issue or request a feature](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md).

To set up your local development environment, see [Local development setup](https://terraform-ibm-modules.github.io/documentation/#/local-dev-setup) in the project documentation.
