# Unity Catalog → Terraform: Import Baseline & Runbook

Bring an existing, manually-created Unity Catalog (UC) metastore and its objects
under Terraform management **without recreating anything**.

**Goal of every step:** after import, `terraform plan` reports **no changes**.

- Databricks-side only — AWS/cloud resources are assumed to already exist.
- Grants are **authoritative**: `databricks_grants` revokes any privilege not in
  config. Snapshots must be complete. See [§5](#5-reconcile-and-clean).

## Two layers, by admin level

The baseline is split by the privilege each part needs:

| Layer (`terraform/…`) | Manages | Needs | Auth |
| --- | --- | --- | --- |
| **`workspace/`** | catalogs, schemas, volumes, external locations, storage credentials, connections, **bindings**, grants (incl. metastore-level grants) | **metastore admin** | workspace-level OAuth |
| **`account/`** | the metastore object + workspace assignments | **account admin** | account-level API |

**The default assumption of this guide is workspace-level OAuth with metastore
admin.** That covers everything in `workspace/` — the bulk of the work. The two
`account/` resources are the *only* things that require an account admin; if you
don't have that, you develop and import the `workspace/` layer independently and hand
the `account/` layer to an account admin (or add it later). Each layer has its own
state.

---

## 0. In-scope objects

| Object | Resource | Layer |
| --- | --- | --- |
| Metastore | `databricks_metastore` | account |
| Metastore assignment | `databricks_metastore_assignment` | account |
| Catalog | `databricks_catalog` | workspace |
| Schema | `databricks_schema` | workspace |
| Volume | `databricks_volume` | workspace |
| External location | `databricks_external_location` | workspace |
| Storage credential | `databricks_storage_credential` | workspace |
| Connection | `databricks_connection` | workspace |
| Workspace binding | `databricks_workspace_binding` | workspace |
| Grants / ownership | `databricks_grants` (+ `owner`) | workspace |

Tables/views are not managed by Terraform.

---

## 1. Prerequisites

- Terraform ≥ 1.7 (`for_each` in `import {}` blocks); Databricks CLI.
- **Workspace layer:** metastore admin, in a workspace assigned to the target
  metastore. **Account layer:** account admin.

**Auth** — local dev uses CLI profiles:

```bash
# workspace layer (metastore admin)
databricks auth login --host https://<workspace-host> --profile my-workspace
# account layer (account admin) — only if you run it
databricks auth login --host https://accounts.cloud.databricks.com --account-id <ID> --profile my-account
```

Set `databricks_workspace_profile` (and `databricks_account_profile` for the account
layer) in each layer's `terraform.tfvars`. For HCP/CI, leave them null and use a
service principal: `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET`.

The workspace layer needs the metastore ID (for connection import IDs and
metastore-level grant keys). Get it read-only as a metastore admin:

```bash
databricks metastores summary -p my-workspace -o json   # returns metastore_id, name, region
```

---

## 2. Layout

```
terraform/
├── account/     # metastore + assignment        (account admin)
│   ├── versions.tf providers.tf variables.tf
│   ├── metastore.tf imports.tf terraform.tfvars.example
└── workspace/   # everything else               (metastore admin)
    ├── versions.tf providers.tf variables.tf locals.tf
    ├── catalogs.tf schemas.tf volumes.tf
    ├── external_locations.tf storage_credentials.tf connections.tf
    ├── bindings.tf grants.tf imports.tf terraform.tfvars.example
```

Backends ship unset (local state). **Configure remote state (e.g. HCP Terraform) in
each layer's `versions.tf` before running against the real metastore.**

---

## 3. Workflow (per layer)

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
cd terraform/workspace
terraform init
BIN="$PWD/$(find .terraform/providers -name 'terraform-provider-databricks*' -type f | head -1)"

UC="uc-catalogs,uc-schemas,uc-volumes,uc-connections,uc-storage-credentials,uc-external-locations,uc-grants"
DATABRICKS_CONFIG_PROFILE=my-workspace "$BIN" exporter \
  -directory="../../exporter-output" -listing="$UC" -services="$UC" \
  -native-import -generateProviderDeclaration=false
```

Scope with `-match` / `-matchRegex`. Output: `uc-*.tf`, `import.tf`, `import.sh`.
(Drop `uc-metastores` — the metastore object is the account layer, authored by hand.)

**One workspace is enough.** A metastore admin sees every securable in the metastore
from a single attached workspace — including `ISOLATED` ones bound to *other*
workspaces. (Verified: from an unbound workspace, an isolated catalog is hidden in the
default list but appears with `--include-unbound`, and `get-bindings` returns all
bound workspace IDs.) You do **not** need to run the exporter in every workspace.
*Exception:* a non-metastore-admin only sees what their workspace can access, so they
must run per-workspace and merge with the exporter's `-prefix`.

### 4b. CLI/SDK cross-check (find gaps)

The exporter **misses account-level objects** (the metastore itself, assignments,
metastore-level grants). Build an independent inventory and diff it:

```bash
# workspace layer (metastore admin):
databricks metastores summary -p my-workspace -o json             # metastore id/name/region
databricks catalogs list --include-unbound -p my-workspace -o json
databricks external-locations list -p my-workspace -o json
databricks storage-credentials list -p my-workspace -o json
databricks connections list -p my-workspace -o json
databricks workspace-bindings get-bindings <securable_type> <name> -p my-workspace -o json
databricks grants get <securable_type> <full_name> -p my-workspace -o json

# account layer (account admin only — these 403 without it):
databricks account metastores get <METASTORE_ID> -p my-account -o json
databricks account metastore-assignments list <METASTORE_ID> -p my-account -o json
```

Every object must end up either managed+imported or consciously excluded.

---

## 5. Reconcile and clean

Fold exporter output into `terraform/workspace/` and apply these corrections (each was
required for a clean no-op):

1. **Author the metastore-level `databricks_grants` by hand** if the exporter missed
   it (it's a `grants` map entry keyed `metastore/<id>` — managed in the workspace
   layer by a metastore admin). The metastore object + assignments live in the
   `account/` layer.
2. **Complete every grants block.** Include all live privileges — system defaults
   (e.g. `account users → USE_MARKETPLACE_ASSETS`) and implicit creator grants.
   **Drop grants the exporter invented but that aren't live** (seen in practice; the
   live `plan` is the source of truth).
3. **Strip system `properties`** on catalogs/schemas (`collation`, `owner="root"`):
   `lifecycle { ignore_changes = [properties] }` (already in the resources).
4. **Ignore provider-defaulted metastore fields** (account layer):
   `lifecycle { ignore_changes = [delta_sharing_recipient_token_lifetime_in_seconds] }`.
5. **Secrets aren't exported** (connection `bearer_token`, credential keys). If a plan
   shows secret drift, supply via variable or `ignore_changes = [options]`.
6. **Bindings:** for every `ISOLATED` securable set `isolation_mode = "ISOLATED"` and
   add its `workspace_bindings` entries, so the bindings are managed too.
7. **Exclude system objects**: `information_schema`, auto-created `default` schemas,
   the Databricks-managed Default Storage external location + its auto-grant.
8. **Set `owner`** on each resource to the live value.

### Import ID formats

| Resource | ID |
| --- | --- |
| `databricks_metastore` | `<metastore_id>` |
| `databricks_metastore_assignment` | `<workspace_id>\|<metastore_id>` |
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

## 6. Import safely (run per layer)

```bash
cd terraform/workspace     # (or terraform/account)
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
Import blocks are idempotent. The discovery/import steps (§4) are **read-only** — the
first and only operation that writes anything is `apply`, and on a clean plan it
writes only to Terraform state, not to Databricks.

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

The workspace layer is **data-driven**: every object type is a single `for_each`
resource fed by a map in `terraform.tfvars`. Adding/removing an object is a one-line
map edit, not new HCL. Map keys are the natural identifiers and double as import IDs.

- `catalogs` — key = catalog name
- `schemas` — key = `catalog.schema`
- `volumes` — key = `catalog.schema.volume`
- `storage_credentials`, `external_locations`, `connections` — key = name
- `workspace_bindings` — one entry per (securable, workspace)
- `grants` — key = `<securable_type>/<full_name>` (also the import ID), e.g.
  `catalog/my_cat`, `schema/my_cat.my_schema`, `metastore/<id>`,
  `external_location/my_el`, `foreign_connection/my_conn`

`imports.tf` uses `for_each` over the same maps, so the inventory you build in §4
drives both resources and imports. Generate the map entries from the §4b inventory
(exporter output or a script over CLI/SDK JSON) and batch discovery with `-match`.

**Two phases:**
1. **Adoption** — `imports.tf` present; each map entry must correspond to an existing
   object. `apply` imports them (0 changes).
2. **Day-2 management** — remove `imports.tf`. The maps are now desired state: adding
   an entry **creates** the object, removing one **destroys** it. (Validated: adding
   one schema entry plans as `1 to add`.)

Keep `grants` entries complete per securable — authoritative management means a
missing privilege is a revoke.

---

## 9. Safety & publishing

- **Never commit:** state, real `*.tfvars`, `.databrickscfg`, secrets, raw exporter
  output. `.gitignore` enforces this.
- Commit only `*.tfvars.example` and sanitized identifiers.
- Before publishing, scrub account/metastore/workspace IDs, bucket paths, IdP group
  names, connection hosts/tokens.
- Apply authoritative grants during a change window.
