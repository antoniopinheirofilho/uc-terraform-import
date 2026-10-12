# Derive structured fields from the map keys so tfvars entries stay minimal.
# Assumes UC object names do not contain "." (standard for unquoted identifiers).

locals {
  # "catalog.schema" -> components
  schemas = {
    for k, v in var.schemas : k => {
      catalog = split(".", k)[0]
      name    = split(".", k)[1]
      owner   = v.owner
      comment = v.comment
    }
  }

  # "catalog.schema.volume" -> components
  volumes = {
    for k, v in var.volumes : k => {
      catalog     = split(".", k)[0]
      schema      = split(".", k)[1]
      name        = split(".", k)[2]
      owner       = v.owner
      comment     = v.comment
      volume_type = v.volume_type
    }
  }

  # "<securable_type>/<full_name>" -> type + securable (the key is also the import ID)
  grants = {
    for k, v in var.grants : k => {
      securable_type = split("/", k)[0]
      securable      = trimprefix(k, "${split("/", k)[0]}/")
      grants         = v.grants
    }
  }
}
