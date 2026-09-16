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
  location          = var.region
  service           = "databases-for-elasticsearch"
}

# Lookup existing instance connection details
data "ibm_database_connection" "existing_connection" {
  count         = var.existing_elasticsearch_instance_crn != null ? 1 : 0
  endpoint_type = "private"
  deployment_id = data.ibm_database.existing_db_instance[0].id
  user_id       = data.ibm_database.existing_db_instance[0].adminuser
  user_type     = "database"
}

# Create new instance
module "elasticsearch" {
  count                             = var.existing_elasticsearch_instance_crn != null ? 0 : 1
  source                            = "../.."
  depends_on                        = [time_sleep.wait_for_authorization_policy]
  resource_group_id                 = module.resource_group.resource_group_id
  name                              = "${local.prefix}${var.name}"
  plan                              = "enterprise-gen2" # this is the only gen2 plan for Elasticsearch
  region                            = var.region
  elasticsearch_version             = var.elasticsearch_version
  skip_iam_authorization_policy     = var.skip_elasticsearch_kms_auth_policy
  use_ibm_owned_encryption_key      = local.use_ibm_owned_encryption_key
  kms_key_crn                       = local.kms_key_crn
  backup_encryption_key_crn         = null  # not supported by gen2
  use_same_kms_key_for_backups      = false # not supported by gen2
  use_default_backup_encryption_key = false # not supported by gen2
  access_tags                       = var.access_tags
  resource_tags                     = var.resource_tags
  admin_pass                        = null # not supported by gen2
  users                             = []   # not supported by gen2
  members                           = var.members
  member_host_flavor                = var.member_host_flavor
  memory_mb                         = var.member_memory_mb
  disk_mb                           = var.member_disk_mb
  cpu_count                         = var.member_cpu_count
  auto_scaling                      = null # not supported by gen2
  service_credential_names          = var.service_credential_names
  backup_crn                        = null      # not supported by gen2
  service_endpoints                 = "private" # this is the only supported service endpoint for gen2
  deletion_protection               = var.deletion_protection
  version_upgrade_skip_backup       = false
  create_timeout                    = var.create_timeout
  update_timeout                    = var.update_timeout
  delete_timeout                    = var.delete_timeout
}

locals {
  elasticsearch_guid     = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].guid : module.elasticsearch[0].guid
  elasticsearch_id       = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].id : module.elasticsearch[0].id
  elasticsearch_version  = var.existing_elasticsearch_instance_crn != null ? data.ibm_database.existing_db_instance[0].version : module.elasticsearch[0].version
  elasticsearch_crn      = var.existing_elasticsearch_instance_crn != null ? var.existing_elasticsearch_instance_crn : module.elasticsearch[0].crn
  elasticsearch_hostname = var.existing_elasticsearch_instance_crn != null ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].hostname : module.elasticsearch[0].hostname
  elasticsearch_port     = var.existing_elasticsearch_instance_crn != null ? data.ibm_database_connection.existing_connection[0].https[0].hosts[0].port : module.elasticsearch[0].port
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
# Kibana Dashboard (VSI in a dedicated VPC, connected to Elasticsearch via a Virtual Private Endpoint)
########################################################################################################################

# Gen2 Elasticsearch instances are only reachable from inside a VPC that has a Virtual Private Endpoint
# (VPE) gateway targeting them - this is IBM's own documented pattern for Gen2 private connectivity
# ("VPE via VSI": https://cloud.ibm.com/docs/cloud-databases-gen2?topic=cloud-databases-gen2-private-connections).
# Code Engine (used by the classic DA's Kibana feature) has no way to join a VPC, so Kibana instead runs
# on a small VSI inside a dedicated VPC alongside the VPE.

# Gen2 has no native database users (the module's 'users' input is not supported), and every service
# credential is granted the same admin-equivalent role (ibm_admin_role) regardless of the IAM role picked -
# so a single dedicated Manager-role credential is used both as Kibana's backend authentication and as the
# human login to the Kibana web UI.
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

locals {
  kibana_username = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["username"] : null
  kibana_password = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["password"] : null
  # The 'ibm_database_connection' data source's typed schema (.https[]) is only ever populated for
  # classic instances and is null for Gen2 - the resource key's own nested 'connection.elasticsearch.*'
  # credential keys are the only reliable source of the hostname/port for a Gen2 instance.
  kibana_es_hostname = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["connection.elasticsearch.hosts.0.hostname"] : null
  kibana_es_port     = var.enable_kibana_dashboard ? ibm_resource_key.kibana_credential[0].credentials["connection.elasticsearch.hosts.0.port"] : null
}

# Dedicated VPC for the Kibana VSI and its VPE gateway to Elasticsearch.
module "kibana_vpc" {
  count             = var.enable_kibana_dashboard ? 1 : 0
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "10.0.6"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = "${local.prefix}kibana"
  name              = "vpc"

  # The module's default ACL only allows internal (10.0.0.0/8) traffic. Kibana needs inbound access from
  # outside the VPC, and NACLs are stateless, so an outbound-initiated connection's return leg (e.g.
  # pulling the Kibana image from the public internet) also needs its own explicit inbound allow.
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules = [
        {
          name        = "allow-ssh-inbound"
          action      = "allow"
          direction   = "inbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
          protocol    = "tcp"
          port_min    = 22
          port_max    = 22
        },
        {
          name        = "allow-kibana-inbound"
          action      = "allow"
          direction   = "inbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
          protocol    = "tcp"
          port_min    = 5601
          port_max    = 5601
        },
        {
          name        = "allow-return-traffic-inbound"
          action      = "allow"
          direction   = "inbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
          protocol    = "tcp"
          port_min    = 1024
          port_max    = 65535
        },
        {
          name        = "allow-all-outbound"
          action      = "allow"
          direction   = "outbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
        }
      ]
    }
  ]
}

# Managed directly (rather than through the VSI module's own security_group input) so the VPE gateway and
# the "allow ES traffic from members of this group" rule can both reference its ID without a circular
# dependency - the VPE gateway has its own security group by default, separate from the VSI's, which only
# allows inbound from members of itself.
resource "ibm_is_security_group" "kibana_sg" {
  count          = var.enable_kibana_dashboard ? 1 : 0
  name           = "${local.prefix}kibana-sg"
  resource_group = module.resource_group.resource_group_id
  vpc            = module.kibana_vpc[0].vpc_id
}

resource "ibm_is_security_group_rule" "kibana_allow_ssh_inbound" {
  count     = var.enable_kibana_dashboard ? 1 : 0
  group     = ibm_is_security_group.kibana_sg[0].id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}

resource "ibm_is_security_group_rule" "kibana_allow_kibana_inbound" {
  count     = var.enable_kibana_dashboard ? 1 : 0
  group     = ibm_is_security_group.kibana_sg[0].id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = 5601
  port_max  = 5601
}

resource "ibm_is_security_group_rule" "kibana_allow_es_inbound" {
  count     = var.enable_kibana_dashboard ? 1 : 0
  group     = ibm_is_security_group.kibana_sg[0].id
  direction = "inbound"
  remote    = ibm_is_security_group.kibana_sg[0].id
  protocol  = "tcp"
  port_min  = 9200
  port_max  = 9200
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

# SSH access is used for operational troubleshooting of the Kibana VSI (checking container logs,
# restarting the service) - an existing key can be supplied, otherwise one is generated and surfaced as a
# sensitive output.
resource "tls_private_key" "kibana_ssh_key" {
  count     = var.enable_kibana_dashboard && var.kibana_existing_ssh_key_name == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "kibana_ssh_key" {
  count          = var.enable_kibana_dashboard && var.kibana_existing_ssh_key_name == null ? 1 : 0
  name           = "${local.prefix}kibana-ssh-key"
  public_key     = tls_private_key.kibana_ssh_key[0].public_key_openssh
  resource_group = module.resource_group.resource_group_id
}

data "ibm_is_ssh_key" "kibana_existing_ssh_key" {
  count = var.enable_kibana_dashboard && var.kibana_existing_ssh_key_name != null ? 1 : 0
  name  = var.kibana_existing_ssh_key_name
}

locals {
  kibana_ssh_key_id = var.enable_kibana_dashboard ? (
    var.kibana_existing_ssh_key_name != null ? data.ibm_is_ssh_key.kibana_existing_ssh_key[0].id : ibm_is_ssh_key.kibana_ssh_key[0].id
  ) : null
}

module "kibana_vsi_image" {
  count            = var.enable_kibana_dashboard ? 1 : 0
  source           = "terraform-ibm-modules/common-utilities/ibm//modules/vsi-image-selector"
  version          = "1.9.0"
  architecture     = "amd64"
  operating_system = "ubuntu"
}

locals {
  kibana_es_url = var.enable_kibana_dashboard ? "https://${local.kibana_es_hostname}:${local.kibana_es_port}" : null

  # Elastic only publishes full patch-version image tags (e.g. "8.19.11"), but Gen2's reported 'version'
  # is just the requested value - for the common case that's this module's own hardcoded "8.0" default,
  # which isn't a real tag at all. So unless a digest is pinned, the VSI looks up the real running
  # version live from the Elasticsearch API at boot (same approach the classic DA takes with its
  # es_metadata.sh, minus the certificate - Gen2 doesn't expose one).
  kibana_docker_run_cmd = var.enable_kibana_dashboard ? join(" ", [
    "ES_VERSION=$(curl -s -k -u '${local.kibana_username}:${local.kibana_password}' '${local.kibana_es_url}/' | jq -r '.version.number') ;",
    "docker run -d --name kibana --restart unless-stopped -p 5601:5601",
    "-e ELASTICSEARCH_HOSTS='${local.kibana_es_url}'",
    "-e ELASTICSEARCH_USERNAME='${local.kibana_username}'",
    "-e ELASTICSEARCH_PASSWORD='${local.kibana_password}'",
    "-e ELASTICSEARCH_SSL_VERIFICATIONMODE=none",
    "-e SERVER_HOST=0.0.0.0",
    var.kibana_image_digest != null ? "${var.kibana_image}@${var.kibana_image_digest}" : "${var.kibana_image}:$ES_VERSION",
  ]) : null

  # landing-zone-vsi only auto-prepends '#cloud-config' when install_logging_agent/install_monitoring_agent
  # is true; since neither is used here, it must be added explicitly or cloud-init ignores the user data.
  kibana_user_data = var.enable_kibana_dashboard ? "#cloud-config\n${yamlencode({
    runcmd = [
      "apt-get update -y",
      "apt-get install -y docker.io jq",
      "systemctl enable docker",
      "systemctl start docker",
      local.kibana_docker_run_cmd,
    ]
  })}" : null
}

module "kibana_vsi" {
  count                 = var.enable_kibana_dashboard ? 1 : 0
  source                = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version               = "6.6.2"
  resource_group_id     = module.resource_group.resource_group_id
  image_id              = module.kibana_vsi_image[0].latest_image_id
  create_security_group = false
  security_group_ids    = [ibm_is_security_group.kibana_sg[0].id]
  subnets               = [module.kibana_vpc[0].subnet_zone_list[0]]
  vpc_id                = module.kibana_vpc[0].vpc_id
  prefix                = "${local.prefix}kibana"
  machine_type          = var.kibana_vsi_profile
  user_data             = local.kibana_user_data
  vsi_per_subnet        = 1
  enable_floating_ip    = var.kibana_public_endpoint
  ssh_key_ids           = [local.kibana_ssh_key_id]
}
