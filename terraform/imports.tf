# Native import blocks (Terraform >= 1.7), grouped by environment. Each block imports
# only the entries whose YAML sets `import_id` (the per-object gate; see README §7);
# entries without one are created on apply. The per-env import map `local._import` is
# built in data.tf. These stay in the repo permanently — control adoption via `import_id`.

# ---- dev ----
import {
  for_each = try(local._import["dev"].catalogs, {})
  to       = module.uc_dev.databricks_catalog.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].schemas, {})
  to       = module.uc_dev.databricks_schema.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].volumes, {})
  to       = module.uc_dev.databricks_volume.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].storage_credentials, {})
  to       = module.uc_dev.databricks_storage_credential.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].external_locations, {})
  to       = module.uc_dev.databricks_external_location.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].connections, {})
  to       = module.uc_dev.databricks_connection.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].workspace_bindings, {})
  to       = module.uc_dev.databricks_workspace_binding.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].grants, {})
  to       = module.uc_dev.databricks_grants.this[each.key]
  id       = each.value
}

# ---- sit ----
import {
  for_each = try(local._import["sit"].catalogs, {})
  to       = module.uc_sit.databricks_catalog.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].schemas, {})
  to       = module.uc_sit.databricks_schema.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].volumes, {})
  to       = module.uc_sit.databricks_volume.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].storage_credentials, {})
  to       = module.uc_sit.databricks_storage_credential.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].external_locations, {})
  to       = module.uc_sit.databricks_external_location.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].connections, {})
  to       = module.uc_sit.databricks_connection.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].workspace_bindings, {})
  to       = module.uc_sit.databricks_workspace_binding.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["sit"].grants, {})
  to       = module.uc_sit.databricks_grants.this[each.key]
  id       = each.value
}

# ---- stg ----
import {
  for_each = try(local._import["stg"].catalogs, {})
  to       = module.uc_stg.databricks_catalog.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].schemas, {})
  to       = module.uc_stg.databricks_schema.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].volumes, {})
  to       = module.uc_stg.databricks_volume.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].storage_credentials, {})
  to       = module.uc_stg.databricks_storage_credential.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].external_locations, {})
  to       = module.uc_stg.databricks_external_location.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].connections, {})
  to       = module.uc_stg.databricks_connection.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].workspace_bindings, {})
  to       = module.uc_stg.databricks_workspace_binding.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["stg"].grants, {})
  to       = module.uc_stg.databricks_grants.this[each.key]
  id       = each.value
}

# ---- prod ----
import {
  for_each = try(local._import["prod"].catalogs, {})
  to       = module.uc_prod.databricks_catalog.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].schemas, {})
  to       = module.uc_prod.databricks_schema.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].volumes, {})
  to       = module.uc_prod.databricks_volume.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].storage_credentials, {})
  to       = module.uc_prod.databricks_storage_credential.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].external_locations, {})
  to       = module.uc_prod.databricks_external_location.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].connections, {})
  to       = module.uc_prod.databricks_connection.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].workspace_bindings, {})
  to       = module.uc_prod.databricks_workspace_binding.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["prod"].grants, {})
  to       = module.uc_prod.databricks_grants.this[each.key]
  id       = each.value
}

