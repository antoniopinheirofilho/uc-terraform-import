# Environment: SIT — routes all UC objects under data/sit/ through the
# sit workspace, in the SINGLE shared state. Catalogs ISOLATED to this workspace
# must be managed here (bindings gate visibility); OPEN catalogs may be managed from any
# environment. To add an environment, copy this file and swap "sit" + add its
# data/<env>/ folder and a workspace_connections entry. To remove one, delete this file,
# its data folder, and its connection entry.

provider "databricks" {
  alias   = "sit"
  host    = var.workspace_connections["sit"].host
  profile = var.workspace_connections["sit"].profile # null => environment auth
}

module "uc_sit" {
  source    = "./modules/uc"
  providers = { databricks = databricks.sit }

  access_profiles     = local.access_profiles
  catalogs            = try(local.inventory["sit"].catalogs, {})
  schemas             = try(local.inventory["sit"].schemas, {})
  volumes             = try(local.inventory["sit"].volumes, {})
  storage_credentials = try(local.inventory["sit"].storage_credentials, {})
  external_locations  = try(local.inventory["sit"].external_locations, {})
  connections         = try(local.inventory["sit"].connections, {})
  workspace_bindings  = try(local.inventory["sit"].workspace_bindings, {})
  grants              = try(local.inventory["sit"].grants, {})
}

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
