# Native import blocks (Terraform >= 1.7 for for_each in import) to adopt existing
# UC objects. The same maps that drive the resources drive the imports, so a new
# object is imported just by adding its map entry. IDs are derived from keys.
# After the first clean adoption these blocks can be removed (resources stay managed).

# ---- Account-level ----
import {
  provider = databricks.account
  to       = databricks_metastore.this
  id       = var.metastore_id
}

import {
  provider = databricks.account
  for_each = toset(var.assigned_workspace_ids)
  to       = databricks_metastore_assignment.this[each.key]
  id       = "${each.key}|${var.metastore_id}"
}

# ---- Workspace-level objects ----
import {
  provider = databricks.workspace
  for_each = var.catalogs
  to       = databricks_catalog.this[each.key]
  id       = each.key
}

import {
  provider = databricks.workspace
  for_each = var.schemas
  to       = databricks_schema.this[each.key]
  id       = each.key
}

import {
  provider = databricks.workspace
  for_each = var.volumes
  to       = databricks_volume.this[each.key]
  id       = each.key
}

import {
  provider = databricks.workspace
  for_each = var.storage_credentials
  to       = databricks_storage_credential.this[each.key]
  id       = each.key
}

import {
  provider = databricks.workspace
  for_each = var.external_locations
  to       = databricks_external_location.this[each.key]
  id       = each.key
}

import {
  provider = databricks.workspace
  for_each = var.connections
  to       = databricks_connection.this[each.key]
  id       = "${var.metastore_id}|${each.key}"
}

# ---- Grants (key is already the import ID) ----
import {
  provider = databricks.workspace
  for_each = var.grants
  to       = databricks_grants.this[each.key]
  id       = each.key
}
