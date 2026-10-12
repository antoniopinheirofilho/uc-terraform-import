resource "databricks_schema" "this" {
  provider = databricks.workspace
  for_each = local.schemas

  catalog_name = each.value.catalog
  name         = each.value.name
  owner        = each.value.owner
  comment      = each.value.comment

  lifecycle {
    ignore_changes = [properties]
  }

  depends_on = [databricks_catalog.this]
}
