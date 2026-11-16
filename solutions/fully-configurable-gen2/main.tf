#######################################################################################################################
# Resource Group
#######################################################################################################################
locals {
  prefix = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""
}

module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.6.1"
  existing_resource_group_name = var.existing_resource_group_name
}

#######################################################################################################################
# KMS encryption key
#######################################################################################################################

locals {
  use_ibm_owned_encryption_key = !var.kms_encryption_enabled
  create_new_kms_key = (
    var.kms_encryption_enabled &&
    var.existing_elasticsearch_instance_crn == null &&
    var.existing_kms_key_crn == null
  )
  elasticsearch_key_name      = "${local.prefix}${var.key_name}"
  elasticsearch_key_ring_name = "${local.prefix}${var.key_ring_name}"
}

module "kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = local.create_new_kms_key ? 1 : 0
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "5.6.5"
  create_key_protect_instance = false
  region                      = local.kms_region
  existing_kms_instance_crn   = var.existing_kms_instance_crn
  key_ring_endpoint_type      = var.kms_endpoint_type
  key_endpoint_type           = var.kms_endpoint_type
  keys = [
    {
      key_ring_name     = local.elasticsearch_key_ring_name
      existing_key_ring = false
      keys = [
        {
          key_name                 = local.elasticsearch_key_name
          standard_key             = false
          rotation_interval_month  = 3
          dual_auth_delete_enabled = false
          force_delete             = true # Force delete must be set to true, or the terraform destroy will fail since the service does not de-register itself from the key until the reclamation period has expired.
        }
      ]
    }
  ]
}

########################################################################################################################
# Parse KMS info from given CRNs
########################################################################################################################

module "kms_instance_crn_parser" {
  count   = var.existing_kms_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.existing_kms_instance_crn
}

module "kms_key_crn_parser" {
  count   = var.existing_kms_key_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.existing_kms_key_crn
}

#######################################################################################################################
# KMS IAM Authorization Policies
#   - only created if user passes a value for 'ibmcloud_kms_api_key' (used when KMS is in different account to Elasticsearch)
#   - if no value passed for 'ibmcloud_kms_api_key', the auth policy is created by the Elasticsearch module
#######################################################################################################################

# Lookup account ID
data "ibm_iam_account_settings" "iam_account_settings" {
}

locals {
  account_id                           = data.ibm_iam_account_settings.iam_account_settings.account_id
  create_cross_account_kms_auth_policy = var.kms_encryption_enabled && !var.skip_elasticsearch_kms_auth_policy && var.ibmcloud_kms_api_key != null

  # If KMS encryption enabled (and existing ES instance is not being passed), parse details from the existing key if being passed, otherwise get it from the key that the DA creates
  kms_account_id    = !var.kms_encryption_enabled || var.existing_elasticsearch_instance_crn != null ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].account_id : module.kms_instance_crn_parser[0].account_id
  kms_service       = !var.kms_encryption_enabled || var.existing_elasticsearch_instance_crn != null ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].service_name : module.kms_instance_crn_parser[0].service_name
  kms_instance_guid = !var.kms_encryption_enabled || var.existing_elasticsearch_instance_crn != null ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].service_instance : module.kms_instance_crn_parser[0].service_instance
  kms_key_crn       = !var.kms_encryption_enabled || var.existing_elasticsearch_instance_crn != null ? null : var.existing_kms_key_crn != null ? var.existing_kms_key_crn : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].crn
  kms_key_id        = !var.kms_encryption_enabled || var.existing_elasticsearch_instance_crn != null ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].resource : module.kms[0].keys[format("%s.%s", local.elasticsearch_key_ring_name, local.elasticsearch_key_name)].key_id
  kms_region        = !var.kms_encryption_enabled || var.existing_elasticsearch_instance_crn != null ? null : var.existing_kms_key_crn != null ? module.kms_key_crn_parser[0].region : module.kms_instance_crn_parser[0].region
}

# Create auth policy (scoped to exact KMS key)
resource "ibm_iam_authorization_policy" "kms_policy" {
  count                  = local.create_cross_account_kms_auth_policy ? 1 : 0
  provider               = ibm.kms
  source_service_account = local.account_id
  source_service_name    = "databases-for-elasticsearch"
  # Workaround: Gen2 returns "422 Missing or misconfigured S2S Authorization Policy" when the policy is
  # scoped to a resource group, so source_resource_group_id is intentionally omitted here (account-level
  # scope only). See https://github.com/terraform-ibm-modules/terraform-ibm-icd-postgresql/issues/885
  roles       = ["Reader", "Authorization Delegator"] # Authorization Delegator role required for backup encryption key
  description = "Allow all Elasticsearch instances in the account ${local.account_id} to read the ${local.kms_service} key ${local.kms_key_id} from the instance GUID ${local.kms_instance_guid}"
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = local.kms_service
  }
  resource_attributes {
    name     = "accountId"
    operator = "stringEquals"
    value    = local.kms_account_id
  }
  resource_attributes {
    name     = "serviceInstance"
    operator = "stringEquals"
    value    = local.kms_instance_guid
  }
  resource_attributes {
    name     = "resourceType"
    operator = "stringEquals"
    value    = "key"
  }
  resource_attributes {
    name     = "resource"
    operator = "stringEquals"
    value    = local.kms_key_id
  }
  # Scope of policy now includes the key, so ensure to create new policy before
  # destroying old one to prevent any disruption to every day services.
  lifecycle {
    create_before_destroy = true
  }
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_authorization_policy" {
  count           = local.create_cross_account_kms_auth_policy ? 1 : 0
  depends_on      = [ibm_iam_authorization_policy.kms_policy]
  create_duration = "30s"
}

#######################################################################################################################
# Elasticsearch Gen2
#######################################################################################################################

# Look up existing instance details if user passes one
module "es_instance_crn_parser" {
  count   = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.existing_elasticsearch_instance_crn
}

# Existing instance local vars
locals {
  existing_elasticsearch_guid = var.existing_elasticsearch_instance_crn != null ? module.es_instance_crn_parser[0].service_instance : null
}

# Do a data lookup on the resource GUID to get more info that is needed for the 'ibm_database' data lookup below
data "ibm_resource_instance" "existing_instance_resource" {
  count      = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  identifier = local.existing_elasticsearch_guid
}

# Lookup details of existing instance
data "ibm_database" "existing_db_instance" {
  count             = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  name              = data.ibm_resource_instance.existing_instance_resource[0].name
  resource_group_id = data.ibm_resource_instance.existing_instance_resource[0].resource_group_id
  location          = data.ibm_resource_instance.existing_instance_resource[0].location
  service           = "databases-for-elasticsearch"
}

# Create new instance
module "elasticsearch" {
  count                                 = var.existing_elasticsearch_instance_crn != null ? 0 : 1
  source                                = "../.."
  depends_on                            = [time_sleep.wait_for_authorization_policy]
  resource_group_id                     = module.resource_group.resource_group_id
  name                                  = "${local.prefix}${var.name}"
  plan                                  = "enterprise-gen2" # this is the only gen2 plan for Elasticsearch
  region                                = var.region
  elasticsearch_version                 = var.elasticsearch_version
  skip_iam_authorization_policy         = var.skip_elasticsearch_kms_auth_policy
  skip_independent_backup_auth_policies = var.skip_independent_backup_auth_policies
  use_ibm_owned_encryption_key          = local.use_ibm_owned_encryption_key
  kms_key_crn                           = local.kms_key_crn
  backup_encryption_key_crn             = null  # not supported by gen2
  use_same_kms_key_for_backups          = false # not supported by gen2
  use_default_backup_encryption_key     = false # not supported by gen2
  access_tags                           = var.access_tags
  resource_tags                         = var.resource_tags
  admin_pass                            = null # not supported by gen2
  users                                 = []   # not supported by gen2
  members                               = var.members
  member_host_flavor                    = var.member_host_flavor
  memory_mb                             = var.member_memory_mb
  disk_mb                               = var.member_disk_mb
  cpu_count                             = var.member_cpu_count
  auto_scaling                          = null # not supported by gen2
  service_credential_names              = var.service_credential_names
  backup_crn                            = var.backup_crn
  service_endpoints                     = "private" # this is the only supported service endpoint for gen2
  deletion_protection                   = var.deletion_protection
  version_upgrade_skip_backup           = false
  create_timeout                        = var.create_timeout
  update_timeout                        = var.update_timeout
  delete_timeout                        = var.delete_timeout
}

locals {
  elasticsearch_guid     = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].guid : module.elasticsearch[0].guid
  elasticsearch_id       = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].id : module.elasticsearch[0].id
  elasticsearch_version  = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].version : module.elasticsearch[0].version
  elasticsearch_crn      = var.existing_elasticsearch_instance_crn != null ? var.existing_elasticsearch_instance_crn : module.elasticsearch[0].crn
  elasticsearch_hostname = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].hostname
  elasticsearch_port     = var.existing_elasticsearch_instance_crn != null ? null : module.elasticsearch[0].port
}

#######################################################################################################################
# Secrets management
#######################################################################################################################

locals {
  create_secrets_manager_auth_policy = var.skip_elasticsearch_to_secrets_manager_auth_policy || var.existing_secrets_manager_instance_crn == null ? 0 : 1
}

# Parse the Secrets Manager CRN
module "sm_instance_crn_parser" {
  count   = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.existing_secrets_manager_instance_crn
}

# create a service authorization between Secrets Manager and the target service (Elasticsearch)
resource "ibm_iam_authorization_policy" "secrets_manager_key_manager" {
  count                       = local.create_secrets_manager_auth_policy
  source_service_name         = "secrets-manager"
  source_resource_instance_id = local.existing_secrets_manager_instance_guid
  target_service_name         = "databases-for-elasticsearch"
  target_resource_instance_id = local.elasticsearch_guid
  roles                       = ["Key Manager"]
  description                 = "Allow Secrets Manager with instance id ${local.existing_secrets_manager_instance_guid} to manage key for the databases-for-elasticsearch instance"
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_elasticsearch_authorization_policy" {
  count           = local.create_secrets_manager_auth_policy
  depends_on      = [ibm_iam_authorization_policy.secrets_manager_key_manager]
  create_duration = "30s"
  triggers = {
    secrets_manager_region = local.existing_secrets_manager_instance_region
    secrets_manager_guid   = local.existing_secrets_manager_instance_guid
  }
}

locals {
  service_credential_secrets = [
    for service_credentials in var.service_credential_secrets : {
      secret_group_name        = service_credentials.secret_group_name
      secret_group_description = service_credentials.secret_group_description
      existing_secret_group    = service_credentials.existing_secret_group
      secrets = [
        for secret in service_credentials.service_credentials : {
          secret_name                                 = secret.secret_name
          secret_labels                               = secret.secret_labels
          secret_auto_rotation                        = secret.secret_auto_rotation
          secret_auto_rotation_unit                   = secret.secret_auto_rotation_unit
          secret_auto_rotation_interval               = secret.secret_auto_rotation_interval
          service_credentials_ttl                     = secret.service_credentials_ttl
          service_credential_secret_description       = secret.service_credential_secret_description
          service_credentials_source_service_role_crn = secret.service_credentials_source_service_role_crn
          service_credentials_source_service_crn      = local.elasticsearch_crn
          secret_type                                 = "service_credentials" #checkov:skip=CKV_SECRET_6
        }
      ]
    }
  ]

  secrets = local.service_credential_secrets # gen2 does not support admin_pass secret
  # Parse Secrets Manager details from the CRN
  existing_secrets_manager_instance_guid   = var.existing_secrets_manager_instance_crn != null ? module.sm_instance_crn_parser[0].service_instance : null
  existing_secrets_manager_instance_region = var.existing_secrets_manager_instance_crn != null ? module.sm_instance_crn_parser[0].region : null
}

module "secrets_manager_service_credentials" {
  count   = length(local.secrets) > 0 && var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/secrets-manager/ibm//modules/secrets"
  version = "2.15.14"
  # converted into implicit dependency and removed explicit depends_on time_sleep.wait_for_elasticsearch_authorization_policy for this module because of issue https://github.com/terraform-ibm-modules/terraform-ibm-icd-redis/issues/608
  existing_sm_instance_guid   = local.create_secrets_manager_auth_policy > 0 ? time_sleep.wait_for_elasticsearch_authorization_policy[0].triggers["secrets_manager_guid"] : local.existing_secrets_manager_instance_guid
  existing_sm_instance_region = local.create_secrets_manager_auth_policy > 0 ? time_sleep.wait_for_elasticsearch_authorization_policy[0].triggers["secrets_manager_region"] : local.existing_secrets_manager_instance_region
  endpoint_type               = var.existing_secrets_manager_endpoint_type
  secrets                     = local.secrets
}

########################################################################################################################
# Kibana Dashboard (Code Engine app, connected to Elasticsearch through Private Path)
########################################################################################################################

# Gen2 Elasticsearch instances are only reachable from inside a VPC, through a Virtual Private Endpoint (VPE)
# gateway. A Code Engine app cannot join a VPC, but it can reach one over a Code Engine Private Path connection
# (https://cloud.ibm.com/docs/codeengine?topic=codeengine-connectivity-outbound). So Kibana runs as a Code Engine app
# (which also gives it a publicly trusted certificate), and a dedicated VPC exposes the instance to it:
#   Code Engine app -> Private Path connection -> Private Path NLB -> ALB -> VPE gateway -> Elasticsearch
# A Private Path NLB cannot target a VPE gateway's IP directly, hence the ALB in between. Both load balancers only
# pass TCP through, so TLS runs end to end between Kibana and Elasticsearch.

# Gen2 has no native database users (the module's 'users' input is not supported), and every service
# credential is granted the same admin-equivalent role (ibm_admin_role) regardless of the IAM role picked.
# ibm_admin_role has allow_restricted_indices=false, so it can never create/manage the .kibana* system
# indices Kibana's own backend needs - every savedObjects migration attempt gets a silent 403 and retries
# forever (invisible at default log level, indistinguishable from a hang). Classic avoids this by creating
# a native user literally named "kibana_system", which Elasticsearch auto-grants its built-in, correctly
# scoped "kibana_system" role. Gen2 can't create that user via Terraform, but the reserved "kibana_system"
# ES user already exists on every cluster (just needs its password set) - so this Manager credential is
# used only to reset that reserved user's password when Kibana starts, and only that user's credentials are
# used by the Kibana process itself. It is also used as the human login to the Kibana web UI, since it is
# the only credential with password-reset access.
resource "ibm_resource_key" "kibana_credential" {
  count                = var.enable_kibana_dashboard ? 1 : 0
  name                 = "${local.prefix}kibana-credential"
  role                 = null
  resource_instance_id = local.elasticsearch_id
  parameters = {
    service-endpoints = "private"
    role_crn          = "crn:v1:bluemix:public:iam::::role:Manager"
  }
}

resource "random_password" "kibana_system_password" {
  count            = var.enable_kibana_dashboard ? 1 : 0
  length           = 32
  special          = true
  override_special = "#$%&*()-_=+[]{}<>:?"
  min_special      = 1
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
}

locals {
  kibana_username = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["username"] : null
  kibana_password = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["password"] : null
  # The 'ibm_database_connection' data source's typed schema (.https[]) is only ever populated for
  # classic instances and is null for Gen2 - the resource key's own nested 'connection.elasticsearch.*'
  # credential keys are the only reliable source of the hostname/port for a Gen2 instance.
  kibana_es_hostname = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["connection.elasticsearch.hosts.0.hostname"] : null
  kibana_es_port     = var.enable_kibana_dashboard ? tonumber(ibm_resource_key.kibana_credential[0].credentials["connection.elasticsearch.hosts.0.port"]) : null

  # Hostname of the Private Path endpoint that Code Engine resolves. The .internal top-level domain is exempt from
  # Private Path's domain ownership verification, so no DNS records are needed.
  kibana_private_path_endpoint = "es.${local.prefix}kibana.internal"
  kibana_scripts_dir           = "/kibana-scripts"
}

# Dedicated VPC for the VPE gateway and the two load balancers.
module "kibana_vpc" {
  count             = var.enable_kibana_dashboard ? 1 : 0
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "10.0.6"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = "${local.prefix}kibana"
  name              = "vpc"

  # Nothing in this VPC needs to reach the internet.
  use_public_gateways = {
    zone-1 = false
    zone-2 = false
    zone-3 = false
  }

  # The module's default ACL only allows internal (10.0.0.0/8) traffic. Connections from Code Engine arrive through
  # Private Path, so the Elasticsearch port is allowed from anywhere; NACLs are stateless, so its responses need
  # their own outbound rule. The VPC has no public gateway or floating IPs, so nothing is reachable from the internet.
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules = [
        {
          name        = "allow-es-inbound"
          action      = "allow"
          direction   = "inbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
          protocol    = "tcp"
          port_min    = local.kibana_es_port
          port_max    = local.kibana_es_port
        },
        {
          name            = "allow-es-outbound"
          action          = "allow"
          direction       = "outbound"
          source          = "0.0.0.0/0"
          destination     = "0.0.0.0/0"
          protocol        = "tcp"
          source_port_min = local.kibana_es_port
          source_port_max = local.kibana_es_port
        }
      ]
    }
  ]
}

# Shared by the VPE gateway and the ALB. A VPE gateway otherwise gets its own security group, which only allows
# inbound traffic from members of itself.
resource "ibm_is_security_group" "kibana_sg" {
  count          = var.enable_kibana_dashboard ? 1 : 0
  name           = "${local.prefix}kibana-sg"
  resource_group = module.resource_group.resource_group_id
  vpc            = module.kibana_vpc[0].vpc_id
}

resource "ibm_is_security_group_rule" "kibana_allow_es_inbound" {
  count     = var.enable_kibana_dashboard ? 1 : 0
  group     = ibm_is_security_group.kibana_sg[0].id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = local.kibana_es_port
  port_max  = local.kibana_es_port
}

resource "ibm_is_security_group_rule" "kibana_allow_all_outbound" {
  count     = var.enable_kibana_dashboard ? 1 : 0
  group     = ibm_is_security_group.kibana_sg[0].id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_virtual_endpoint_gateway" "kibana_es_vpe" {
  count = var.enable_kibana_dashboard ? 1 : 0
  name  = "${local.prefix}kibana-es-vpe"
  target {
    crn           = local.elasticsearch_crn
    resource_type = "provider_cloud_service"
  }
  vpc             = module.kibana_vpc[0].vpc_id
  resource_group  = module.resource_group.resource_group_id
  security_groups = [ibm_is_security_group.kibana_sg[0].id]

  ips {
    subnet = module.kibana_vpc[0].subnet_zone_list[0].id
    name   = "${local.prefix}kibana-es-vpe-ip"
  }
}

# Passes TCP through to the VPE gateway's IP, for the Private Path NLB to target.
resource "ibm_is_lb" "kibana_alb" {
  count           = var.enable_kibana_dashboard ? 1 : 0
  name            = "${local.prefix}kibana-alb"
  type            = "private"
  subnets         = [module.kibana_vpc[0].subnet_zone_list[0].id]
  security_groups = [ibm_is_security_group.kibana_sg[0].id]
  resource_group  = module.resource_group.resource_group_id
}

resource "ibm_is_lb_pool" "kibana_alb_pool" {
  count          = var.enable_kibana_dashboard ? 1 : 0
  name           = "${local.prefix}kibana-alb-pool"
  lb             = ibm_is_lb.kibana_alb[0].id
  algorithm      = "round_robin"
  protocol       = "tcp"
  health_type    = "tcp"
  health_delay   = 10
  health_retries = 2
  health_timeout = 5
}

resource "ibm_is_lb_pool_member" "kibana_alb_pool_member" {
  count          = var.enable_kibana_dashboard ? 1 : 0
  lb             = ibm_is_lb.kibana_alb[0].id
  pool           = ibm_is_lb_pool.kibana_alb_pool[0].pool_id
  port           = local.kibana_es_port
  target_address = ibm_is_virtual_endpoint_gateway.kibana_es_vpe[0].ips[0].address
}

resource "ibm_is_lb_listener" "kibana_alb_listener" {
  count        = var.enable_kibana_dashboard ? 1 : 0
  lb           = ibm_is_lb.kibana_alb[0].id
  port         = local.kibana_es_port
  protocol     = "tcp"
  default_pool = ibm_is_lb_pool.kibana_alb_pool[0].pool_id
}

# Connection requests are reviewed by default, and only the request from this deployment's Code Engine project is
# permitted (see ibm_is_private_path_service_gateway_endpoint_gateway_binding_operations below). Publishing is needed
# because Code Engine connects from its own account.
module "kibana_private_path" {
  count                              = var.enable_kibana_dashboard ? 1 : 0
  depends_on                         = [ibm_is_lb_listener.kibana_alb_listener, ibm_is_lb_pool_member.kibana_alb_pool_member]
  source                             = "terraform-ibm-modules/vpc-private-path/ibm"
  version                            = "1.10.2"
  resource_group_id                  = module.resource_group.resource_group_id
  subnet_id                          = module.kibana_vpc[0].subnet_zone_list[0].id
  nlb_name                           = "${local.prefix}kibana-pp-nlb"
  private_path_name                  = "${local.prefix}kibana-pp"
  private_path_service_endpoints     = [local.kibana_private_path_endpoint]
  private_path_default_access_policy = "review"
  private_path_publish               = true
  nlb_backend_pools = [{
    pool_name                                = "${local.prefix}kibana-pp-pool"
    pool_health_delay                        = 10
    pool_health_timeout                      = 5
    pool_health_type                         = "tcp"
    pool_health_monitor_port                 = local.kibana_es_port
    pool_member_port                         = local.kibana_es_port
    pool_member_application_load_balancer_id = ibm_is_lb.kibana_alb[0].id
    listener_port                            = local.kibana_es_port
  }]
}

module "kibana_code_engine_project" {
  count             = var.enable_kibana_dashboard ? 1 : 0
  source            = "terraform-ibm-modules/code-engine/ibm//modules/project"
  version           = "4.9.17"
  name              = "${local.prefix}kibana"
  resource_group_id = module.resource_group.resource_group_id
}

# Code Engine removes the VPE gateway behind its Private Path connection asynchronously, and the Private Path service
# cannot be deleted while that VPE gateway is still bound to it (409 "in use").
resource "time_sleep" "wait_for_kibana_private_path_release" {
  count            = var.enable_kibana_dashboard ? 1 : 0
  depends_on       = [module.kibana_private_path]
  destroy_duration = "120s"
}

resource "ibm_code_engine_allowed_outbound_destination" "kibana_private_path" {
  count                            = var.enable_kibana_dashboard ? 1 : 0
  depends_on                       = [time_sleep.wait_for_kibana_private_path_release]
  project_id                       = module.kibana_code_engine_project[0].project_id
  name                             = "${local.prefix}kibana-es"
  type                             = "private_path_service_gateway"
  private_path_service_gateway_crn = module.kibana_private_path[0].private_path_crn
  isolation_policy                 = "dedicated"
}

# Creating the Code Engine Private Path connection only completes once its connection request (an endpoint gateway
# binding) is permitted. So the request is looked up and permitted in parallel with that creation, rather than after
# it: this wait starts at the same time, giving Code Engine time to send the request.
resource "time_sleep" "wait_for_kibana_private_path_request" {
  count           = var.enable_kibana_dashboard ? 1 : 0
  depends_on      = [time_sleep.wait_for_kibana_private_path_release]
  create_duration = "120s"
}

# The Code Engine project's connection is the only one expected on this dedicated Private Path service.
data "ibm_is_private_path_service_gateway_endpoint_gateway_bindings" "kibana_private_path" {
  count                        = var.enable_kibana_dashboard ? 1 : 0
  depends_on                   = [time_sleep.wait_for_kibana_private_path_request]
  private_path_service_gateway = module.kibana_private_path[0].private_path_id
}

locals {
  kibana_private_path_bindings = var.enable_kibana_dashboard ? data.ibm_is_private_path_service_gateway_endpoint_gateway_bindings.kibana_private_path[0].endpoint_gateway_bindings : []
  # The pending request is the one to permit. Once permitted, any binding is fine to reference: the value is ignored
  # after creation (see ignore_changes below).
  kibana_private_path_binding_id = try(
    [for binding in local.kibana_private_path_bindings : binding.id if binding.status == "pending"][0],
    local.kibana_private_path_bindings[0].id,
    null
  )
}

resource "ibm_is_private_path_service_gateway_endpoint_gateway_binding_operations" "kibana_private_path" {
  count                        = var.enable_kibana_dashboard ? 1 : 0
  private_path_service_gateway = module.kibana_private_path[0].private_path_id
  endpoint_gateway_binding     = local.kibana_private_path_binding_id
  access_policy                = "permit"
  lifecycle {
    # The binding list is read again on every plan; only the first approval matters.
    ignore_changes = [endpoint_gateway_binding]
    precondition {
      condition     = local.kibana_private_path_binding_id != null
      error_message = "No connection request from the Kibana Code Engine project was found on the Kibana Private Path service. Apply again to retry."
    }
  }
}

module "kibana_code_engine_scripts" {
  count      = var.enable_kibana_dashboard ? 1 : 0
  source     = "terraform-ibm-modules/code-engine/ibm//modules/config_map"
  version    = "4.9.17"
  project_id = module.kibana_code_engine_project[0].project_id
  name       = "${local.prefix}kibana-scripts"
  data = {
    "kibana-start.sh"    = file("${path.module}/scripts/kibana-start.sh")
    "es-dns-override.js" = file("${path.module}/scripts/es-dns-override.js")
  }
}

module "kibana_code_engine_secret" {
  count      = var.enable_kibana_dashboard ? 1 : 0
  source     = "terraform-ibm-modules/code-engine/ibm//modules/secret"
  version    = "4.9.17"
  project_id = module.kibana_code_engine_project[0].project_id
  name       = "${local.prefix}kibana-es-credentials"
  format     = "generic"
  data = {
    ES_ADMIN_USERNAME      = local.kibana_username
    ES_ADMIN_PASSWORD      = local.kibana_password
    ELASTICSEARCH_PASSWORD = random_password.kibana_system_password[0].result
  }
}

locals {
  kibana_secret_env = [for key in ["ES_ADMIN_USERNAME", "ES_ADMIN_PASSWORD", "ELASTICSEARCH_PASSWORD"] : {
    type      = "secret_key_reference"
    name      = key
    key       = key
    reference = var.enable_kibana_dashboard ? module.kibana_code_engine_secret[0].name : null
  }]
}

module "kibana_code_engine_app" {
  count = var.enable_kibana_dashboard ? 1 : 0
  depends_on = [
    ibm_code_engine_allowed_outbound_destination.kibana_private_path,
    ibm_is_private_path_service_gateway_endpoint_gateway_binding_operations.kibana_private_path,
    module.kibana_code_engine_scripts,
  ]
  source          = "terraform-ibm-modules/code-engine/ibm//modules/app"
  version         = "4.9.17"
  project_id      = module.kibana_code_engine_project[0].project_id
  name            = "${local.prefix}kibana"
  image_reference = var.kibana_image_digest != null ? "${var.kibana_image}@${var.kibana_image_digest}" : "${var.kibana_image}:${var.kibana_version}"
  image_port      = 5601
  run_commands    = ["/bin/bash", "${local.kibana_scripts_dir}/kibana-start.sh"]
  run_volume_mounts = [{
    mount_path = local.kibana_scripts_dir
    reference  = module.kibana_code_engine_scripts[0].name
    type       = "config_map"
  }]
  run_env_variables = concat(local.kibana_secret_env, [
    for name, value in {
      ES_HOSTNAME           = local.kibana_es_hostname
      ES_PORT               = tostring(local.kibana_es_port)
      PRIVATE_PATH_ENDPOINT = local.kibana_private_path_endpoint
      KIBANA_SCRIPTS_DIR    = local.kibana_scripts_dir
      # Code Engine doesn't restart an app when a mounted config map changes, so this rolls out script changes.
      KIBANA_SCRIPTS_HASH = sha256(join("", values(module.kibana_code_engine_scripts[0].data)))
      SERVER_HOST         = "0.0.0.0"
      } : {
      type  = "literal"
      name  = name
      value = value
    }
  ])
  # A single instance: Kibana sessions are not shared between instances without a common encryption key.
  scale_min_instances     = 1
  scale_max_instances     = 1
  scale_cpu_limit         = "1"
  scale_memory_limit      = "4G"
  managed_domain_mappings = var.kibana_visibility
}
