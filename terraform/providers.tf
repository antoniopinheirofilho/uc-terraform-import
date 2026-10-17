# All workspace provider aliases — one per environment/workspace routed through, driven
# by var.workspace_connections. UC object management goes through a workspace API and
# workspace-catalog bindings gate what each workspace can see, so each environment gets
# its own alias; all of them write to a SINGLE Terraform state.
#
# This template ships dev / sit / stg / prod (four workspaces on one metastore). To add
# an environment: add a provider block here, a module instance in main.tf, its import
# blocks in imports.tf, a workspace_connections entry, and a data/<env>/ folder. To
# remove one, delete those. (Static because Terraform can't for_each over providers.)

provider "databricks" {
  alias   = "dev"
  host    = var.workspace_connections["dev"].host
  profile = var.workspace_connections["dev"].profile # null => environment auth
}

provider "databricks" {
  alias   = "sit"
  host    = var.workspace_connections["sit"].host
  profile = var.workspace_connections["sit"].profile
}

provider "databricks" {
  alias   = "stg"
  host    = var.workspace_connections["stg"].host
  profile = var.workspace_connections["stg"].profile
}

provider "databricks" {
  alias   = "prod"
  host    = var.workspace_connections["prod"].host
  profile = var.workspace_connections["prod"].profile
}
