variable "databricks_workspace_host" {
  description = "Workspace URL (a workspace assigned to the target metastore)."
  type        = string
}

variable "databricks_workspace_profile" {
  description = "CLI profile for workspace-level auth (local dev). Null => environment auth."
  type        = string
  default     = null
}

# ---- Data-driven object inventories (add an object = add a map entry) ----
#
# Every object type carries an optional `import_id`. It gates per-object importing:
#   - import_id set   => imports.tf imports the existing object using that exact ID.
#   - import_id null  => the object is NOT imported (it would be created on apply).
# imports.tf is permanent; you control adoption by setting/removing import_id, not by
# deleting the file. For most types import_id equals the map key; connections and
# bindings use a composite ID (see the examples / README import-ID table).

# key = catalog name
variable "catalogs" {
  description = "Catalogs. Key = catalog name."
  type = map(object({
    owner          = optional(string)
    comment        = optional(string)
    storage_root   = optional(string)
    isolation_mode = optional(string) # "OPEN" (default) or "ISOLATED"
    import_id      = optional(string) # set to import an existing catalog (= catalog name)
  }))
  default = {}
}

# key = "catalog.schema"
variable "schemas" {
  description = "Schemas. Key = \"catalog.schema\"."
  type = map(object({
    owner     = optional(string)
    comment   = optional(string)
    import_id = optional(string) # set to import (= "catalog.schema")
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
    import_id   = optional(string) # set to import (= "catalog.schema.volume")
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
    import_id      = optional(string) # set to import (= name)
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
    import_id       = optional(string) # set to import (= name)
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
    import_id       = optional(string) # set to import (= "<metastore_id>|<name>")
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
    import_id      = optional(string) # set to import (= "<securable_type>|<securable_name>|<workspace_id>")
  }))
  default = {}
}

# key = "<securable_type>/<full_name>" (parsed to pick the securable), e.g.
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
    import_id = optional(string) # set to import (= the key, "<securable_type>/<full_name>")
  }))
  default = {}
}
