provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

# On Gen2 the elasticsearch provider is never used (its resources are skipped in this example), so this
# config is otherwise inert. Gen2 credentials use Manager/Writer roles instead of the classic 'admin' user,
# so the 'elasticsearch_manager' credential is used as the closest equivalent. Gen2 has no TLS certificate,
# so cacert_file falls back to an empty string.
provider "elasticsearch" {
  username    = try(module.database.service_credentials_object.credentials[local.is_gen2 ? "elasticsearch_manager" : "elasticsearch_admin"].username, "")
  password    = try(module.database.service_credentials_object.credentials[local.is_gen2 ? "elasticsearch_manager" : "elasticsearch_admin"].password, "")
  url         = try("https://${module.database.service_credentials_object.hostname}:${module.database.service_credentials_object.port}", "")
  cacert_file = try(base64decode(module.database.service_credentials_object.certificate), "")
}
