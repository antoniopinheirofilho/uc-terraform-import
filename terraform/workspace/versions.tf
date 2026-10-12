terraform {
  # import blocks require >= 1.5; for_each inside import blocks requires >= 1.7
  required_version = ">= 1.7.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.59.0"
    }
  }

  # Backend unset => local state. Configure remote state (e.g. HCP Terraform) here.
}
