# ---- Provider / connection wiring ----

variable "databricks_account_host" {
  description = "Databricks account console host."
  type        = string
  default     = "https://accounts.cloud.databricks.com"
}

variable "databricks_account_id" {
  description = "Databricks account ID (UUID). Do not hardcode in committed tfvars for a public repo."
  type        = string
}

variable "databricks_workspace_host" {
  description = "Workspace URL used for workspace-level Unity Catalog operations."
  type        = string
}

variable "databricks_account_profile" {
  description = "CLI profile for account-level auth (local dev). Null => environment auth (HCP/CI)."
  type        = string
  default     = null
}

variable "databricks_workspace_profile" {
  description = "CLI profile for workspace-level auth (local dev). Null => environment auth."
  type        = string
  default     = null
}

# ---- Metastore (singleton) ----

variable "metastore_id" {
  description = "Existing metastore ID (used for import IDs)."
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

# ---- Data-driven object inventories ----
# Add an object = add a map entry (no new HCL). Keys are the natural identifiers
# and double as import IDs.

# key = catalog name
variable "catalogs" {
  description = "Catalogs. Key = catalog name."
  type = map(object({
    owner          = optional(string)
    comment        = optional(string)
    storage_root   = optional(string)
    isolation_mode = optional(string)
  }))
  default = {}
}

# key = "<catalog>.<schema>"
variable "schemas" {
  description = "Schemas. Key = \"catalog.schema\"."
  type = map(object({
    owner   = optional(string)
    comment = optional(string)
  }))
  default = {}
}

# key = "<catalog>.<schema>.<volume>"
variable "volumes" {
  description = "Volumes. Key = \"catalog.schema.volume\"."
  type = map(object({
    owner       = optional(string)
    comment     = optional(string)
    volume_type = optional(string, "MANAGED")
  }))
  default = {}
}

# key = storage credential name
variable "storage_credentials" {
  description = "Storage credentials. Key = name."
  type = map(object({
    owner    = optional(string)
    comment  = optional(string)
    role_arn = string
  }))
  default = {}
}

# key = external location name
variable "external_locations" {
  description = "External locations. Key = name."
  type = map(object({
    owner           = optional(string)
    comment         = optional(string)
    url             = string
    credential_name = string
  }))
  default = {}
}

# key = connection name
variable "connections" {
  description = "Connections. Key = name. Secrets (e.g. bearer_token) are not stored here."
  type = map(object({
    connection_type = string
    owner           = optional(string)
    options         = map(string)
  }))
  default = {}
}

# key = "<securable_type>/<full_name>" (also the grants import ID), e.g.
#   "metastore/<metastore_id>", "catalog/my_cat", "schema/my_cat.my_schema",
#   "volume/my_cat.my_schema.my_vol", "external_location/my_el",
#   "storage_credential/my_sc", "foreign_connection/my_conn"
variable "grants" {
  description = "Authoritative grants per securable. Key = \"<securable_type>/<full_name>\"."
  type = map(object({
    grants = list(object({
      principal  = string
      privileges = list(string)
    }))
  }))
  default = {}
}
