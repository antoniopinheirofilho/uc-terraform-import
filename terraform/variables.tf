# Root inputs: provider/connection only. The object inventory is NOT passed as
# variables — it is read from the YAML data tree (see data.tf). Supply these two via
# provider.auto.tfvars (auto-loaded) or environment auth.

variable "databricks_workspace_host" {
  description = "Workspace URL (a workspace assigned to the target metastore)."
  type        = string
}

variable "databricks_workspace_profile" {
  description = "CLI profile for workspace-level auth (local dev). Null => environment auth."
  type        = string
  default     = null
}
