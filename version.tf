terraform {
  required_version = ">= 1.3.0"
  # Use "greater than or equal to" range in modules
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = ">= 1.70.0, <2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1, < 4.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}
