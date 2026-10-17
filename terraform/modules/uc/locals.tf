# Derive structured fields from map keys so tfvars entries stay minimal.
# Assumes UC object names do not contain "." (standard for unquoted identifiers).

locals {
  schemas = {
    for k, v in var.schemas : k => {
      catalog = split(".", k)[0]
      name    = split(".", k)[1]
      owner   = v.owner
      comment = v.comment
    }
  }

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

  # "<securable_type>/<full_name>" -> type + securable (key is also the import ID).
  # Each grant's effective privileges are resolved here: raw `privileges` pass through;
  # `access` aliases expand to the union of their privilege lists FOR THIS securable
  # type (unknown alias or unsupported type -> empty, caught by the grants precondition).
  grants = {
    for k, v in var.grants : k => {
      securable_type = split("/", k)[0]
      securable      = trimprefix(k, "${split("/", k)[0]}/")
      grants = [
        for g in v.grants : {
          principal = g.principal
          privileges = g.privileges != null ? g.privileges : sort(distinct(flatten([
            for a in coalesce(g.access, []) :
            lookup(lookup(var.access_profiles, a, {}), split("/", k)[0], [])
          ])))
        }
      ]
    }
  }
}
