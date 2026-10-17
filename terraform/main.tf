# One module instance per environment, each routed through its workspace provider alias
# (providers.tf) and fed its slice of the YAML inventory (data/<env>/). All instances
# share ONE Terraform state, so a single state manages the whole metastore across
# workspace-catalog bindings. try(...) defaults an environment with no data to empty.

module "uc_dev" {
  source    = "./modules/uc"
  providers = { databricks = databricks.dev }

  access_profiles     = local.access_profiles
  catalogs            = try(local.inventory["dev"].catalogs, {})
  schemas             = try(local.inventory["dev"].schemas, {})
  volumes             = try(local.inventory["dev"].volumes, {})
  storage_credentials = try(local.inventory["dev"].storage_credentials, {})
  external_locations  = try(local.inventory["dev"].external_locations, {})
  connections         = try(local.inventory["dev"].connections, {})
  workspace_bindings  = try(local.inventory["dev"].workspace_bindings, {})
  grants              = try(local.inventory["dev"].grants, {})
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

