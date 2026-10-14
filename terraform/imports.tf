# Native import blocks (Terraform >= 1.7) — PERMANENT.
#
# Each block imports only the entries that declare an `import_id`; entries without one
# are not imported (they would be created on apply). This gates adoption per object, so
# the file stays in the repo — you control importing by setting/removing `import_id` on
# each map entry, never by deleting this file.
#
# After an object is confirmed in state (post-apply), dropping its import_id is optional
# hygiene — the import is idempotent, so leaving it is harmless.

import {
  for_each = { for k, v in var.catalogs : k => v.import_id if v.import_id != null }
  to       = databricks_catalog.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.schemas : k => v.import_id if v.import_id != null }
  to       = databricks_schema.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.volumes : k => v.import_id if v.import_id != null }
  to       = databricks_volume.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.storage_credentials : k => v.import_id if v.import_id != null }
  to       = databricks_storage_credential.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.external_locations : k => v.import_id if v.import_id != null }
  to       = databricks_external_location.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.connections : k => v.import_id if v.import_id != null }
  to       = databricks_connection.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.workspace_bindings : k => v.import_id if v.import_id != null }
  to       = databricks_workspace_binding.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in var.grants : k => v.import_id if v.import_id != null }
  to       = databricks_grants.this[each.key]
  id       = each.value
}
