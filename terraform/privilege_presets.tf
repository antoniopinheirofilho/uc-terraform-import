# Privilege presets — the governance vocabulary for grants.
#
# A privilege preset is a named, securable-type-aware bundle of UC privileges. In the
# grant YAML a principal references a preset by name (e.g. presets: [DATA_READER])
# instead of listing raw privileges, which keeps the data readable and stops people
# copy-pasting privilege sets they don't understand. The resolver (modules/uc) picks the
# privilege list for the grant's securable type (catalog / schema / volume / ...).
#
# These mirror the Databricks Catalog Explorer "Privilege presets" (Data Reader / Data
# Editor). Those presets are a UI convenience that ticks a bundle of individual
# privileges — there is no grantable "preset" object, so Terraform must list the raw
# privileges. These reproduce that bundle in version-controlled, reviewable form. The
# catalog/schema sets match the documented presets exactly; volume and external_location
# carry the applicable read / read+write privileges (the UI preset likewise only selects
# privileges valid for the chosen securable).
#
#   Data Reader  = read-only
#   Data Editor  = read + modify
#
# This is governed, stable vocabulary — change it deliberately via PR. It is generic
# (no customer identifiers), so it is committed. The grant YAML is the high-churn data.
# Add your own presets here as needed (e.g. DATA_ADMIN); a grant referencing a preset
# with no entry for its securable type fails the plan (see modules/uc/grants.tf).

locals {
  privilege_presets = {
    # Databricks "Data Reader" preset — read-only.
    DATA_READER = {
      catalog           = ["USE_CATALOG", "USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
      schema            = ["USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
      volume            = ["READ_VOLUME"]
      external_location = ["READ_FILES"]
    }

    # Databricks "Data Editor" preset — read + modify (Data Reader + modify privileges).
    DATA_EDITOR = {
      catalog           = ["USE_CATALOG", "USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT", "APPLY_TAG", "MODIFY", "REFRESH", "WRITE_VOLUME"]
      schema            = ["USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT", "APPLY_TAG", "MODIFY", "REFRESH", "WRITE_VOLUME"]
      volume            = ["READ_VOLUME", "WRITE_VOLUME"]
      external_location = ["READ_FILES", "WRITE_FILES"]
    }
  }
}
