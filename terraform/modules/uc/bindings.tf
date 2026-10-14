# Workspace bindings for ISOLATED securables. For each binding, set
# isolation_mode = "ISOLATED" on the securable (catalog/external location/storage
# credential) and list its bound workspaces here. OPEN securables need no bindings.

resource "databricks_workspace_binding" "this" {
  for_each = var.workspace_bindings

  securable_type = each.value.securable_type
  securable_name = each.value.securable_name
  workspace_id   = each.value.workspace_id
  binding_type   = each.value.binding_type

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    databricks_catalog.this,
    databricks_external_location.this,
    databricks_storage_credential.this,
  ]
}
