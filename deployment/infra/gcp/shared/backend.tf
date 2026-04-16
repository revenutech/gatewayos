# =============================================================================
# Revenu Platform — Gateway Terraform Remote State
# ISO 27001: A.8.9 (Configuration management), A.5.33 (Protection of records)
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "revenu-platform-tf-state"
    # prefix is set per environment:
    #   gateway/dev/terraform.tfstate
    #   gateway/staging/terraform.tfstate
    #   gateway/production/terraform.tfstate
  }
}
