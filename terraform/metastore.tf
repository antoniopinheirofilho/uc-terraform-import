# Account-level Unity Catalog objects (metastore + workspace assignments).
# The experimental Resource Exporter does NOT emit these at workspace scope,
# so they are authored by hand and imported via the account-level provider.

resource "databricks_metastore" "this" {
  provider = databricks.account

  name   = var.metastore_name
  region = var.metastore_region
  owner  = var.metastore_owner

  # Delta Sharing is not managed here. The provider defaults the recipient-token
  # lifetime to 31536000, which would drift against this INTERNAL metastore
  # (live value 0), so it is ignored to keep the plan a clean no-op.
  lifecycle {
    ignore_changes = [delta_sharing_recipient_token_lifetime_in_seconds]
  }
}

resource "databricks_metastore_assignment" "this" {
  provider = databricks.account
  for_each = toset(var.assigned_workspace_ids)

  workspace_id = each.key
  metastore_id = databricks_metastore.this.id
}
