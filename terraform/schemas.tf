resource "databricks_schema" "this" {
  for_each = local.schemas

  catalog_name = each.value.catalog
  name         = each.value.name
  owner        = each.value.owner
  comment      = each.value.comment

  lifecycle {
    ignore_changes  = [properties]
    prevent_destroy = true
  }

  depends_on = [databricks_catalog.this]
}
