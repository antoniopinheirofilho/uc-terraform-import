resource "databricks_external_location" "this" {
  for_each = var.external_locations

  name            = each.key
  url             = each.value.url
  credential_name = each.value.credential_name
  owner           = each.value.owner
  comment         = each.value.comment
  isolation_mode  = each.value.isolation_mode

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [databricks_storage_credential.this]
}
