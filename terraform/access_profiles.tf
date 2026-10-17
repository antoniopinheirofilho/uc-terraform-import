# Access profiles — the governance vocabulary for grants.
#
# An access profile is a named, securable-type-aware bundle of UC privileges. In the
# grant YAML a principal references a profile by name (e.g. access: [READ_ACCESS])
# instead of listing raw privileges, which keeps the data readable and stops people
# copy-pasting privilege sets they don't understand. The resolver (modules/uc) picks the
# privilege list for the grant's securable type (catalog / schema / volume / ...).
#
# This is governed, stable vocabulary — change it deliberately via PR. It is generic
# (no customer identifiers), so it is committed. The grant YAML is the high-churn data;
# this is not.
#
# Shape: profile_name => { securable_type => [UC privileges] }. A profile need only
# define the securable types it applies to; referencing a profile on a type it does not
# define fails the plan (see modules/uc/grants.tf precondition). The sets below are a
# starting point — adapt them to your governance model.

locals {
  access_profiles = {
    READ_ACCESS = {
      catalog           = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
      schema            = ["USE_SCHEMA", "SELECT"]
      volume            = ["READ_VOLUME"]
      external_location = ["READ_FILES"]
    }

    WRITE_ACCESS = {
      catalog           = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "MODIFY"]
      schema            = ["USE_SCHEMA", "SELECT", "MODIFY"]
      volume            = ["READ_VOLUME", "WRITE_VOLUME"]
      external_location = ["READ_FILES", "WRITE_FILES"]
    }
  }
}
