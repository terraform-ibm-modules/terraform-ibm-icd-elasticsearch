// Tests in this file are run in the PR pipeline.
package test

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"os"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testschematic"
)

const completeExampleTerraformDir = "examples/complete"
const fscloudExampleTerraformDir = "examples/fscloud"
const fullyConfigurableSolutionTerraformDir = "solutions/fully-configurable"
const securityEnforcedSolutionTerraformDir = "solutions/security-enforced"

const icdType = "elasticsearch"

// Use existing resource group
const resourceGroup = "geretain-test-elasticsearch"

// Restricting due to limited availability of BYOK in certain regions
const regionSelectionPath = "../common-dev-assets/common-go-assets/icd-region-prefs.yaml"

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

var permanentResources map[string]interface{}

var sharedInfoSvc *cloudinfo.CloudInfoService
var validICDRegions = []string{
	"eu-de",
	"us-south",
}

func GetRegionVersions(region string) (string, string) {

	cloudInfoSvc, err := cloudinfo.NewCloudInfoServiceFromEnv("TF_VAR_ibmcloud_api_key", cloudinfo.CloudInfoServiceOptions{
		IcdRegion: region,
	})

	if err != nil {
		log.Fatal(err)
	}

	icdAvailableVersions, err := cloudInfoSvc.GetAvailableIcdVersions(icdType)

	if err != nil {
		log.Fatal(err)
	}

	if len(icdAvailableVersions) == 0 {
		log.Fatal("No available ICD versions found")
	}

	sort.Slice(icdAvailableVersions, func(i, j int) bool {
		partsI := strings.Split(icdAvailableVersions[i], ".")
		partsJ := strings.Split(icdAvailableVersions[j], ".")

		majorI, _ := strconv.Atoi(partsI[0])
		majorJ, _ := strconv.Atoi(partsJ[0])

		if majorI != majorJ {
			return majorI < majorJ
		}

		minorI := 0
		minorJ := 0

		if len(partsI) >= 2 {
			minorI, _ = strconv.Atoi(partsI[1])
		}
		if len(partsJ) >= 2 {
			minorJ, _ = strconv.Atoi(partsJ[1])
		}
		return minorI < minorJ
	})

	fmt.Println("version list is ", icdAvailableVersions)
	latestVersion := icdAvailableVersions[len(icdAvailableVersions)-1]
	oldestVersion := icdAvailableVersions[0]

	return latestVersion, oldestVersion
}

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {
	var err error
	sharedInfoSvc, err = cloudinfo.NewCloudInfoServiceFromEnv("TF_VAR_ibmcloud_api_key", cloudinfo.CloudInfoServiceOptions{})
	if err != nil {
		log.Fatal(err)
	}

	permanentResources, err = common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}

	os.Exit(m.Run())
}

func TestRunFullyConfigurableSolutionSchematics(t *testing.T) {
	t.Parallel()

	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing: t,
		TarIncludePatterns: []string{
			"*.tf",
			fmt.Sprintf("%s/*.tf", fullyConfigurableSolutionTerraformDir),
			fmt.Sprintf("%s/scripts/*.sh", fullyConfigurableSolutionTerraformDir),
			fmt.Sprintf("%s/*.sh", "scripts"),
		},
		TemplateFolder:         fullyConfigurableSolutionTerraformDir,
		BestRegionYAMLPath:     regionSelectionPath,
		Prefix:                 "els-fc-da",
		ResourceGroup:          resourceGroup,
		DeleteWorkspaceOnFail:  false,
		WaitJobCompleteMinutes: 60,
	})

	serviceCredentialSecrets := []map[string]interface{}{
		{
			"secret_group_name": fmt.Sprintf("%s-secret-group", options.Prefix),
			"service_credentials": []map[string]string{
				{
					"secret_name": fmt.Sprintf("%s-cred-reader", options.Prefix),
					"service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Viewer",
				},
				{
					"secret_name": fmt.Sprintf("%s-cred-writer", options.Prefix),
					"service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Editor",
				},
			},
		},
	}

	region := "us-south"
	latestVersion, _ := GetRegionVersions(region)
	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
		{Name: "access_tags", Value: permanentResources["accessTags"], DataType: "list(string)"},
		{Name: "kms_encryption_enabled", Value: true, DataType: "bool"},
		{Name: "deletion_protection", Value: false, DataType: "bool"},
		{Name: "existing_kms_instance_crn", Value: permanentResources["hpcs_south_crn"], DataType: "string"},
		{Name: "kms_endpoint_type", Value: "private", DataType: "string"},
		{Name: "existing_resource_group_name", Value: resourceGroup, DataType: "string"},
		{Name: "plan", Value: "platinum", DataType: "string"},
		{Name: "region", Value: region, DataType: "string"},
		{Name: "elasticsearch_version", Value: latestVersion, DataType: "string"},
		{Name: "enable_elser_model", Value: true, DataType: "bool"},
		{Name: "service_credential_names", Value: "{\"admin_test\": \"Administrator\", \"editor_test\": \"Editor\"}", DataType: "map(string)"},
		{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
		{Name: "service_credential_secrets", Value: serviceCredentialSecrets, DataType: "list(object)"},
		{Name: "service_endpoints", Value: "private", DataType: "string"},
		{Name: "admin_pass_secrets_manager_secret_group", Value: options.Prefix, DataType: "string"},
		{Name: "admin_pass_secrets_manager_secret_name", Value: options.Prefix, DataType: "string"},
		{Name: "enable_kibana_dashboard", Value: true, DataType: "bool"},
		{Name: "provider_visibility", Value: "private", DataType: "string"},
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
		{Name: "admin_pass", Value: GetRandomAdminPassword(t), DataType: "string"},
	}

	// need to ignore because of a provider issue: https://github.com/IBM-Cloud/terraform-provider-ibm/issues/6330
	options.IgnoreUpdates = testhelper.Exemptions{
		List: []string{
			"module.code_engine_kibana[0].module.app[\"" + options.Prefix + "-ce-kibana-app\"].ibm_code_engine_app.ce_app",
		},
	}

	err := options.RunSchematicTest()
	assert.Nil(t, err, "This should not have errored")
}

func TestRunSecurityEnforcedUpgradeSolutionSchematics(t *testing.T) {
	t.Parallel()

	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing:       t,
		Region:        "us-south",
		Prefix:        "es-se-upg",
		ResourceGroup: resourceGroup,
		TarIncludePatterns: []string{
			"*.tf",
			fullyConfigurableSolutionTerraformDir + "/*.tf",
			securityEnforcedSolutionTerraformDir + "/*.tf",
		},
		TemplateFolder:             securityEnforcedSolutionTerraformDir,
		Tags:                       []string{"es-se-upg"},
		DeleteWorkspaceOnFail:      false,
		WaitJobCompleteMinutes:     120,
		CheckApplyResultForUpgrade: true,
	})

	serviceCredentialSecrets := []map[string]any{
		{
			"secret_group_name": fmt.Sprintf("%s-secret-group", options.Prefix),
			"service_credentials": []map[string]string{
				{
					"secret_name": fmt.Sprintf("%s-cred-reader", options.Prefix),
					"service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Viewer",
				},
				{
					"secret_name": fmt.Sprintf("%s-cred-writer", options.Prefix),
					"service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Editor",
				},
			},
		},
	}

	serviceCredentialNames := map[string]string{
		"admin": "Administrator",
		"user1": "Viewer",
		"user2": "Editor",
	}

	serviceCredentialNamesJSON, err := json.Marshal(serviceCredentialNames)
	if err != nil {
		log.Fatalf("Error converting to JSON: %s", err)
	}

	region := "us-south"
	latestVersion, _ := GetRegionVersions(region)
	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
		{Name: "deletion_protection", Value: false, DataType: "bool"},
		{Name: "region", Value: region, DataType: "string"},
		{Name: "elasticsearch_version", Value: latestVersion, DataType: "string"},
		{Name: "existing_resource_group_name", Value: resourceGroup, DataType: "string"},
		{Name: "existing_kms_instance_crn", Value: permanentResources["hpcs_south_crn"], DataType: "string"},
		{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
		{Name: "service_credential_secrets", Value: serviceCredentialSecrets, DataType: "list(object)"},
		{Name: "service_credential_names", Value: string(serviceCredentialNamesJSON), DataType: "map(string)"},
		{Name: "admin_pass_secrets_manager_secret_name", Value: options.Prefix, DataType: "string"},
		{Name: "admin_pass", Value: GetRandomAdminPassword(t), DataType: "string"},
		{Name: "admin_pass_secrets_manager_secret_group", Value: fmt.Sprintf("es-%s-admin-secrets", options.Prefix), DataType: "string"},
	}

	err = options.RunSchematicUpgradeTest()
	assert.Nil(t, err, "This should not have errored")
}

func TestRunSecurityEnforcedSolutionSchematics(t *testing.T) {
	t.Parallel()

	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing: t,
		TarIncludePatterns: []string{
			"*.tf",
			fmt.Sprintf("%s/*.tf", fullyConfigurableSolutionTerraformDir),
			fmt.Sprintf("%s/*.tf", securityEnforcedSolutionTerraformDir),
			fmt.Sprintf("%s/scripts/*.sh", fullyConfigurableSolutionTerraformDir),
			fmt.Sprintf("%s/*.sh", "scripts"),
		},
		TemplateFolder:         securityEnforcedSolutionTerraformDir,
		BestRegionYAMLPath:     regionSelectionPath,
		Prefix:                 "els-se-da",
		ResourceGroup:          resourceGroup,
		DeleteWorkspaceOnFail:  false,
		WaitJobCompleteMinutes: 60,
	})

	serviceCredentialSecrets := []map[string]interface{}{
		{
			"secret_group_name": fmt.Sprintf("%s-secret-group", options.Prefix),
			"service_credentials": []map[string]string{
				{
					"secret_name": fmt.Sprintf("%s-cred-reader", options.Prefix),
					"service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Viewer",
				},
				{
					"secret_name": fmt.Sprintf("%s-cred-writer", options.Prefix),
					"service_credentials_source_service_role_crn": "crn:v1:bluemix:public:iam::::role:Editor",
				},
			},
		},
	}

	uniqueResourceGroup := generateUniqueResourceGroupName(options.Prefix)

	region := "us-south"
	latestVersion, _ := GetRegionVersions(region)

	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
		{Name: "access_tags", Value: permanentResources["accessTags"], DataType: "list(string)"},
		{Name: "deletion_protection", Value: false, DataType: "bool"},
		{Name: "region", Value: region, DataType: "string"},
		{Name: "elasticsearch_version", Value: latestVersion, DataType: "string"},
		{Name: "existing_kms_instance_crn", Value: permanentResources["hpcs_south_crn"], DataType: "string"},
		{Name: "existing_backup_kms_key_crn", Value: permanentResources["hpcs_south_root_key_crn"], DataType: "string"},
		{Name: "existing_resource_group_name", Value: uniqueResourceGroup, DataType: "string"},
		{Name: "plan", Value: "platinum", DataType: "string"},
		{Name: "enable_elser_model", Value: true, DataType: "bool"},
		{Name: "service_credential_names", Value: "{\"admin_test\": \"Administrator\", \"editor_test\": \"Editor\"}", DataType: "map(string)"},
		{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
		{Name: "service_credential_secrets", Value: serviceCredentialSecrets, DataType: "list(object)"},
		{Name: "admin_pass_secrets_manager_secret_group", Value: options.Prefix, DataType: "string"},
		{Name: "admin_pass_secrets_manager_secret_name", Value: options.Prefix, DataType: "string"},
		{Name: "enable_kibana_dashboard", Value: true, DataType: "bool"},
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
	}

	// need to ignore because of a provider issue: https://github.com/IBM-Cloud/terraform-provider-ibm/issues/6330
	options.IgnoreUpdates = testhelper.Exemptions{
		List: []string{
			"module.elasticsearch.module.code_engine_kibana[0].module.app[\"" + options.Prefix + "-ce-kibana-app\"].ibm_code_engine_app.ce_app",
		},
	}

	err := sharedInfoSvc.WithNewResourceGroup(uniqueResourceGroup, func() error {
		return options.RunSchematicTest()
	})
	assert.Nil(t, err, "This should not have errored")
}

func TestRunExistingInstance(t *testing.T) {
	t.Parallel()
	prefix := fmt.Sprintf("elastic-t-%s", strings.ToLower(random.UniqueId()))
	realTerraformDir := ".."
	tempTerraformDir, _ := files.CopyTerraformFolderToTemp(realTerraformDir, fmt.Sprintf(prefix+"-%s", strings.ToLower(random.UniqueId())))

	index, err := rand.Int(rand.Reader, big.NewInt(int64(len(validICDRegions))))
	if err != nil {
		log.Fatalf("Failed to generate a secure random index: %v", err)
	}
	region := validICDRegions[index.Int64()]

	// Verify ibmcloud_api_key variable is set
	checkVariable := "TF_VAR_ibmcloud_api_key"
	val, present := os.LookupEnv(checkVariable)
	require.True(t, present, checkVariable+" environment variable not set")
	require.NotEqual(t, "", val, checkVariable+" environment variable is empty")

	logger.Log(t, "Tempdir: ", tempTerraformDir)

	_, oldestVersion := GetRegionVersions(region)
	existingTerraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: tempTerraformDir + "/examples/basic",
		Vars: map[string]interface{}{
			"prefix":                prefix,
			"region":                region,
			"elasticsearch_version": oldestVersion,
			"service_endpoints":     "public-and-private",
		},
		// Set Upgrade to true to ensure latest version of providers and modules are used by terratest.
		// This is the same as setting the -upgrade=true flag with terraform.
		Upgrade: true,
	})

	terraform.WorkspaceSelectOrNew(t, existingTerraformOptions, prefix)
	_, existErr := terraform.InitAndApplyE(t, existingTerraformOptions)
	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
	} else {
		logger.Log(t, "existing_elasticsearch_instance_crn: ", terraform.Output(t, existingTerraformOptions, "elasticsearch_crn"))
		options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
			Testing: t,
			TarIncludePatterns: []string{
				"*.tf",
				fmt.Sprintf("%s/*.tf", fullyConfigurableSolutionTerraformDir),
				fmt.Sprintf("%s/*.tf", fscloudExampleTerraformDir),
				fmt.Sprintf("%s/*.tf", "modules/fscloud"),
				fmt.Sprintf("%s/*.sh", "scripts"),
			},
			TemplateFolder:         fullyConfigurableSolutionTerraformDir,
			BestRegionYAMLPath:     regionSelectionPath,
			Prefix:                 "els-sr-da",
			ResourceGroup:          resourceGroup,
			DeleteWorkspaceOnFail:  false,
			WaitJobCompleteMinutes: 60,
		})

		options.TerraformVars = []testschematic.TestSchematicTerraformVar{
			{Name: "prefix", Value: options.Prefix, DataType: "string"},
			{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
			{Name: "existing_elasticsearch_instance_crn", Value: terraform.Output(t, existingTerraformOptions, "elasticsearch_crn"), DataType: "string"},
			{Name: "existing_resource_group_name", Value: fmt.Sprintf("%s-resource-group", prefix), DataType: "string"},
			{Name: "deletion_protection", Value: false, DataType: "bool"},
			{Name: "region", Value: region, DataType: "string"},
			{Name: "provider_visibility", Value: "public", DataType: "string"},
		}
		err := options.RunSchematicTest()
		assert.Nil(t, err, "This should not have errored")

	}
	envVal, _ := os.LookupEnv("DO_NOT_DESTROY_ON_FAILURE")
	// Destroy the temporary existing resources if required
	if t.Failed() && strings.ToLower(envVal) == "true" {
		fmt.Println("Terratest failed. Debug the test and delete resources manually.")
	} else {
		logger.Log(t, "START: Destroy (existing resources)")
		terraform.Destroy(t, existingTerraformOptions)
		terraform.WorkspaceDelete(t, existingTerraformOptions, prefix)
		logger.Log(t, "END: Destroy (existing resources)")
	}
}

// Test the DA when using IBM owned encryption keys
func TestFullyConfigurableSolutionIBMKeys(t *testing.T) {
	t.Parallel()

	options := testhelper.TestOptionsDefault(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  fullyConfigurableSolutionTerraformDir,
		Region:        "us-south",
		Prefix:        "esicdkey",
		ResourceGroup: resourceGroup,
	})

	region := options.Region
	latestVersion, _ := GetRegionVersions(region)
	options.TerraformVars = map[string]interface{}{
		"elasticsearch_version":        latestVersion,
		"region":                       region,
		"provider_visibility":          "public",
		"existing_resource_group_name": resourceGroup,
		"kms_encryption_enabled":       false,
		"prefix":                       options.Prefix,
		"deletion_protection":          false,
	}

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestPlanValidation(t *testing.T) {
	options := testhelper.TestOptionsDefault(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  fullyConfigurableSolutionTerraformDir,
		Prefix:        "val-plan",
		ResourceGroup: resourceGroup,
		Region:        "us-south", // skip VPC region picker
	})
	options.TestSetup()
	options.TerraformOptions.NoColor = true
	options.TerraformOptions.Logger = logger.Discard

	latestVersion, _ := GetRegionVersions(options.Region)

	options.TerraformOptions.Vars = map[string]interface{}{
		"prefix":                       options.Prefix,
		"existing_resource_group_name": resourceGroup,
		"region":                       "us-south",
		"elasticsearch_version":        latestVersion,
		"provider_visibility":          "public",
	}

	// Test the DA when using Elser model
	var fullyConfigurableSolutionWithElserModelVars = map[string]interface{}{
		"kms_encryption_enabled":    true,
		"existing_kms_instance_crn": permanentResources["hpcs_south_crn"],
		"enable_elser_model":        true,
		"plan":                      "platinum",
	}

	// Test the DA when using Kibana dashboard and existing KMS instance
	var fullyConfigurableSolutionWithKibanaDashboardVars = map[string]interface{}{
		"enable_kibana_dashboard":   true,
		"kms_encryption_enabled":    true,
		"existing_kms_instance_crn": permanentResources["hpcs_south_crn"],
		"plan":                      "enterprise",
	}

	// Test the DA when using IBM owned encryption key
	var fullyConfigurableSolutionWithUseIbmOwnedEncKey = map[string]interface{}{
		"kms_encryption_enabled": false,
	}

	// Create a map of the variables
	tfVarsMap := map[string]map[string]interface{}{
		"fullyConfigurableSolutionWithElserModelVars":      fullyConfigurableSolutionWithElserModelVars,
		"fullyConfigurableSolutionWithKibanaDashboardVars": fullyConfigurableSolutionWithKibanaDashboardVars,
		"fullyConfigurableSolutionWithUseIbmOwnedEncKey":   fullyConfigurableSolutionWithUseIbmOwnedEncKey,
	}

	_, initErr := terraform.InitE(t, options.TerraformOptions)
	if assert.Nil(t, initErr, "This should not have errored") {
		// Iterate over the slice of maps
		for name, tfVars := range tfVarsMap {
			t.Run(name, func(t *testing.T) {
				// Iterate over the keys and values in each map
				for key, value := range tfVars {
					options.TerraformOptions.Vars[key] = value
				}
				output, err := terraform.PlanE(t, options.TerraformOptions)
				assert.Nil(t, err, "This should not have errored")
				assert.NotNil(t, output, "Expected some output")
				// Delete the keys from the map
				for key := range tfVars {
					delete(options.TerraformOptions.Vars, key)
				}
			})
		}
	}
}

func GetRandomAdminPassword(t *testing.T) string {
	// Generate a 15 char long random string for the admin_pass
	randomBytes := make([]byte, 13)
	_, randErr := rand.Read(randomBytes)
	require.Nil(t, randErr) // do not proceed if we can't gen a random password
	randomPass := "A1" + base64.URLEncoding.EncodeToString(randomBytes)[:13]
	return randomPass
}

func generateUniqueResourceGroupName(baseName string) string {
	id := uuid.New().String()[:8]
	return fmt.Sprintf("%s-%s", baseName, id)
}
