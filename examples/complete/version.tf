terraform {
  required_version = ">= 1.9.0"
  # Pin to the lowest provider version of the range defined in the main module's version.tf to ensure lowest version still works
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">=1.70.0, <2.0.0"
    }
  }
}
