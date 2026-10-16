# One module instance per workspace, each routed through that workspace's provider
# alias and fed the inventory under data/<workspace>/. All instances write to the SAME
# Terraform state, so a single state manages the whole metastore across bindings.
# The typed module variables validate the YAML-sourced maps. try(...) defaults a
# workspace with no data folder to empty.

module "uc_primary" {
  source    = "./modules/uc"
  providers = { databricks = databricks.primary }

  catalogs            = try(local.inventory["primary"].catalogs, {})
  schemas             = try(local.inventory["primary"].schemas, {})
  volumes             = try(local.inventory["primary"].volumes, {})
  storage_credentials = try(local.inventory["primary"].storage_credentials, {})
  external_locations  = try(local.inventory["primary"].external_locations, {})
  connections         = try(local.inventory["primary"].connections, {})
  workspace_bindings  = try(local.inventory["primary"].workspace_bindings, {})
  grants              = try(local.inventory["primary"].grants, {})
}

# Additional workspace (copy for each one; see providers.tf). Reads data/secondary/.
#
# module "uc_secondary" {
#   source    = "./modules/uc"
#   providers = { databricks = databricks.secondary }
#
#   catalogs            = try(local.inventory["secondary"].catalogs, {})
#   schemas             = try(local.inventory["secondary"].schemas, {})
#   volumes             = try(local.inventory["secondary"].volumes, {})
#   storage_credentials = try(local.inventory["secondary"].storage_credentials, {})
#   external_locations  = try(local.inventory["secondary"].external_locations, {})
#   connections         = try(local.inventory["secondary"].connections, {})
#   workspace_bindings  = try(local.inventory["secondary"].workspace_bindings, {})
#   grants              = try(local.inventory["secondary"].grants, {})
# }
