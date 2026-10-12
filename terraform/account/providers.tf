# ACCOUNT-LEVEL layer. Requires ACCOUNT ADMIN (account-level API).
# Only the metastore object and its workspace assignments live here. If you only
# have metastore admin, you do not run this layer — hand it to an account admin.

provider "databricks" {
  host       = var.databricks_account_host
  account_id = var.databricks_account_id
  profile    = var.databricks_account_profile # null => environment auth (HCP/CI)
}
