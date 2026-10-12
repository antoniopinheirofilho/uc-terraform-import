# Native import blocks (Terraform >= 1.7). The same maps that drive the resources
# drive the imports, so a new object is imported just by adding its map entry.
# Remove this file after the first clean adoption (resources stay managed).

import {
  for_each = var.catalogs
  to       = databricks_catalog.this[each.key]
  id       = each.key
}

import {
  for_each = var.schemas
  to       = databricks_schema.this[each.key]
  id       = each.key
}

import {
  for_each = var.volumes
  to       = databricks_volume.this[each.key]
  id       = each.key
}

import {
  for_each = var.storage_credentials
  to       = databricks_storage_credential.this[each.key]
  id       = each.key
}

import {
  for_each = var.external_locations
  to       = databricks_external_location.this[each.key]
  id       = each.key
}

import {
  for_each = var.connections
  to       = databricks_connection.this[each.key]
  id       = "${var.metastore_id}|${each.key}"
}

import {
  for_each = var.workspace_bindings
  to       = databricks_workspace_binding.this[each.key]
  id       = "${each.value.securable_type}|${each.value.securable_name}|${each.value.workspace_id}"
}

# grants: key is already the import ID
import {
  for_each = var.grants
  to       = databricks_grants.this[each.key]
  id       = each.key
}
