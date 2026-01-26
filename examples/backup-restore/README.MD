# Restore from backup example

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=icd-elasticsearch-backup-restore-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-icd-elasticsearch/tree/main/examples/backup-restore"><img src="https://img.shields.io/badge/Deploy%20with IBM%20Cloud%20Schematics-0f62fe?logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics" style="height: 16px; vertical-align: text-bottom;"></a>
<!-- END SCHEMATICS DEPLOY HOOK -->


This example provides an end-to-end executable flow of how a Elasticsearch DB instance can be created from a backup instance. This example uses the IBM Cloud terraform provider to:

- Create a new resource group if one is not passed in.
- Create a restored ICD Elasticsearch database instance pointing to the lastest backup of the existing Elasticsearch database instance crn passed.

<!-- BEGIN SCHEMATICS DEPLOY TIP HOOK -->
:information_source: Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab
<!-- END SCHEMATICS DEPLOY TIP HOOK -->
