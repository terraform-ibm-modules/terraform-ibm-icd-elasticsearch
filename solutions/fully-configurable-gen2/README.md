# IBM Cloud Databases Gen 2 (VPC) for Elasticsearch

This deployable architecture provides a fully configurable solution for IBM Cloud Databases Gen 2 (VPC) for Elasticsearch. For more information about Gen 2, see [Databases for Elasticsearch Gen 2](https://cloud.ibm.com/docs/databases-for-elasticsearch-gen2).

:exclamation: **Important:** This solution is not intended to be called by other modules because it contains a provider configuration and is not compatible with the `for_each`, `count`, and `depends_on` arguments. For more information, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
