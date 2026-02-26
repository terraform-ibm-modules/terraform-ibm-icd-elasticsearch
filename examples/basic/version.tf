terraform {
  required_version = ">= 1.9.0"
  required_providers {
    # Use latest version of provider in non-basic examples to verify latest version works with module
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.79.2"
    }
    # The elasticsearch provider is not actually required by the module itself, just this example, so OK to use ">=" here instead of locking into a version
    elasticsearch = {
      source  = "phillbaker/elasticsearch"
      version = ">= 2.0.7"
    }
    # The time provider is not actually required by the module itself, just this example, so OK to use ">=" here instead of locking into a version
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}
