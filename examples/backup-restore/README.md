# Restore from backup example

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<p>
  <a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=icd-elasticsearch-backup-restore-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/examples/backup-restore">
    <img src="https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics">
  </a><br>
  ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
</p>
<!-- END SCHEMATICS DEPLOY HOOK -->

This example provides an end-to-end executable flow of how an Elasticsearch DB instance can be restored from a backup. It supports both classic and Gen2 plans. This example uses the IBM Cloud Terraform provider to:

- Create a new resource group if one is not passed in.
- Look up the latest available backup of an existing Elasticsearch instance using the `ibm_database_backups` data source.
- Create a restored ICD Elasticsearch database instance from that backup.

## Classic restore

Set `plan` to a classic plan (e.g. `enterprise`) and provide the CRN of an existing **classic** Elasticsearch instance via `existing_database_crn`. The `member_host_flavor` is automatically set to `multitenant`.

## Gen2 restore

Set `plan` to a Gen2 plan (e.g. `enterprise-gen2`) and provide the CRN of an existing **Gen2** Elasticsearch instance via `existing_database_crn`. The `member_host_flavor` is automatically set to `bx3d.4x20` and `service_endpoints` to `private`.

The `ibm_database_backups` data source returns backups for the given deployment. For Gen2 instances, the backup CRN is in the `databases-independent-backups` format:

```
crn:v1:bluemix:public:databases-independent-backups:<region>:a/<account-id>:<backup-id>::
```

For classic instances, the backup CRN is in the legacy format:

```
crn:v1:bluemix:public:databases-for-elasticsearch:<region>:a/<account-id>:<instance-id>:backup:<backup-id>
```
