# Configuring complex inputs in Databases for Elasticsearch

Several optional input variables in the IBM Cloud [Databases for Elasticsearch deployable architecture](https://cloud.ibm.com/catalog#deployable_architecture) use complex object types. You specify these inputs when you configure you deployable architecture.

- [Service credentials](#svc-credential-name) (`service_credential_names`)
- [Users](#users) (`users`)
- [Autoscaling](#autoscaling) (`auto_scaling`)
- [Service credential secrets](#service-credential-secrets) (`service_credential_secrets`)

## Service credentials <a name="svc-credential-name"></a>

You can specify a set of IAM credentials to connect to the database with the `service_credential_names` input variable. Include a credential name and IAM service role for each key-value pair. Each role provides a specific level of access to the database. For more information, see [Adding and viewing credentials](https://cloud.ibm.com/docs/account?topic=account-service_credentials&interface=ui).

- Variable name: `service_credential_names`.
- Type: A map. The key is the name of the service credential. The value is the role that is assigned to that credential.
- Default value: An empty map (`{}`).

### Options for service_credential_names

- Key (required): The name of the service credential.
- Value (required): The IAM service role that is assigned to the credential. For more information, see [IBM Cloud IAM roles](https://cloud.ibm.com/docs/account?topic=account-userroles).

### Example service credential

```hcl
  {
      "es_admin" : "Administrator",
      "es_reader" : "Operator",
      "es_viewer" : "Viewer",
      "es_editor" : "Editor"
  }
```


## Users <a name="users"></a>

If you can't use the IAM-enabled `service_credential_names` input variable for access, you can create users and roles directly in the database. For more information, see [Managing users and roles](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-user-management&interface=ui).

:exclamation: **Important:** The `users` input contains sensitive information (the user's password).

- Variable name: `users`.
- Type: A list of objects that represent a user
- Default value: An empty list (`[]`)

### Options for users

- `name` (required): The username for the user account.
- `password` (required): The password for the user account in the range of 10-32 characters.
- `type` (required): The user type. The "type" field is required to generate the connection string for the outputs.
- `role`: The user role. The role determines the user's access level and permissions.

### Example users

```hcl
[
  {
    "name": "es_admin",
    "password": "securepassword123",
    "type": "database",
  },
  {
    "name": "es_reader",
    "password": "readpassword123",
    "type": "ops_manager"
  }
]
```

## Autoscaling <a name="autoscaling"></a>

The Autoscaling variable sets the rules for how database increase resources in response to usage. Make sure you understand the effects of autoscaling, especially for production environments. For more information, see [Autoscaling](https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations).

- Variable name: `auto_scaling`
- Type: An object with `disk` and `memory` configurations

### Disk options for auto_scaling

Disk autoscaling specifies thresholds when scaling can occur based on disk usage, disk I/O utilization, or both.

The disk object in the `auto_scaling` input contains the following options. All options are optional.

- `capacity_enabled`: Whether disk capacity autoscaling is enabled (default: `false`).
- `free_space_less_than_percent`: The percentage of free disk space that triggers autoscaling (default: `10`).
- `io_above_percent`: The percentage of I/O (input/output) disk usage that triggers autoscaling (default: `90`).
- `io_enabled`: Indicates whether IO-based autoscaling is enabled (default: `false`).
- `io_over_period`: How long I/O usage is evaluated for autoscaling (default: `"15m"` (15 minutes)).
- `rate_increase_percent`: The percentage increase in disk capacity when autoscaling is triggered (default: `10`).
- `rate_limit_mb_per_member`: The limit in megabytes for the rate of disk increase per member (default: `3670016`).
- `rate_period_seconds`: How long (in seconds) the rate limit is applied for disk (default: `900` (15 minutes)).
- `rate_units`: The units to use for the rate increase (default: `"mb"` (megabytes)).

### Memory options for auto_scaling

The memory object within auto_scaling contains the following options. All options are optional.

- `io_above_percent`: The percentage of I/O memory usage that triggers autoscaling (default: `90`).
- `io_enabled`: Whether IO-based autoscaling for memory is enabled (default: `false`).
- `io_over_period`: How long I/O usage is evaluated for memory autoscaling (default: `"15m"` (15 minutes)).
- `rate_increase_percent`: The percentage increase in memory capacity that triggers autoscaling (default: `10`).
- `rate_limit_mb_per_member`: The limit in megabytes for the rate of memory increase per member (default: `114688`).
- `rate_period_seconds`: How long (in seconds) the rate limit is applied for memory (default: `900` (15 minutes)).
- `rate_units`: The memory size units to use for the rate increase (default: `"mb"` (megabytes)).

### Example autoscaling

The following example shows values for both disk and memory for the `auto_scaling` input.

```hcl
{
  "disk": {
      "capacity_enabled": true,
      "free_space_less_than_percent": 15,
      "io_above_percent": 85,
      "io_enabled": true,
      "io_over_period": "15m",
      "rate_increase_percent": 15,
      "rate_limit_mb_per_member": 3670016,
      "rate_period_seconds": 900,
      "rate_units": "mb"
  },
  "memory": {
      "io_above_percent": 90,
      "io_enabled": true,
      "io_over_period": "15m",
      "rate_increase_percent": 10,
      "rate_limit_mb_per_member": 114688,
      "rate_period_seconds": 900,
      "rate_units": "mb"
  }
}
```

## Service credential secrets <a name="service-credential-secrets"></a>

When you add an IBM Databases for Elasticsearch service from the IBM Cloud catalog to an IBM Cloud Projects service, you can configure service credentials. In the edit mode for the projects configuration, select the Configure panel and then click the optional tab.

In the configuration, specify the secret group name, whether it already exists or will be created and include all the necessary service credential secrets that need to be created within that secret group.

To enter a custom value, use the edit action to open the "Edit Array" panel. Add the service credential secrets configurations to the array here.

 [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/sm_service_credentials_secret) about service credential secrets.

- Variable name: `service_credential_secrets`.
- Type: A list of objects that represent a service credential secret groups and secrets
- Default value: An empty list (`[]`)

### Options for service_credential_secrets

- `secret_group_name` (required): A unique human-readable name that identifies this service credential secret group.
- `secret_group_description` (optional, default = `null`): A human-readable description for this secret group.
- `existing_secret_group`: (optional, default = `false`): Set to true, if secret group name provided in the variable `secret_group_name` already exists.
- `service_credentials`: (optional, default = `[]`): A list of object that represents a service credential secret.

### Options for service_credentials

- `secret_name`: (required): A unique human-readable name of the secret to create.
- `service_credentials_source_service_role_crn`: (required): The CRN of the role to give the service credential in the IBM Cloud Database service. Service credentials role CRNs can be found at https://cloud.ibm.com/iam/roles, select the IBM Cloud Database and select the role.
- `secret_labels`: (optional, default = `[]`): Labels of the secret to create. Up to 30 labels can be created. Labels can be 2 - 30 characters, including spaces. Special characters that are not permitted include the angled brackets (<>), comma (,), colon (:), ampersand (&), and vertical pipe character (|).
- `secret_auto_rotation`: (optional, default = `true`): Whether to configure automatic rotation of service credential.
- `secret_auto_rotation_unit`: (optional, default = `day`): Specifies the unit of time for rotation of a secret. Acceptable values are `day` or `month`.
- `secret_auto_rotation_interval`: (optional, default = `89`): Specifies the rotation interval for the rotation unit.
- `service_credentials_ttl`: (optional, default = `7776000`): The time-to-live (TTL) to assign to generated service credentials (in seconds).
- `service_credential_secret_description`: (optional, default = `null`): Description of the secret to create.

The following example includes all the configuration options for four service credentials and two secret groups.
```hcl
[
  {
    "secret_group_name": "sg-1"
    "existing_secret_group": true
    "service_credentials": [                                              # pragma: allowlist secret
      {
        "secret_name": "cred-1"
        "service_credentials_source_service_role_crn":  "crn:v1:bluemix:public:iam::::role:Editor"
        "secret_labels": ["test-editor-1", "test-editor-2"]
        "secret_auto_rotation": true
        "secret_auto_rotation_unit": "day"
        "secret_auto_rotation_interval": 89
        "service_credentials_ttl": 7776000
        "service_credential_secret_description": "sample description"
      },
      {
        "secret_name": "cred-2"
        "service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Viewer"
      }
    ]
  },
  {
    "secret_group_name": "sg-2"
    "service_credentials": [                                              # pragma: allowlist secret
      {
        "secret_name": "cred-3"
        "service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Viewer"
      }
    ]
  }
]
```
### Options for kibana_visibility

When the Kibana application visibility is changed from private to public using `kibana_visibility` variable, it will become accessible from the public Internet. However, access via the IBM Cloud private network will no longer be available. This change takes effect immediately, potentially impacting active users or integrations. It is important to consider the associated security implications before proceeding, [learn more](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsvisibility).
If Kibana is enabled, you can access the Kibana application over a IBM private network using the method outlined [here](https://cloud.ibm.com/docs/codeengine?topic=codeengine-vpe).
