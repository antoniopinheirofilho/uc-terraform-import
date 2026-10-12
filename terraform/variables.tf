variable "databricks_workspace_host" {
  description = "Workspace URL (a workspace assigned to the target metastore)."
  type        = string
}

variable "databricks_workspace_profile" {
  description = "CLI profile for workspace-level auth (local dev). Null => environment auth."
  type        = string
  default     = null
}

variable "metastore_id" {
  description = "Metastore ID — used for connection import IDs and metastore-level grant keys. Read it with `databricks metastores summary` (metastore admin, read-only)."
  type        = string
}

# ---- Data-driven object inventories (add an object = add a map entry) ----

# key = catalog name
variable "catalogs" {
  description = "Catalogs. Key = catalog name."
  type = map(object({
    owner          = optional(string)
    comment        = optional(string)
    storage_root   = optional(string)
    isolation_mode = optional(string) # "OPEN" (default) or "ISOLATED"
  }))
  default = {}
}

# key = "catalog.schema"
variable "schemas" {
  description = "Schemas. Key = \"catalog.schema\"."
  type = map(object({
    owner   = optional(string)
    comment = optional(string)
  }))
  default = {}
}

# key = "catalog.schema.volume"
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
    owner          = optional(string)
    comment        = optional(string)
    role_arn       = string
    isolation_mode = optional(string)
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
    isolation_mode  = optional(string)
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

# key = free label. Bindings for ISOLATED securables (catalog / external_location /
# storage_credential / credential). Set isolation_mode = "ISOLATED" on the securable
# above, then list its bound workspaces here.
variable "workspace_bindings" {
  description = "Workspace bindings for isolated securables."
  type = map(object({
    securable_type = string # catalog | external_location | storage_credential | credential
    securable_name = string
    workspace_id   = string
    binding_type   = optional(string, "BINDING_TYPE_READ_WRITE")
  }))
  default = {}
}

# key = "<securable_type>/<full_name>" (also the import ID), e.g.
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
