provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

# The try() fallbacks are needed for Gen2 instances, where the 'elasticsearch_admin' credential does not
# exist and the service credentials do not expose the connection details. The provider is never used in
# that case because the elasticsearch_* resources in this example are skipped for Gen2.
provider "elasticsearch" {
  username    = try(module.database.service_credentials_object.credentials["elasticsearch_admin"].username, "")
  password    = try(module.database.service_credentials_object.credentials["elasticsearch_admin"].password, "")
  url         = try("https://${module.database.service_credentials_object.hostname}:${module.database.service_credentials_object.port}", "https://localhost:9200")
  cacert_file = try(base64decode(module.database.service_credentials_object.certificate), "")
}
