terraform {
  required_version = ">= 1.7.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.59.0"
    }
  }
  # No provider block — the default databricks provider is inherited from the root.
}
