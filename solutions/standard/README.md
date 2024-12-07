# IBM Cloud Databases for Elasticsearch

This architecture creates an instance of IBM Cloud Databases for Elasticsearch and supports provisioning of the following resources:

- A resource group, if one is not passed in.
- A KMS root key, if one is not passed in.
- An IBM Cloud Databases for Elasticsearch instance with KMS encryption.
- Autoscaling rules for the database instance, if provided.
- Kibana dashboard for Elasticsearch.

**Note on accessing Kibana:** If Kibana is enabled, you can access the Kibana application over a IBM private network using one of the methods outlined [here](https://cloud.ibm.com/docs/private-connectivity?topic=private-connectivity-connect-privately-ibm-cloud).

**Note on setting kibana_visibility:** When the Kibana application visibility is changed from private to public using kibana_visibility variable, it will become accessible from the public Internet. However, access via the IBM Cloud private network will no longer be available. This change takes effect immediately, potentially impacting active users or integrations. It is important to consider the associated security implications before proceeding.

![fscloud-elastic-search](../../reference-architecture/deployable-architecture-elasticsearch.svg)

:exclamation: **Important:** This solution is not intended to be called by other modules because it contains a provider configuration and is not compatible with the `for_each`, `count`, and `depends_on` arguments. For more information, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
