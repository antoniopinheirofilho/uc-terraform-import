# Unity Catalog → Terraform: Import Baseline & Runbook

Bring existing, manually-created Unity Catalog (UC) objects under Terraform management
**without recreating anything**.

**Goal of every step:** after import, `terraform plan` reports **no changes**.

- Databricks-side only — AWS/cloud resources are assumed to already exist.
- Grants are **authoritative**: `databricks_grants` revokes any privilege not in
  config. Snapshots must be complete. See [§5](#5-reconcile-and-clean).

## What this template supports / doesn't

### Supports
- **Importing (adopting) existing workspace-level UC objects** into Terraform with a
  clean no-op plan — not creating them from scratch (though the same config also
  creates them once import blocks are removed; see [§8](#8-scaling--data-driven-model)):
  catalogs, schemas, volumes, external locations, storage credentials, connections,
  **workspace bindings**, and **grants + ownership** (including metastore-level grants).
- **Data-driven scaling** — objects are map entries in `terraform.tfvars`, not
  hand-written HCL; `for_each` import blocks are generated from the same maps.
- **Authoritative grants** per securable (`databricks_grants`), with `owner` captured.
- **Isolated securables** via `isolation_mode` + `databricks_workspace_binding`.
- **AWS** storage credentials (IAM role, self-assuming UC role pattern).
- **Any auth that the Databricks provider accepts** — CLI profile (dev) or service
  principal via env vars (HCP/CI).

### Does NOT support (in this version)
- **The metastore object and workspace assignments** (`databricks_metastore`,
  `databricks_metastore_assignment`) — account-level, assumed to already exist and
  managed outside Terraform. Add later as an account-admin layer ([§9](#9-adding-the-account-layer-later)).
- **Tables, views, materialized views, functions, registered models** — data objects
  are not managed (manage their containers + grants instead).
- **Delta Sharing** shares/recipients/providers, and **system schemas / Lakehouse
  Federation foreign catalogs** beyond the plain `connection` object.
- **Azure / GCP storage credentials** — only `aws_iam_role` is wired in; Azure
  (`azure_managed_identity`) / GCP variants would need to be added.
- **Secret values** (connection `bearer_token`, credential keys) — write-only, not
  stored or managed; set out-of-band.
- **Creating the underlying cloud infrastructure** (S3 buckets, IAM roles, workspaces)
  — Databricks-side only; cloud resources are assumed to exist.
- **Non-metastore-admin discovery** — a caller without metastore admin only sees their
  own workspace's objects and must run the exporter per-workspace ([§4a](#4a-resource-exporter-primary)).

### Assumptions
- **Metastore admin + workspace-level OAuth** (no account admin required).
- The target metastore and the workspace you connect to already exist and are assigned.
- Terraform **≥ 1.7**, Databricks provider **≥ 1.59**.

---

## 0. In-scope objects

| Object | Resource |
| --- | --- |
| Catalog | `databricks_catalog` |
| Schema | `databricks_schema` |
| Volume | `databricks_volume` |
| External location | `databricks_external_location` |
| Storage credential | `databricks_storage_credential` |
| Connection | `databricks_connection` |
| Workspace binding | `databricks_workspace_binding` |
| Grants / ownership | `databricks_grants` (+ `owner`) — incl. metastore-level grants |

Tables/views are not managed by Terraform. The metastore object and its workspace
assignments are out of scope in this version.

---

## 1. Prerequisites

- Terraform ≥ 1.7 (`for_each` in `import {}` blocks); Databricks CLI.
- **Metastore admin**, in a workspace assigned to the target metastore.

**Auth** — local dev uses a workspace CLI profile:

```bash
databricks auth login --host https://<workspace-host> --profile my-workspace
```

Set `databricks_workspace_profile` in `terraform.tfvars`. For HCP/CI, leave it null
and use a service principal: `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET`.

The config needs the metastore ID (for connection import IDs and metastore-level grant
keys). Get it read-only as a metastore admin:

```bash
databricks metastores summary -p my-workspace -o json   # returns metastore_id, name, region
```

---

## 2. Layout

```
terraform/
├── versions.tf providers.tf variables.tf locals.tf
├── catalogs.tf schemas.tf volumes.tf
├── external_locations.tf storage_credentials.tf connections.tf
├── bindings.tf grants.tf imports.tf
└── terraform.tfvars.example
```

Backend ships unset (local state). **Configure remote state (e.g. HCP Terraform) in
`versions.tf` before running against the real metastore.**

---

## 3. Workflow

```
4. DISCOVER → 5. RECONCILE/CLEAN → 6. IMPORT (plan→0) → 7. VERIFY
```

**Never `apply` exporter output without reviewing `plan`.** The exporter is a
starting point, not a safe-to-apply artifact.

---

## 4. Extract the snapshot (discovery)

### 4a. Resource Exporter (primary)

Extract the snapshot with the provider's experimental **Resource Exporter**, run with
`-native-import` to emit import blocks with correct IDs. Run it as a **metastore
admin** against a workspace assigned to the metastore:

```bash
cd terraform
terraform init
BIN="$PWD/$(find .terraform/providers -name 'terraform-provider-databricks*' -type f | head -1)"

UC="uc-catalogs,uc-schemas,uc-volumes,uc-connections,uc-storage-credentials,uc-external-locations,uc-grants"
DATABRICKS_CONFIG_PROFILE=my-workspace "$BIN" exporter \
  -directory="../exporter-output" -listing="$UC" -services="$UC" \
  -native-import -generateProviderDeclaration=false
```

Scope with `-match` / `-matchRegex`. Output: `uc-*.tf`, `import.tf`, `import.sh`.
(`uc-metastores` is omitted — the metastore object is out of scope in this version.)

**One workspace is enough.** A metastore admin sees every securable in the metastore
from a single attached workspace — including `ISOLATED` ones bound to *other*
workspaces. (Verified: from an unbound workspace, an isolated catalog is hidden in the
default list but appears with `--include-unbound`, and `get-bindings` returns all
bound workspace IDs.) You do **not** need to run the exporter in every workspace.
*Exception:* a non-metastore-admin only sees what their workspace can access, so they
must run per-workspace and merge with the exporter's `-prefix`.

### 4b. CLI/SDK cross-check (find gaps)

Build an independent inventory (all read-only) and diff it against the export:

```bash
databricks metastores summary -p my-workspace -o json             # metastore id/name/region
databricks catalogs list --include-unbound -p my-workspace -o json
databricks external-locations list -p my-workspace -o json
databricks storage-credentials list -p my-workspace -o json
databricks connections list -p my-workspace -o json
databricks workspace-bindings get-bindings <securable_type> <name> -p my-workspace -o json
databricks grants get <securable_type> <full_name> -p my-workspace -o json
```

Every object must end up either managed+imported or consciously excluded.

---

## 5. Reconcile and clean

Fold exporter output into `terraform/` and apply these corrections (each was required
for a clean no-op):

1. **Complete every grants block.** Include all live privileges — system defaults
   (e.g. `account users → USE_MARKETPLACE_ASSETS`) and implicit creator grants.
   **Drop grants the exporter invented but that aren't live** (seen in practice; the
   live `plan` is the source of truth). Metastore-level grants (`metastore/<id>`) are
   managed here too — a metastore admin can administer them.
2. **Strip system `properties`** on catalogs/schemas (`collation`, `owner="root"`):
   `lifecycle { ignore_changes = [properties] }` (already in the resources).
3. **Secrets aren't exported** (connection `bearer_token`, credential keys). If a plan
   shows secret drift, supply via variable or `ignore_changes = [options]`.
4. **Bindings:** for every `ISOLATED` securable set `isolation_mode = "ISOLATED"` and
   add its `workspace_bindings` entries, so the bindings are managed too.
5. **Exclude system objects**: `information_schema`, auto-created `default` schemas,
   the Databricks-managed Default Storage external location + its auto-grant.
6. **Set `owner`** on each resource to the live value.

### Import ID formats

| Resource | ID |
| --- | --- |
| `databricks_catalog` | `<catalog>` |
| `databricks_schema` | `<catalog>.<schema>` |
| `databricks_volume` | `<catalog>.<schema>.<volume>` |
| `databricks_connection` | `<metastore_id>\|<name>` |
| `databricks_external_location` | `<name>` |
| `databricks_storage_credential` | `<name>` |
| `databricks_workspace_binding` | `<securable_type>\|<securable_name>\|<workspace_id>` |
| `databricks_grants` | `<securable_type>/<full_name>` (e.g. `catalog/<name>`, `schema/<cat.schema>`, `metastore/<metastore_id>`, `external_location/<name>`) |

When unsure, use the IDs in the exporter's `import.tf`.

---

## 6. Import safely

```bash
cd terraform
terraform init             # with remote backend configured
terraform plan             # read every line
```

Iterate §5 until the plan reads exactly:

```
Plan: N to import, 0 to add, 0 to change, 0 to destroy.
```

- `to change` / `to destroy` **must be 0** — anything else means config ≠ reality; fix it.
- A `databricks_grants` block that removes a `grant {}` = a **revoke**. Add the missing grant.

Get sign-off, then `terraform apply` (adopts into state; 0 changes to Databricks).
Import blocks are idempotent. Discovery (§4) is **read-only** — the first and only
operation that writes anything is `apply`, and on a clean plan it writes only to
Terraform state, not to Databricks.

---

## 7. Verify

```bash
terraform plan        # "No changes. Your infrastructure matches the configuration."
terraform state list  # count == imported objects
```

Reconcile `state list` against the §4b inventory. Document any exclusions. Import
blocks can then be removed (resources stay managed) or left in place.

---

## 8. Scaling — data-driven model

The baseline is **data-driven**: every object type is a single `for_each` resource fed
by a map in `terraform.tfvars`. Adding/removing an object is a one-line map edit, not
new HCL. Map keys are the natural identifiers and double as import IDs.

- `catalogs` — key = catalog name
- `schemas` — key = `catalog.schema`
- `volumes` — key = `catalog.schema.volume`
- `storage_credentials`, `external_locations`, `connections` — key = name
- `workspace_bindings` — one entry per (securable, workspace)
- `grants` — key = `<securable_type>/<full_name>` (also the import ID)

`imports.tf` uses `for_each` over the same maps, so the inventory you build in §4
drives both resources and imports.

**Two phases:**
1. **Adoption** — `imports.tf` present; each map entry must correspond to an existing
   object. `apply` imports them (0 changes).
2. **Day-2 management** — remove `imports.tf`. The maps are now desired state: adding
   an entry **creates** the object, removing one **destroys** it.

Keep `grants` entries complete per securable — authoritative management means a
missing privilege is a revoke.

---

## 9. Adding the account layer later

The metastore object and workspace assignments are account-level (account admin). To
bring them under Terraform later, add a separate root with its own state and an
account-level provider:

```hcl
provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}

resource "databricks_metastore" "this" { /* name, region, owner; import id = <metastore_id> */ }
resource "databricks_metastore_assignment" "this" {
  for_each     = toset(var.assigned_workspace_ids)
  workspace_id = each.key
  metastore_id = databricks_metastore.this.id
  # import id = "<workspace_id>|<metastore_id>"
}
```

Keep it as its own state so the account-admin lifecycle stays separate from this
metastore-admin workspace layer.

---

## 10. Safety & publishing

- **Never commit:** state, real `*.tfvars`, `.databrickscfg`, secrets, raw exporter
  output. `.gitignore` enforces this.
- Commit only `*.tfvars.example` and sanitized identifiers.
- Before publishing, scrub metastore/workspace IDs, bucket paths, IdP group names,
  connection hosts/tokens.
- Apply authoritative grants during a change window.
