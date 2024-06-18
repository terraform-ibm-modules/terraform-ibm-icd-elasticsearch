provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "restapi" {
  uri = "https:"
  headers = {
    authorization  = var.ibmcloud_api_key
    "Content-Type" = "application/json"
  }
  write_returns_object = true
}
