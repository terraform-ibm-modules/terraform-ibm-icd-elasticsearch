provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "restapi" {
  uri = "https:"
  headers = {
    "Content-Type" = "application/json"
  }
  write_returns_object = true
}
