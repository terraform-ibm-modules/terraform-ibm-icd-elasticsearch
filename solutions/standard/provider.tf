provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  visibility       = var.provider_visibility
}

provider "ibm" {
  alias            = "kms"
  ibmcloud_api_key = var.ibmcloud_kms_api_key != null ? var.ibmcloud_kms_api_key : var.ibmcloud_api_key
  region           = local.kms_region
  visibility       = var.provider_visibility
}

data "ibm_iam_auth_token" "auth_token" {}
provider "restapi" {
  uri = "https://api.${var.region}.private.databases.cloud.ibm.com"
  headers = {
    Authorization = data.ibm_iam_auth_token.auth_token.iam_access_token
    Content-Type  = "application/json"
  }
  write_returns_object = true
}
