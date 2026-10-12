# WORKSPACE-LEVEL layer. METASTORE ADMIN is sufficient — no account admin needed.
# Auth is workspace-level OAuth (a workspace assigned to the target metastore).
# Everything here (catalogs, schemas, volumes, external locations, storage
# credentials, connections, workspace bindings, and grants — including
# metastore-level grants) is managed via the workspace Unity Catalog API.

provider "databricks" {
  host    = var.databricks_workspace_host
  profile = var.databricks_workspace_profile # null => environment auth
}
