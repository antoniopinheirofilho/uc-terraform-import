resource "databricks_catalog" "this" {
  provider = databricks.workspace
  for_each = var.catalogs

  name           = each.key
  owner          = each.value.owner
  comment        = each.value.comment
  storage_root   = each.value.storage_root
  isolation_mode = each.value.isolation_mode

  # System-managed properties (e.g. collation) are not customer config.
  lifecycle {
    ignore_changes = [properties]
  }
}
