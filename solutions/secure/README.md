# IBM Elastic Search on IBM Cloud

This architecture creates an IBM Elastic Search instance in IBM Cloud environment and supports provisioning the following resources:

- A resource group, if one is not passed in.
- An IBM Elastic search instance on IBM Cloud
- Creation of CBR rules
- Supports autoscaling

![fscloud-elastic-search](https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/reference-architecture/da-elasticsearch.svg)

NB: This solution is not intended to be called by one or more other modules since it contains a provider configurations, meaning it is not compatible with the for_each, count, and depends_on arguments. For more information see ![Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
