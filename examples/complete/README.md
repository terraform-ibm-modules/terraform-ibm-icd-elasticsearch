# Complete example with autoscaling, BYOK encryption, service credentials creation, index creation and updates to cluster-wide settings

An end-to-end example that provisions the following infrastructure:

- A resource group, if one is not passed in.
- A Key Protect instance with a root key.
- An instance of Databases for Elasticsearch with BYOK encryption and autoscaling.
- A Secrets Manager instance if one is not passed in.
- Service credentials for the database instance.
- A Secrets Manager secret containing the service credentials.
- An Elasticsearch index
- Updates to the cluster-wide settings
