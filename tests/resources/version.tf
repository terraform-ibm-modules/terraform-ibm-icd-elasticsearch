terraform {
  required_version = ">= 1.3.0"
  required_providers {
    # Pin to the lowest provider version of the range defined in the main module's version.tf to ensure lowest version still works
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.70.0"
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
