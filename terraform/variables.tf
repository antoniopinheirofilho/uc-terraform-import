# Root inputs: workspace connections only. The object inventory is NOT passed as
# variables — it is read from the YAML data tree (see data.tf).
#
# One Terraform state manages the whole metastore even when catalogs are ISOLATED to
# different workspaces: declare one connection per environment/workspace you route
# through (keys here must match the env_<key>.tf files and the data/<key>/ folders).
# This template ships dev / sit / stg / prod as the worked example — all four workspaces
# attached to the same metastore, catalogs bound per environment.

variable "workspace_connections" {
  description = "Databricks workspace connections keyed by environment (dev/sit/stg/prod). Each key must match an env_<key>.tf and data/<key>/ folder. host = workspace URL; profile = local-dev CLI profile (null => environment auth / service principal)."
  type = map(object({
    host    = string
    profile = optional(string)
  }))
}
