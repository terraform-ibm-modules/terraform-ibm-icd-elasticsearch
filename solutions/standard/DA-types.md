# IBM Cloud Elasticsearch Deployable Architecture Variables Documentation
This document provides detailed information about the complex object types used in the IBM Cloud Elasticsearch DA (Deployable Architecture).


## 1. Service Credential Names

**Description:**
This variable defines a map of service credential names and their corresponding roles for the Elasticsearch database. This allows for the creation of service credentials with specific roles, providing controlled access to the database.

**Type:**
The `service_credential_names` variable is a map where the key is the name of the service credential and the value is the role assigned to that credential.

**Default Value:**
The default value for the `service_credential_names` variable is an empty map (`{}`).

### Detailed Structure:

- `Key (name, required):` The name of the service credential.

- `Value (role, required):` The role assigned to the service credential.

## 2. Users

**Description:**

This variable defines a list of users who have access to the Elasticsearch database. Each user in the list includes a name, password, type, and an optional role. This configuration creates native Elasticsearch database users.

**Type:**
The `users` variable is a list of objects, where each object represents a user with the following properties:
 - `name (required):` The username for the user account.

 - `password (required):` The password for the user account. This password must be in the range of 10-32 characters. This field is sensitive and should be handled securely.

- `type (required)`: This is to specify the type of user.
   - The "type" field is required to generate the connection string for the outputs.

 - `role (optional):` Defines the role assigned to the user, determining their access level and permissions.


**Default Value:**
The default value for the `users` variable is an empty list (`[]`).

**Sensitive:**
The `users` variable is marked as sensitive due to the inclusion of passwords.


## 3. Auto Scaling
**Description:**

This variable defines the auto-scaling configuration for the Elasticsearch deployment. Auto-scaling allows the database to automatically adjust resources in response to changes in usage, ensuring optimal performance and resource utilization. It includes settings for both disk, memory auto-scaling or both.

The auto_scaling variable is an object that contains nested objects for `disk` and `memory` configurations.

**Disk Auto-Scaling Configuration**
The disk object within `auto_scaling` contains the following properties:

- `capacity_enabled (optional, default=false):` Indicates whether disk capacity auto-scaling is enabled.

- `free_space_less_than_percent (optional, default=10):` Specifies the threshold percentage of free disk space below which auto-scaling is triggered.

- `io_above_percent (optional, default=90):` Sets the IO(Input/Output) usage percentage above which auto-scaling is triggered.

- `io_enabled (optional, default=false):` Indicates whether IO-based auto-scaling is enabled.

- `io_over_period (optional, default="15m"(15 minutes)):` Defines the period over which IO usage is evaluated for auto-scaling.

- `rate_increase_percent (optional, default=10):` Specifies the percentage increase in disk capacity when auto-scaling is triggered.

- `rate_limit_mb_per_member (optional, default=3670016 MB):` Sets the limit on the rate of disk increase per member (in megabytes).

- `rate_period_seconds (optional, default=900 seconds (15 minutes)):` Defines the period (in seconds) over which the rate limit is applied.

- `rate_units (optional, default="mb" (megabytes)):` Specifies the units used for rate increase.

<br>**Memory Auto-Scaling Configuration**: The memory object within auto_scaling contains the following properties:

- `io_above_percent (optional, default= 90):` Sets the IO usage percentage above which memory auto-scaling is triggered.

- `io_enabled (optional, default= false):` Indicates whether IO-based auto-scaling for memory is enabled.

- `io_over_period (optional, default= "15m" (15 minutes)):` Defines the period over which IO usage is evaluated for memory auto-scaling.

- `rate_increase_percent (optional, default= 10):` Specifies the percentage increase in memory capacity when auto-scaling is triggered.

- `rate_limit_mb_per_member (optional, default= 114688 MB):` Sets the limit on the rate of memory increase per member (in megabytes).

- `rate_period_seconds (optional, default= 900 seconds (15 minutes)):` Defines the period (in seconds) over which the rate limit is applied for memory.

- `rate_units (optional, default= "mb" (megabytes)):` Specifies the units used for rate increase.

**Sample Example:** Below example is to illustrate how to use both disk and memory configurations.

```hcl
variable "auto_scaling" {
  type = object({
    disk = object({
      capacity_enabled             = true
      free_space_less_than_percent = 15
      io_above_percent             = 85
      io_enabled                   = true
      io_over_period               = "10m"
      rate_increase_percent        = 20
      rate_limit_mb_per_member     = 5000000
      rate_period_seconds          = 600
      rate_units                   = "mb"
    })
    memory = object({
      io_above_percent         = 80
      io_enabled               = true
      io_over_period           = "10m"
      rate_increase_percent    = 15
      rate_limit_mb_per_member = 200000
      rate_period_seconds      = 600
      rate_units               = "mb"
    })
  })
  description = "The rules to allow the database to increase resources in response to usage. Only a single autoscaling block is allowed. Make sure you understand the effects of autoscaling, especially for production environments. See https://cloud.ibm.com/docs/databases-for-elasticsearch?topic=databases-for-elasticsearch-autoscaling&interface=cli#autoscaling-considerations in the IBM Cloud Docs."
  default     = null
}

```
