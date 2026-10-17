# Environment: PROD — routes all UC objects under data/prod/ through the
# prod workspace, in the SINGLE shared state. Catalogs ISOLATED to this workspace
# must be managed here (bindings gate visibility); OPEN catalogs may be managed from any
# environment. To add an environment, copy this file and swap "prod" + add its
# data/<env>/ folder and a workspace_connections entry. To remove one, delete this file,
# its data folder, and its connection entry.

provider "databricks" {
  alias   = "prod"
  host    = var.workspace_connections["prod"].host
  profile = var.workspace_connections["prod"].profile # null => environment auth
}

module "uc_prod" {
  source    = "./modules/uc"
  providers = { databricks = databricks.prod }

  access_profiles     = local.access_profiles
  catalogs            = try(local.inventory["prod"].catalogs, {})
  schemas             = try(local.inventory["prod"].schemas, {})
  volumes             = try(local.inventory["prod"].volumes, {})
  storage_credentials = try(local.inventory["prod"].storage_credentials, {})
  external_locations  = try(local.inventory["prod"].external_locations, {})
  connections         = try(local.inventory["prod"].connections, {})
  workspace_bindings  = try(local.inventory["prod"].workspace_bindings, {})
  grants              = try(local.inventory["prod"].grants, {})
}

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
