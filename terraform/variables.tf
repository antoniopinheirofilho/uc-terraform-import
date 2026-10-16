# Root inputs: workspace connections only. The object inventory is NOT passed as
# variables — it is read from the YAML data tree (see data.tf).
#
# One Terraform state can manage a whole metastore even when catalogs are ISOLATED to
# different workspaces: declare one connection per workspace you route through, and the
# matching provider alias + module instance (providers.tf / main.tf) manage the objects
# that workspace can reach. `primary` is the default/only connection for the common
# single-workspace case.

variable "workspace_connections" {
  description = "Databricks workspace connections keyed by routing name (e.g. \"primary\"). host = workspace URL; profile = local-dev CLI profile (null => environment auth / service principal)."
  type = map(object({
    host    = string
    profile = optional(string)
  }))
}
