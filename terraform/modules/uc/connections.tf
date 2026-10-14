# UC connections. Secrets (e.g. bearer_token) are write-only and not stored here;
# if a plan shows secret drift, add lifecycle { ignore_changes = [options] }.

resource "databricks_connection" "this" {
  for_each = var.connections

  name            = each.key
  connection_type = each.value.connection_type
  owner           = each.value.owner
  options         = each.value.options

  lifecycle {
    prevent_destroy = true
  }
}
