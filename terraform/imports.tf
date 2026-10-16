# Native import blocks (Terraform >= 1.7) — PERMANENT. Import blocks must live in the
# root module and reference a static module instance, so there is one set per workspace.
# Each block imports only the entries whose YAML declares an `import_id`; entries without
# one are created on apply. Control adoption per object via `import_id` in the YAML.

locals {
  # local._import[<workspace>][<type>] = { key => import_id } for entries that set import_id
  _import = {
    for ws in local._workspaces : ws => {
      for t in local._types : t => {
        for k, v in local.inventory[ws][t] : k => v.import_id if try(v.import_id, null) != null
      }
    }
  }
}

# ---- primary ----
import {
  for_each = try(local._import["primary"].catalogs, {})
  to       = module.uc_primary.databricks_catalog.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].schemas, {})
  to       = module.uc_primary.databricks_schema.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].volumes, {})
  to       = module.uc_primary.databricks_volume.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].storage_credentials, {})
  to       = module.uc_primary.databricks_storage_credential.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].external_locations, {})
  to       = module.uc_primary.databricks_external_location.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].connections, {})
  to       = module.uc_primary.databricks_connection.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].workspace_bindings, {})
  to       = module.uc_primary.databricks_workspace_binding.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["primary"].grants, {})
  to       = module.uc_primary.databricks_grants.this[each.key]
  id       = each.value
}

# ---- additional workspace (copy per workspace; swap "secondary" / module.uc_secondary) ----
# import {
#   for_each = try(local._import["secondary"].catalogs, {})
#   to       = module.uc_secondary.databricks_catalog.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].schemas, {})
#   to       = module.uc_secondary.databricks_schema.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].volumes, {})
#   to       = module.uc_secondary.databricks_volume.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].storage_credentials, {})
#   to       = module.uc_secondary.databricks_storage_credential.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].external_locations, {})
#   to       = module.uc_secondary.databricks_external_location.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].connections, {})
#   to       = module.uc_secondary.databricks_connection.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].workspace_bindings, {})
#   to       = module.uc_secondary.databricks_workspace_binding.this[each.key]
#   id       = each.value
# }
# import {
#   for_each = try(local._import["secondary"].grants, {})
#   to       = module.uc_secondary.databricks_grants.this[each.key]
#   id       = each.value
# }
