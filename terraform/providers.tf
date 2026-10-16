# WORKSPACE-LEVEL layer. METASTORE ADMIN is sufficient — no account admin needed.
# All UC object management (catalogs, schemas, grants, etc.) goes through a workspace
# Unity Catalog API, so each run routes through a workspace. Workspace bindings gate
# what a given workspace can see, so one provider alias is declared per workspace you
# need to route through — all writing to a SINGLE Terraform state.
#
# Terraform limitation: provider aliases and the module `providers` mapping cannot be
# generated dynamically (no for_each over providers). So adding a workspace means
# copying one provider block here + one module block in main.tf + its import blocks in
# imports.tf. The object inventory itself stays data-driven (YAML, no HCL edits).

provider "databricks" {
  alias   = "primary"
  host    = var.workspace_connections["primary"].host
  profile = var.workspace_connections["primary"].profile # null => environment auth
}

# To route through additional workspaces (e.g. for catalogs ISOLATED to them), copy the
# block above with a new alias and a matching key in var.workspace_connections, then add
# the corresponding module instance (main.tf) and import blocks (imports.tf), and place
# that workspace's YAML under data/<alias>/.
#
# provider "databricks" {
#   alias   = "secondary"
#   host    = var.workspace_connections["secondary"].host
#   profile = var.workspace_connections["secondary"].profile
# }
