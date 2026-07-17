locals {
  # Determine if gen2 plan is being used
  is_gen2 = can(regex("-gen2$", var.plan))

  gen2_host_flavor    = "bx3d.4x20"
  classic_host_flavor = "multitenant"

  # Use the most recent restorable backup
  restorable_backups = [
    for b in data.ibm_database_backups.backup_database.backups : b
    if b.is_restorable == true
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

data "ibm_database_backups" "backup_database" {
  deployment_id = var.existing_database_crn
}

# New elasticsearch instance restored from the most recent restorable backup
module "restored_icd_elasticsearch" {
  source = "../.."
  # remove the above line and uncomment the below 2 lines to consume the module from the registry
  # source            = "terraform-ibm-modules/icd-elasticsearch/ibm"
  # version           = "X.Y.Z" # Replace "X.Y.Z" with a release version to lock into a specific release
  resource_group_id     = module.resource_group.resource_group_id
  name                  = "${var.prefix}-elasticsearch-restored"
  plan                  = var.plan
  region                = var.region
  elasticsearch_version = var.elasticsearch_version
  access_tags           = var.access_tags
  resource_tags         = var.resource_tags
  member_host_flavor    = local.is_gen2 ? local.gen2_host_flavor : local.classic_host_flavor
  disk_mb               = local.is_gen2 ? 10240 : 5120
  deletion_protection   = false
  backup_crn            = local.restorable_backups[0].backup_id
}
