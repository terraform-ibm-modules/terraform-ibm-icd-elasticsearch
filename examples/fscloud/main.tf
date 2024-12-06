##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Get Cloud Account ID
##############################################################################

data "ibm_iam_account_settings" "iam_account_settings" {
}

##############################################################################
# VPC
##############################################################################
resource "ibm_is_vpc" "example_vpc" {
  name           = "${var.prefix}-vpc"
  resource_group = module.resource_group.resource_group_id
  tags           = var.resource_tags
}

resource "ibm_is_subnet" "testacc_subnet" {
  name                     = "${var.prefix}-subnet"
  vpc                      = ibm_is_vpc.example_vpc.id
  zone                     = "${var.region}-1"
  total_ipv4_address_count = 256
  resource_group           = module.resource_group.resource_group_id
}

##############################################################################
# Create CBR Zone
##############################################################################
module "cbr_zone" {
  source           = "terraform-ibm-modules/cbr/ibm//modules/cbr-zone-module"
  version          = "1.29.0"
  name             = "${var.prefix}-VPC-network-zone"
  zone_description = "CBR Network zone containing VPC"
  account_id       = data.ibm_iam_account_settings.iam_account_settings.account_id
  addresses = [{
    type  = "vpc", # to bind a specific vpc to the zone
    value = ibm_is_vpc.example_vpc.crn,
  }]
}

##############################################################################
# Key Protect All Inclusive
##############################################################################

module "key_protect_all_inclusive" {
  source            = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version           = "4.17.1"
  resource_group_id = module.resource_group.resource_group_id
  # Only us-south, eu-de backup encryption keys are supported. See https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-key-protect&interface=ui#key-byok for details.
  # Note: Database instance and Key Protect must be created on the same region.
  region                    = var.region
  key_protect_instance_name = "${var.prefix}-kp"
  resource_tags             = var.resource_tags
  keys = [
    {
      key_ring_name = "icd"
      keys = [
        {
          key_name     = "backup-${var.prefix}-elasticsearch"
          force_delete = true
        }
      ]
    }
  ]
}

##############################################################################
# ICD elasticsearch database
##############################################################################

module "elasticsearch" {
  source                     = "../../modules/fscloud"
  resource_group_id          = module.resource_group.resource_group_id
  name                       = "${var.prefix}-elasticsearch"
  region                     = var.region
  tags                       = var.resource_tags
  access_tags                = var.access_tags
  kms_key_crn                = var.kms_key_crn
  existing_kms_instance_guid = var.existing_kms_instance_guid
  elasticsearch_version      = var.elasticsearch_version
  service_credential_names   = var.service_credential_names
  auto_scaling               = var.auto_scaling
  member_host_flavor         = "b3c.4x16.encrypted"
  backup_encryption_key_crn  = module.key_protect_all_inclusive.keys["icd.backup-${var.prefix}-elasticsearch"].crn
  backup_crn                 = var.backup_crn
  enable_elser_model         = var.enable_elser_model
  cbr_rules = [
    {
      description      = "${var.prefix}-elasticsearch access only from vpc"
      enforcement_mode = "enabled"
      account_id       = data.ibm_iam_account_settings.iam_account_settings.account_id
      rule_contexts = [{
        attributes = [
          {
            "name" : "endpointType",
            "value" : "private"
          },
          {
            name  = "networkZoneId"
            value = module.cbr_zone.zone_id
        }]
      }]
    }
  ]
}
