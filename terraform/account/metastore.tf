resource "databricks_metastore" "this" {
  name   = var.metastore_name
  region = var.metastore_region
  owner  = var.metastore_owner

  # Delta Sharing not managed here; the provider otherwise defaults the recipient
  # token lifetime (31536000) which drifts against an INTERNAL metastore.
  lifecycle {
    ignore_changes = [delta_sharing_recipient_token_lifetime_in_seconds]
  }
}

resource "databricks_metastore_assignment" "this" {
  for_each = toset(var.assigned_workspace_ids)

  workspace_id = each.key
  metastore_id = databricks_metastore.this.id
}
