provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "elasticsearch" {
  username    = module.database.service_credentials_object.credentials["elasticsearch_admin"].username
  password    = module.database.service_credentials_object.credentials["elasticsearch_admin"].password
  url         = "https://${module.database.service_credentials_object.hostname}:${module.database.service_credentials_object.port}"
  cacert_file = base64decode(module.database.service_credentials_object.certificate)
}
