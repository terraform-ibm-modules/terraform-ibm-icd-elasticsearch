terraform {
  required_version = ">= 1.3.0, <1.7.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.62.0"
    }
  } # Lock DA into an exact provider version - renovate automation will keep it updated
}