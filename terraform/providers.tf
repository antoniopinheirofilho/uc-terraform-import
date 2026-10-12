# Two Databricks provider configurations:
#   - account:   account-level objects (metastore, metastore assignment)
#   - workspace: workspace-level Unity Catalog objects (catalogs, schemas,
#                external locations, storage credentials, connections, volumes, grants)
#
# Authentication is supplied externally (environment variables or a CLI profile),
# never hardcoded, so the baseline is safe to publish and portable across
# environments. Examples:
#   - User OAuth (dev):  export DATABRICKS_CONFIG_PROFILE for each, or set host/token.
#   - Service principal (automation / HCP): DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET.

provider "databricks" {
  alias      = "account"
  host       = var.databricks_account_host
  account_id = var.databricks_account_id
  profile    = var.databricks_account_profile # null => use environment auth (HCP/CI)
}

provider "databricks" {
  alias   = "workspace"
  host    = var.databricks_workspace_host
  profile = var.databricks_workspace_profile # null => use environment auth (HCP/CI)
}
