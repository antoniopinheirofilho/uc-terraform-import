# Environment: DEV — routes all UC objects under data/dev/ through the
# dev workspace, in the SINGLE shared state. Catalogs ISOLATED to this workspace
# must be managed here (bindings gate visibility); OPEN catalogs may be managed from any
# environment. To add an environment, copy this file and swap "dev" + add its
# data/<env>/ folder and a workspace_connections entry. To remove one, delete this file,
# its data folder, and its connection entry.

provider "databricks" {
  alias   = "dev"
  host    = var.workspace_connections["dev"].host
  profile = var.workspace_connections["dev"].profile # null => environment auth
}

module "uc_dev" {
  source    = "./modules/uc"
  providers = { databricks = databricks.dev }

  access_profiles     = local.access_profiles
  catalogs            = try(local.inventory["dev"].catalogs, {})
  schemas             = try(local.inventory["dev"].schemas, {})
  volumes             = try(local.inventory["dev"].volumes, {})
  storage_credentials = try(local.inventory["dev"].storage_credentials, {})
  external_locations  = try(local.inventory["dev"].external_locations, {})
  connections         = try(local.inventory["dev"].connections, {})
  workspace_bindings  = try(local.inventory["dev"].workspace_bindings, {})
  grants              = try(local.inventory["dev"].grants, {})
}

import {
  for_each = try(local._import["dev"].catalogs, {})
  to       = module.uc_dev.databricks_catalog.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].schemas, {})
  to       = module.uc_dev.databricks_schema.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].volumes, {})
  to       = module.uc_dev.databricks_volume.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].storage_credentials, {})
  to       = module.uc_dev.databricks_storage_credential.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].external_locations, {})
  to       = module.uc_dev.databricks_external_location.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].connections, {})
  to       = module.uc_dev.databricks_connection.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].workspace_bindings, {})
  to       = module.uc_dev.databricks_workspace_binding.this[each.key]
  id       = each.value
}
import {
  for_each = try(local._import["dev"].grants, {})
  to       = module.uc_dev.databricks_grants.this[each.key]
  id       = each.value
}
