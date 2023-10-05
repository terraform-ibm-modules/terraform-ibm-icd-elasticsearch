terraform {
  required_version = "<= 1.5.5"
  # Use "greater than or equal to" range in modules
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = ">= 1.56.1, < 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}
