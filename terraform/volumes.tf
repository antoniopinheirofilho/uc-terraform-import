resource "databricks_volume" "this" {
  provider = databricks.workspace
  for_each = local.volumes

  catalog_name = each.value.catalog
  schema_name  = each.value.schema
  name         = each.value.name
  volume_type  = each.value.volume_type
  owner        = each.value.owner
  comment      = each.value.comment

  depends_on = [databricks_schema.this]
}
