# UC storage credentials (AWS IAM role, self-assuming UC role pattern).
# The IAM roles are assumed to already exist (not managed here).

resource "databricks_storage_credential" "this" {
  for_each = var.storage_credentials

  name           = each.key
  owner          = each.value.owner
  comment        = each.value.comment
  isolation_mode = each.value.isolation_mode

  aws_iam_role {
    role_arn = each.value.role_arn
  }

  lifecycle {
    prevent_destroy = true
  }
}
