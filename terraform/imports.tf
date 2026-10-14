# Native import blocks (Terraform >= 1.7) — PERMANENT. Import blocks must live in the
# root module, so they target the module's resources (module.uc.<resource>.this[key]).
#
# Each block imports only the entries whose YAML declares an `import_id`; entries
# without one are created on apply. You control adoption per object by setting/removing
# `import_id` in the YAML, never by editing this file.

import {
  for_each = { for k, v in local.catalogs : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_catalog.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.schemas : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_schema.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.volumes : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_volume.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.storage_credentials : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_storage_credential.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.external_locations : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_external_location.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.connections : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_connection.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.workspace_bindings : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_workspace_binding.this[each.key]
  id       = each.value
}

import {
  for_each = { for k, v in local.grants : k => v.import_id if try(v.import_id, null) != null }
  to       = module.uc.databricks_grants.this[each.key]
  id       = each.value
}
