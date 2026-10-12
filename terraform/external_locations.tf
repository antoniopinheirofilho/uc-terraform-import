resource "databricks_external_location" "this" {
  provider = databricks.workspace
  for_each = var.external_locations

  name            = each.key
  url             = each.value.url
  credential_name = each.value.credential_name
  owner           = each.value.owner
  comment         = each.value.comment

  depends_on = [databricks_storage_credential.this]
}
