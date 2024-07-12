## ICD Elasticsearch Module

[![Graduated (Supported)](https://img.shields.io/badge/Status-Graduated%20(Supported)-brightgreen)](https://terraform-ibm-modules.github.io/documentation/#/badge-status)
[![latest release](https://img.shields.io/github/v/release/terraform-ibm-modules/terraform-ibm-icd-elasticsearch?logo=GitHub&sort=semver)](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/releases/latest)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)


<!-- BEGIN OVERVIEW HOOK -->
## Overview
* [terraform-ibm-icd-elasticsearch](#terraform-ibm-icd-elasticsearch)
* [Submodules](./modules)
    * [fscloud](./modules/fscloud)
* [Examples](./examples)
    * [Basic example](./examples/basic)
    * [Complete example with autoscaling, BYOK encryption, service credentials creation, index creation and updates to cluster-wide settings](./examples/complete)
    * [Financial Services Cloud profile example with autoscaling enabled](./examples/fscloud)
* [Contributing](#contributing)
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
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.65.0, <2.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cbr_rule"></a> [cbr\_rule](#module\_cbr\_rule) | terraform-ibm-modules/cbr/ibm//modules/cbr-rule-module | 1.22.2 |

### Resources

| Name | Type |
|------|------|
| [ibm_database.elasticsearch](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/database) | resource |
| [ibm_iam_authorization_policy.policy](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_resource_key.service_credentials](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/resource_key) | resource |
| [ibm_resource_tag.elasticsearch_tag](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/resources/resource_tag) | resource |
| [time_sleep.wait_for_authorization_policy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [ibm_database_connection.database_connection](https://registry.terraform.io/providers/ibm-cloud/ibm/latest/docs/data-sources/database_connection) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_tags"></a> [access\_tags](#input\_access\_tags) | A list of access tags to apply to the Databases for Elasticsearch instance created by the module. [Learn more](https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial). | `list(string)` | `[]` | no |
| <a name="input_admin_pass"></a> [admin\_pass](#input\_admin\_pass) | The password for the database administrator. If the admin password is null, the admin user ID cannot be accessed. You can specify more users in a user block. | `string` | `null` | no |
| <a name="input_auto_scaling"></a> [auto\_scaling](#input\_auto\_scaling) | The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations). | <pre>object({<br>    disk = object({<br>      capacity_enabled             = optional(bool, false)<br>      free_space_less_than_percent = optional(number, 10)<br>      io_above_percent             = optional(number, 90)<br>      io_enabled                   = optional(bool, false)<br>      io_over_period               = optional(string, "15m")<br>      rate_increase_percent        = optional(number, 10)<br>      rate_limit_mb_per_member     = optional(number, 3670016)<br>      rate_period_seconds          = optional(number, 900)<br>      rate_units                   = optional(string, "mb")<br>    })<br>    memory = object({<br>      io_above_percent         = optional(number, 90)<br>      io_enabled               = optional(bool, false)<br>      io_over_period           = optional(string, "15m")<br>      rate_increase_percent    = optional(number, 10)<br>      rate_limit_mb_per_member = optional(number, 114688)<br>      rate_period_seconds      = optional(number, 900)<br>      rate_units               = optional(string, "mb")<br>    })<br>  })</pre> | `null` | no |
| <a name="input_backup_crn"></a> [backup\_crn](#input\_backup\_crn) | The CRN of a backup resource to restore from. The backup is created by a database deployment with the same service ID. The backup is loaded after both provisioning is complete and the new deployment that uses that data starts. Specify a backup CRN is in the format `crn:v1:<...>:backup:`. If not specified, the database is provisioned empty. | `string` | `null` | no |
| <a name="input_backup_encryption_key_crn"></a> [backup\_encryption\_key\_crn](#input\_backup\_encryption\_key\_crn) | The CRN of a KMS (Key Protect or Hyper Protect Crypto Service) key to use for encrypting the disk that holds deployment backups. Applies only if `kms_encryption_enabled` is true. Limitations exist for regions. For more information, see [Key Protect integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok) or [Hyper Protect Crypto Services integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs#use-hpcs-backups). | `string` | `null` | no |
| <a name="input_cbr_rules"></a> [cbr\_rules](#input\_cbr\_rules) | The list of context-based restriction rules to create. | <pre>list(object({<br>    description = string<br>    account_id  = string<br>    rule_contexts = list(object({<br>      attributes = optional(list(object({<br>        name  = string<br>        value = string<br>    }))) }))<br>    enforcement_mode = string<br>  }))</pre> | `[]` | no |
| <a name="input_elasticsearch_version"></a> [elasticsearch\_version](#input\_elasticsearch\_version) | The version of Databases for Elasticsearch to deploy. Possible values: `8.10`, `8.12`, which requires an Enterprise Platinum pricing plan. If no value is specified, the current preferred version for IBM Cloud Databases is used. | `string` | `null` | no |
| <a name="input_existing_kms_instance_guid"></a> [existing\_kms\_instance\_guid](#input\_existing\_kms\_instance\_guid) | The GUID of a Hyper Protect Crypto Services or Key Protect instance for the CRN specified in `kms_key_crn` and `backup_encryption_key_crn`. Applies only if `kms_encryption_enabled` is true, `skip_iam_authorization_policy` is false, and you specify values for `kms_key_crn` or `backup_encryption_key_crn`. | `string` | `null` | no |
| <a name="input_kms_encryption_enabled"></a> [kms\_encryption\_enabled](#input\_kms\_encryption\_enabled) | Whether to specify the keys used to encrypt data in the database. Specify `true` to identify the encryption keys. If set to `false`, the data is encrypted with randomly generated keys. [Learn more about Key Protect integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect). [Learn more about HPCS integration](https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-hpcs). | `bool` | `false` | no |
| <a name="input_kms_key_crn"></a> [kms\_key\_crn](#input\_kms\_key\_crn) | The root key CRN of the Key Protect or Hyper Protect Crypto Services instance to use for disk encryption. Applies only if `kms_encryption_enabled` is true. | `string` | `null` | no |
| <a name="input_member_cpu_count"></a> [member\_cpu\_count](#input\_member\_cpu\_count) | The dedicated CPU per member that is allocated. For shared CPU, set to 0. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling). | `number` | `0` | no |
| <a name="input_member_disk_mb"></a> [member\_disk\_mb](#input\_member\_disk\_mb) | The disk that is allocated per member. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling). | `number` | `5120` | no |
| <a name="input_member_host_flavor"></a> [member\_host\_flavor](#input\_member\_host\_flavor) | The host flavor per member. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor). | `string` | `null` | no |
| <a name="input_member_memory_mb"></a> [member\_memory\_mb](#input\_member\_memory\_mb) | The memory per member that is allocated. For more information, see https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling | `number` | `4096` | no |
| <a name="input_members"></a> [members](#input\_members) | The number of members that are allocated. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-resources-scaling). | `number` | `3` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the Databases for Elasticsearch instance. | `string` | n/a | yes |
| <a name="input_plan"></a> [plan](#input\_plan) | The pricing plan for the Databases for Elasticsearch instance. Must be `enterprise` or `platinum` if the `elasticsearch_version` variable is set to `8.10` or later. | `string` | `"enterprise"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where you want to deploy your instance. | `string` | `"us-south"` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | The resource group ID where the Databases for Elasticsearch instance is created. | `string` | n/a | yes |
| <a name="input_service_credential_names"></a> [service\_credential\_names](#input\_service\_credential\_names) | The map of name and role for service credentials that you want to create for the database. | `map(string)` | `{}` | no |
| <a name="input_service_endpoints"></a> [service\_endpoints](#input\_service\_endpoints) | The type of endpoint of the database instance. Possible values: `public`, `private`, `public-and-private`. | `string` | `"public"` | no |
| <a name="input_skip_iam_authorization_policy"></a> [skip\_iam\_authorization\_policy](#input\_skip\_iam\_authorization\_policy) | Whether to create an IAM authorization policy that permits all Databases for Elasticsearch instances in the resource group to read the encryption key from the Hyper Protect Crypto Services instance specified in the `existing_kms_instance_guid` variable. If set to `false`, specify a value for the KMS instance in the `existing_kms_instance_guid` variable. No policy is created if `kms_encryption_enabled` is false. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | The list of tags to be added to the Databases for Elasticsearch instance. | `list(string)` | `[]` | no |
| <a name="input_use_default_backup_encryption_key"></a> [use\_default\_backup\_encryption\_key](#input\_use\_default\_backup\_encryption\_key) | Whether to use the IBM Cloud Databases generated keys. | `bool` | `false` | no |
| <a name="input_users"></a> [users](#input\_users) | The list of users that have access to the database. Multiple blocks are allowed. The user password must be 10-32 characters. In most cases, you can use IAM service credentials (by specifying `service_credential_names`) to control access to the database instance. This block creates native database users. [Learn more](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-user-management&interface=ui). | <pre>list(object({<br>    name     = string<br>    password = string           # pragma: allowlist secret<br>    type     = optional(string) # "type" is required to generate the connection string for the outputs.<br>    role     = optional(string)<br>  }))</pre> | `[]` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_adminuser"></a> [adminuser](#output\_adminuser) | Database admin user name |
| <a name="output_cbr_rule_ids"></a> [cbr\_rule\_ids](#output\_cbr\_rule\_ids) | CBR rule ids created to restrict Elasticsearch |
| <a name="output_certificate_base64"></a> [certificate\_base64](#output\_certificate\_base64) | Database connection certificate |
| <a name="output_crn"></a> [crn](#output\_crn) | Elasticsearch instance crn |
| <a name="output_guid"></a> [guid](#output\_guid) | Elasticsearch instance guid |
| <a name="output_hostname"></a> [hostname](#output\_hostname) | Database connection hostname |
| <a name="output_id"></a> [id](#output\_id) | Elasticsearch id |
| <a name="output_port"></a> [port](#output\_port) | Database connection port |
| <a name="output_service_credentials_json"></a> [service\_credentials\_json](#output\_service\_credentials\_json) | Service credentials json map |
| <a name="output_service_credentials_object"></a> [service\_credentials\_object](#output\_service\_credentials\_object) | Service credentials object |
| <a name="output_version"></a> [version](#output\_version) | Elasticsearch version |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- Leave this section as is so that your module has a link to local development environment set up steps for contributors to follow -->
## Contributing

You can report issues and request features for this module in GitHub issues in the module repo. See [Report an issue or request a feature](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md).

To set up your local development environment, see [Local development setup](https://terraform-ibm-modules.github.io/documentation/#/local-dev-setup) in the project documentation.
