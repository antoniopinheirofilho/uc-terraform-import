variable "databricks_account_host" {
  description = "Databricks account console host."
  type        = string
  default     = "https://accounts.cloud.databricks.com"
}

variable "databricks_account_id" {
  description = "Databricks account ID (UUID)."
  type        = string
}

variable "databricks_account_profile" {
  description = "CLI profile for account-level auth (local dev). Null => environment auth (HCP/CI)."
  type        = string
  default     = null
}

variable "metastore_id" {
  description = "Existing metastore ID (used as the import ID)."
  type        = string
}

variable "metastore_name" {
  description = "Unity Catalog metastore name."
  type        = string
}

variable "metastore_region" {
  description = "Cloud region of the metastore."
  type        = string
}

variable "metastore_owner" {
  description = "Metastore owner principal."
  type        = string
}

variable "assigned_workspace_ids" {
  description = "Workspace IDs assigned to the metastore."
  type        = list(string)
}
