# Typed inputs for the Unity Catalog objects. The root module reads the YAML data
# tree and passes it in here, so these type constraints validate the decoded data
# (missing/mistyped/unknown fields fail the plan).
#
# Every object type carries an optional `import_id` that gates per-object importing
# (see the root imports.tf): set it to import an existing object, omit it to create.

# key = catalog name
variable "catalogs" {
  type = map(object({
    owner          = optional(string)
    comment        = optional(string)
    storage_root   = optional(string)
    isolation_mode = optional(string) # "OPEN" (default) or "ISOLATED"
    import_id      = optional(string) # = catalog name
  }))
  default = {}
}

# key = "catalog.schema"
variable "schemas" {
  type = map(object({
    owner     = optional(string)
    comment   = optional(string)
    import_id = optional(string) # = "catalog.schema"
  }))
  default = {}
}

# key = "catalog.schema.volume"
variable "volumes" {
  type = map(object({
    owner       = optional(string)
    comment     = optional(string)
    volume_type = optional(string, "MANAGED")
    import_id   = optional(string) # = "catalog.schema.volume"
  }))
  default = {}
}

# key = storage credential name
variable "storage_credentials" {
  type = map(object({
    owner          = optional(string)
    comment        = optional(string)
    role_arn       = string
    isolation_mode = optional(string)
    import_id      = optional(string) # = name
  }))
  default = {}
}

# key = external location name
variable "external_locations" {
  type = map(object({
    owner           = optional(string)
    comment         = optional(string)
    url             = string
    credential_name = string
    isolation_mode  = optional(string)
    import_id       = optional(string) # = name
  }))
  default = {}
}

# key = connection name
variable "connections" {
  type = map(object({
    connection_type = string
    owner           = optional(string)
    options         = map(string)
    import_id       = optional(string) # = "<metastore_id>|<name>"
  }))
  default = {}
}

# key = free label
variable "workspace_bindings" {
  type = map(object({
    securable_type = string # catalog | external_location | storage_credential | credential
    securable_name = string
    workspace_id   = string
    binding_type   = optional(string, "BINDING_TYPE_READ_WRITE")
    import_id      = optional(string) # = "<securable_type>|<securable_name>|<workspace_id>"
  }))
  default = {}
}

# key = "<securable_type>/<full_name>"
variable "grants" {
  type = map(object({
    grants = list(object({
      principal  = string
      privileges = list(string)
    }))
    import_id = optional(string) # = the key, "<securable_type>/<full_name>"
  }))
  default = {}
}
