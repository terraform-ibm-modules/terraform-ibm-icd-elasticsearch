# Financial Services Cloud profile example with autoscaling enabled

An end-to-end example that uses the [Profile for IBM Cloud Framework for Financial Services](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/modules/fscloud) to deploy an instance of IBM Cloud Databases for Elasticsearch.

The example uses the IBM Cloud Terraform provider to create the following infrastructure:

- A resource group, if one is not passed in.
- An IAM authorization between all Elasticsearch database instances in the given resource group, and the Hyper Protect Crypto Services instance that is passed in.
- An IBM Cloud Databases Elasticsearch database instance that is encrypted with the Hyper Protect Crypto Services root key that is passed in.
- Autoscaling rules for the IBM Cloud Databases Elasticsearch database instance.
- Service Credentials for the Elasticsearch database instance.
- A sample virtual private cloud (VPC).
- A context-based restriction (CBR) rule to only allow Elasticsearch to be accessible from within the VPC.

:exclamation: **Important:** In this example, only the IBM Cloud Databases for Elasticsearch instance complies with the IBM Cloud Framework for Financial Services. Other parts of the infrastructure do not necessarily comply.

## Before you begin

- You need a Hyper Protect Crypto Services instance and root key available in the region that you want to deploy your Elasticsearch database instance to.
