terraform {
  # import blocks require >= 1.5; for_each inside import blocks requires >= 1.7
  required_version = ">= 1.7.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.59.0"
    }
  }

  # Backend intentionally left unset => local state for development.
  # For remote state (e.g. HCP Terraform), configure it here, e.g.:
  #
  #   cloud {
  #     organization = "<org>"
  #     workspaces { name = "<workspace>" }
  #   }
  #
  # Keep backend config out of this file so the baseline stays portable.
}
