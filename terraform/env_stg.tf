# Environment: STG — routes all UC objects under data/stg/ through the
# stg workspace, in the SINGLE shared state. Catalogs ISOLATED to this workspace
# must be managed here (bindings gate visibility); OPEN catalogs may be managed from any
# environment. To add an environment, copy this file and swap "stg" + add its
# data/<env>/ folder and a workspace_connections entry. To remove one, delete this file,
# its data folder, and its connection entry.

provider "databricks" {
  alias   = "stg"
  host    = var.workspace_connections["stg"].host
  profile = var.workspace_connections["stg"].profile # null => environment auth
}

module "uc_stg" {
  source    = "./modules/uc"
  providers = { databricks = databricks.stg }

  access_profiles     = local.access_profiles
  catalogs            = try(local.inventory["stg"].catalogs, {})
  schemas             = try(local.inventory["stg"].schemas, {})
  volumes             = try(local.inventory["stg"].volumes, {})
  storage_credentials = try(local.inventory["stg"].storage_credentials, {})
  external_locations  = try(local.inventory["stg"].external_locations, {})
  connections         = try(local.inventory["stg"].connections, {})
  workspace_bindings  = try(local.inventory["stg"].workspace_bindings, {})
  grants              = try(local.inventory["stg"].grants, {})
}

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
