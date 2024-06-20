terraform {
  required_version = ">= 1.3.0"
  # Use "greater than or equal to" range in modules
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = ">= 1.62.0, <2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1, <1.0.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 1.19.1, <2.0.0"
    }
  }
}
