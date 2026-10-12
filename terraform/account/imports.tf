# Native import blocks (Terraform >= 1.7). Remove after the first clean adoption.

import {
  to = databricks_metastore.this
  id = var.metastore_id
}

import {
  for_each = toset(var.assigned_workspace_ids)
  to       = databricks_metastore_assignment.this[each.key]
  id       = "${each.key}|${var.metastore_id}"
}
