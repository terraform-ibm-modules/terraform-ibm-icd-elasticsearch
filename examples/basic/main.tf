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

module "icd_elasticsearch" {
  source                = "../../"
  resource_group_id     = module.resource_group.resource_group_id
  name                  = "${var.prefix}-elasticsearch"
  region                = var.region
  elasticsearch_version = var.elasticsearch_version
  tags                  = var.resource_tags
  access_tags           = var.access_tags
}
