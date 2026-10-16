# Read the YAML data tree, keyed by workspace routing name:
#
#   data/<workspace>/<type>/*.yaml
#
# e.g. data/primary/catalogs/finance.yaml. Each <type> folder may hold one or many
# YAML files; all files in a folder are merged into one map. Add an object = add/extend
# a YAML file under the right workspace+type folder; no HCL changes.
#
# local.inventory[<workspace>][<type>] is the merged map for that workspace+type, passed
# to that workspace's module instance (main.tf), where the typed module variables
# validate the decoded data. The leading {} seeds merge() so an empty folder yields {}.

locals {
  _data  = "${path.module}/data"
  _types = ["catalogs", "schemas", "volumes", "storage_credentials", "external_locations", "connections", "workspace_bindings", "grants"]

  # Routing workspaces = top-level folders under data/ that contain real *.yaml files.
  _workspaces = toset([for p in fileset(local._data, "*/*/*.yaml") : split("/", p)[0]])

  inventory = {
    for ws in local._workspaces : ws => {
      for t in local._types : t => merge(concat([{}], [
        for f in fileset("${local._data}/${ws}/${t}", "*.yaml") :
        yamldecode(file("${local._data}/${ws}/${t}/${f}"))
      ])...)
    }
  }
}
