resource "databricks_catalog" "this" {
  for_each = var.catalogs

  name           = each.key
  owner          = each.value.owner
  comment        = each.value.comment
  storage_root   = each.value.storage_root
  isolation_mode = each.value.isolation_mode

  lifecycle {
    # System-managed properties (e.g. collation) are not customer config.
    ignore_changes = [properties]
    # Import-only project: a proposed destroy/replace fails the plan on purpose.
    prevent_destroy = true
  }
}
