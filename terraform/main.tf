# Pass the YAML-sourced maps into the typed module. The module's variable type
# constraints validate the decoded data (this is what preserves type-safety when the
# source is YAML rather than native tfvars).

module "uc" {
  source = "./modules/uc"

  catalogs            = local.catalogs
  schemas             = local.schemas
  volumes             = local.volumes
  storage_credentials = local.storage_credentials
  external_locations  = local.external_locations
  connections         = local.connections
  workspace_bindings  = local.workspace_bindings
  grants              = local.grants
}
