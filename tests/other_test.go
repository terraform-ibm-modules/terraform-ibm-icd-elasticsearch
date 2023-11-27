// Tests in this file are run in the PR pipeline
package test

import (
	"crypto/rand"
	"encoding/base64"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:            t,
		TerraformDir:       "examples/basic",
		Prefix:             "es-test",
		ResourceGroup:      resourceGroup,
		BestRegionYAMLPath: regionSelectionPath,
	})

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunCompleteExampleOtherVersion(t *testing.T) {
	t.Parallel()

	// Generate a 15 char long random string for the admin_pass
	randomBytes := make([]byte, 15)
	_, err := rand.Read(randomBytes)
	randomPass := "A" + base64.URLEncoding.EncodeToString(randomBytes)[:10]

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:            t,
		TerraformDir:       completeExampleTerraformDir,
		Prefix:             "es-complete-test",
		ResourceGroup:      resourceGroup,
		BestRegionYAMLPath: regionSelectionPath,
		TerraformVars: map[string]interface{}{
			"elasticsearch_version":       "8.7",
			"existing_sm_instance_guid":   permanentResources["secretsManagerGuid"],
			"existing_sm_instance_region": permanentResources["secretsManagerRegion"],
			"users": []map[string]interface{}{
				{
					"name":     "testuser",
					"password": randomPass, // pragma: allowlist secret
					"type":     "database",
				},
			},
			"admin_pass": randomPass,
		},
	})
	options.SkipTestTearDown = true
	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")

	// check if outputs exist
	outputs := terraform.OutputAll(options.Testing, options.TerraformOptions)
	expectedOutputs := []string{"port", "hostname"}
	_, outputErr := testhelper.ValidateTerraformOutputs(outputs, expectedOutputs...)
	assert.NoErrorf(t, outputErr, "Some outputs not found or nil")
	options.TestTearDown()
}
