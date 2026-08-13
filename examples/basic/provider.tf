provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

# On Gen2 the elasticsearch provider is never used (its resources are skipped in this example). The try()
# fallbacks keep the provider config valid on that path: Gen2 has no 'elasticsearch_admin' credential (it
# uses Manager/Writer roles) and no TLS certificate, so those references would otherwise error.
provider "elasticsearch" {
  username    = try(module.database.service_credentials_object.credentials["elasticsearch_admin"].username, "")
  password    = try(module.database.service_credentials_object.credentials["elasticsearch_admin"].password, "")
  url         = try("https://${module.database.service_credentials_object.hostname}:${module.database.service_credentials_object.port}", "")
  cacert_file = try(base64decode(module.database.service_credentials_object.certificate), "")
}
