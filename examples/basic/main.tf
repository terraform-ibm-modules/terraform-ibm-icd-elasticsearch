locals {
  # Determine if gen2 plan is being used
  is_gen2 = can(regex("-gen2$", var.plan))

  gen2_host_flavor    = "bx3d.4x20"
  classic_host_flavor = "multitenant"

  endpoint_type = var.service_endpoints == "public-and-private" ? "public" : var.service_endpoints

  gen2_service_credential_names = [
    {
      name     = "elasticsearch_manager"
      role     = "Manager"
      endpoint = local.endpoint_type
    },
    {
      name     = "elasticsearch_writer"
      role     = "Writer"
      endpoint = local.endpoint_type
    }
  ]
  classic_service_credential_names = [
    {
      name     = "elasticsearch_admin"
      role     = "Administrator"
      endpoint = local.endpoint_type
    },
    {
      name     = "elasticsearch_operator"
      role     = "Operator"
      endpoint = local.endpoint_type
    },
    {
      name     = "elasticsearch_viewer"
      role     = "Viewer"
      endpoint = local.endpoint_type
    },
    {
      name     = "elasticsearch_editor"
      role     = "Editor"
      endpoint = local.endpoint_type
    }
  ]
}

##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.6.1"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Elasticsearch Instance
##############################################################################

module "database" {
  source = "../../"
  # remove the above line and uncomment the below 2 lines to consume the module from the registry
  # source            = "terraform-ibm-modules/icd-elasticsearch/ibm"
  # version           = "X.Y.Z" # Replace "X.Y.Z" with a release version to lock into a specific release
  resource_group_id        = module.resource_group.resource_group_id
  name                     = "${var.prefix}-data-store"
  region                   = var.region
  plan                     = var.plan
  elasticsearch_version    = local.is_gen2 ? "8.0" : var.elasticsearch_version # TODO: gen2 hardcoded to 8.0 until the catalog/provider version list is fixed (unpinned provisions 8.19.11 which CustomizeDiff rejects)
  access_tags              = var.access_tags
  resource_tags            = var.resource_tags
  service_endpoints        = var.service_endpoints
  member_host_flavor       = local.is_gen2 ? local.gen2_host_flavor : local.classic_host_flavor
  disk_mb                  = local.is_gen2 ? 10240 : 5120
  deletion_protection      = false
  service_credential_names = local.is_gen2 ? local.gen2_service_credential_names : local.classic_service_credential_names
}

# wait 60 secs to allow IAM credential access to kick in before configuring instance
# without the wait, you can intermittently get "Error 401 (Unauthorized)"
resource "time_sleep" "wait" {
  depends_on      = [module.database]
  create_duration = "60s"
}

# The elasticsearch provider resources below are skipped for Gen2 instances because the Gen2 service
# credentials do not expose the connection details (hostname, port, certificate) used to configure the
# elasticsearch provider, and the Gen2 example deploys with private only endpoints.
resource "elasticsearch_index" "test" {
  count              = local.is_gen2 ? 0 : 1
  depends_on         = [time_sleep.wait]
  name               = "terraform-test"
  number_of_shards   = 1
  number_of_replicas = 1
  force_destroy      = true
}

resource "elasticsearch_cluster_settings" "global" {
  count                       = local.is_gen2 ? 0 : 1
  depends_on                  = [time_sleep.wait]
  cluster_max_shards_per_node = 10
  action_auto_create_index    = "my-index-000001,index10,-index1*,+ind*"
}
