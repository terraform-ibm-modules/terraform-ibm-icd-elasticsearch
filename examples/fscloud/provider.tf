provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "restapi" {
  uri = "https:"
  headers = {
    Accept        = "application/json"
    Content-Type = "application/json"
  }
  write_returns_object = true
  create_returns_object = false
  insecure = true
}
