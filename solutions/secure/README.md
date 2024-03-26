# IBM Cloud Databases for Elasticsearch

This architecture creates an IBM Elasticsearch instance in IBM Cloud environment and supports provisioning the following resources:

- A Resource Group, if one is not passed in.
- An IBM Elasticsearch instance on IBM Cloud
- Creation of CBR rules
- Supports KMS encryption
- Supports autoscaling

![fscloud-elastic-search](../../reference-architecture/deployable-architecture-elasticsearch.svg)

This solution is not intended to be called by one or more other modules since it contains a provider configurations, meaning it is not compatible with the for_each, count, and depends_on arguments. For more information see ![Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
