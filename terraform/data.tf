# Read the YAML data tree. Each resource type is a folder under data/; every *.yaml
# file in it is a map of entries (one or many per file — organize by domain/team as you
# like). All files in a folder are merged into one map. Add an object = add/extend a
# YAML file; no HCL changes. The merged maps are passed to the typed `uc` module
# (main.tf), where the type constraints validate them.
#
# The leading {} seeds merge() so an empty folder yields {} instead of an error.

locals {
  _data = "${path.module}/data"

  catalogs = merge(concat([{}], [
    for f in fileset("${local._data}/catalogs", "*.yaml") :
    yamldecode(file("${local._data}/catalogs/${f}"))
  ])...)

  schemas = merge(concat([{}], [
    for f in fileset("${local._data}/schemas", "*.yaml") :
    yamldecode(file("${local._data}/schemas/${f}"))
  ])...)

  volumes = merge(concat([{}], [
    for f in fileset("${local._data}/volumes", "*.yaml") :
    yamldecode(file("${local._data}/volumes/${f}"))
  ])...)

  storage_credentials = merge(concat([{}], [
    for f in fileset("${local._data}/storage_credentials", "*.yaml") :
    yamldecode(file("${local._data}/storage_credentials/${f}"))
  ])...)

  external_locations = merge(concat([{}], [
    for f in fileset("${local._data}/external_locations", "*.yaml") :
    yamldecode(file("${local._data}/external_locations/${f}"))
  ])...)

  connections = merge(concat([{}], [
    for f in fileset("${local._data}/connections", "*.yaml") :
    yamldecode(file("${local._data}/connections/${f}"))
  ])...)

  workspace_bindings = merge(concat([{}], [
    for f in fileset("${local._data}/workspace_bindings", "*.yaml") :
    yamldecode(file("${local._data}/workspace_bindings/${f}"))
  ])...)

  grants = merge(concat([{}], [
    for f in fileset("${local._data}/grants", "*.yaml") :
    yamldecode(file("${local._data}/grants/${f}"))
  ])...)
}
