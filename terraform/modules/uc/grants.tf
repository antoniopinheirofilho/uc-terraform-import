# Authoritative grants (databricks_grants). TF is the source of truth per securable:
# any privilege not listed is REVOKED on apply, so each entry must be a COMPLETE
# snapshot (system defaults + implicit creator grants). Metastore-level grants are
# managed here too (a metastore admin can administer them via the workspace API).
#
# The securable type is taken from the map key prefix; the matching attribute is set.

resource "databricks_grants" "this" {
  for_each = local.grants

  metastore          = each.value.securable_type == "metastore" ? each.value.securable : null
  catalog            = each.value.securable_type == "catalog" ? each.value.securable : null
  schema             = each.value.securable_type == "schema" ? each.value.securable : null
  volume             = each.value.securable_type == "volume" ? each.value.securable : null
  external_location  = each.value.securable_type == "external_location" ? each.value.securable : null
  storage_credential = each.value.securable_type == "storage_credential" ? each.value.securable : null
  foreign_connection = each.value.securable_type == "foreign_connection" ? each.value.securable : null

  dynamic "grant" {
    for_each = each.value.grants
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }

  lifecycle {
    prevent_destroy = true

    # Fail loud if any grant resolved to no privileges — a raw list was empty, or an
    # `presets` name is undefined / not defined for this securable type (see
    # privilege_presets.tf). This stops a typo'd preset from silently granting nothing.
    precondition {
      condition     = alltrue([for g in each.value.grants : length(g.privileges) > 0])
      error_message = "Grant on '${each.key}' resolved to no privileges: a `presets` name is undefined or has no entry for securable type '${each.value.securable_type}', or a raw `privileges` list is empty. Check the grant YAML and privilege_presets.tf."
    }
  }

  depends_on = [
    databricks_catalog.this,
    databricks_schema.this,
    databricks_volume.this,
    databricks_external_location.this,
    databricks_storage_credential.this,
    databricks_connection.this,
  ]
}
