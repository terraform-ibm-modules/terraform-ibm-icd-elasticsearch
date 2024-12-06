# IBM Cloud Databases for Elasticsearch

This architecture creates an instance of IBM Cloud Databases for Elasticsearch and supports provisioning of the following resources:

- A resource group, if one is not passed in.
- A KMS root key, if one is not passed in.
- An IBM Cloud Databases for Elasticsearch instance with KMS encryption.
- Autoscaling rules for the database instance, if provided.
- Kibana dashboard for Elasticsearch.

**Note:** If Kibana is enabled, accessing Kibana application over private network can be achieved using one of following ways mentioned here: https://cloud.ibm.com/docs/private-connectivity?topic=private-connectivity-connect-privately-ibm-cloud

![fscloud-elastic-search](../../reference-architecture/deployable-architecture-elasticsearch.svg)

:exclamation: **Important:** This solution is not intended to be called by other modules because it contains a provider configuration and is not compatible with the `for_each`, `count`, and `depends_on` arguments. For more information, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
