# IBM Cloud Databases for Elasticsearch

This architecture creates an Elasticsearch instance on IBM Cloud and supports provisioning of the following resources:

- A resource group, if one is not passed in.
- An Elasticsearch instance on IBM Cloud with KMS encryption.
- Autoscaling rules for the Elasticsearch instance, if provided.

![fscloud-elastic-search](../../reference-architecture/deployable-architecture-elasticsearch.svg)

This solution is not intended to be called by one or more other modules since it contains a provider configurations, meaning it is not compatible with the for_each, count, and depends_on arguments. For more information see ![Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
