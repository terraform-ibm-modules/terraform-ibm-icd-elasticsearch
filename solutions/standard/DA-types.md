# Configuring complex inputs in Databases for Elasticsearch

Several optional input variables in the IBM Cloud [Databases for Elasticsearch deployable architecture](https://cloud.ibm.com/catalog#deployable_architecture) use complex object types. You specify these inputs when you configure you deployable architecture.

- [Service credentials](#svc-credential-name) (`service_credential_names`)
- [Users](#users) (`users`)
- [Autoscaling](#autoscaling) (`auto_scaling`)

## Service credentials <a name="svc-credential-name"></a>

You can specify a set of IAM credentials to connect to the database with the `service_credential_names` input variable. Include a credential name and IAM service role for each key-value pair. Each role provides a specific level of access to the database. For more information, see [Adding and viewing credentials](https://cloud.ibm.com/docs/account?topic=account-service_credentials&interface=ui).

- Variable name: `service_credential_names`.
- Type: A map. The key is the name of the service credential. The value is the role that is assigned to that credential.
- Default value: An empty map (`{}`).

### Options for service_credential_names

- Key (required): The name of the service credential.
- Value (required): The IAM service role that is assigned to the credential. For more information, see [IBM Cloud IAM roles](https://cloud.ibm.com/docs/account?topic=account-userroles).

### Example service credential

Example with single role:

```hcl
  {
    "elastic_user_1" = "Viewer"
  }
```

Example with more than one role:

```hcl
  {
    "elastic_user_2" = ["Editor", "Operator"]
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

The following example shows a list of two users. One user does not have an optional role.

```hcl
[
    {
      name     = "es_admin"
      password = "securepassword123"
      type     = "Administrator"
      role     = "Administrator"
    },
    {
      name     = "es_reader"
      password = "readpassword123"
      type     = "Operator"
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
  disk {
    capacity_enabled             = true
    free_space_less_than_percent   = 15
    io_above_percent             = 85
    io_enabled                  = true
    io_over_period               = "15m"
    rate_increase_percent         = 15
    rate_limit_mb_per_member     = 3670016
    rate_period_seconds          = 900
    rate_units                  = "mb"
  }
  memory {
    io_above_percent         = 90
    io_enabled               = true
    io_over_period           = "15m"
    rate_increase_percent    = 10
    rate_limit_mb_per_member = 114688
    rate_period_seconds      = 900
    rate_units               = "mb"
  }
}
```
