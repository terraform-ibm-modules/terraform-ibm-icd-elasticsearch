##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source = "git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git?ref=v1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Elasticsearch Instance
##############################################################################

module "database" {
  source                = "../../"
  resource_group_id     = module.resource_group.resource_group_id
  name                  = "${var.prefix}-data-store"
  region                = var.region
  elasticsearch_version = var.elasticsearch_version
  tags                  = var.resource_tags
  access_tags           = var.access_tags
  service_endpoints     = var.service_endpoints
  member_host_flavor    = var.member_host_flavor
  service_credential_names = {
    "elasticsearch_admin" : "Administrator",
    "elasticsearch_operator" : "Operator",
    "elasticsearch_viewer" : "Viewer",
    "elasticsearch_editor" : "Editor",
  }
}

# wait 60 secs to allow IAM credential access to kick in before configuring instance
# without the wait, you can intermittently get "Error 401 (Unauthorized)"
resource "time_sleep" "wait" {
  depends_on      = [module.database]
  create_duration = "60s"
}

resource "elasticsearch_index" "test" {
  depends_on         = [time_sleep.wait]
  name               = "terraform-test"
  number_of_shards   = 1
  number_of_replicas = 1
  force_destroy      = true
}

resource "elasticsearch_cluster_settings" "global" {
  depends_on                  = [time_sleep.wait]
  cluster_max_shards_per_node = 10
  action_auto_create_index    = "my-index-000001,index10,-index1*,+ind*"
}
