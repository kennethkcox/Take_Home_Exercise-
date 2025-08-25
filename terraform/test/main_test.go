package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTerraformPlan(t *testing.T) {
	t.Parallel()

	// Define the path to the Terraform code
	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../",
	}

	// This will run `terraform init` and `terraform plan` and fail the test if there are any errors
	terraform.InitAndPlan(t, terraformOptions)
}
