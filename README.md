# Unity Catalog → Terraform: Import Baseline & Runbook

Bring an existing, manually-created Unity Catalog (UC) metastore and its objects
under Terraform management **without recreating anything**.

**Goal of every step:** after import, `terraform plan` reports **no changes**.

- Databricks-side only — AWS/cloud resources are assumed to already exist.
- Grants are **authoritative**: `databricks_grants` revokes any privilege not in
  config. Snapshots must be complete. See [§5](#5-reconcile-and-clean).

---

## 0. In-scope objects

| Object | Resource | Scope |
| --- | --- | --- |
| Metastore | `databricks_metastore` | account |
| Metastore assignment | `databricks_metastore_assignment` | account |
| Catalog | `databricks_catalog` | workspace |
| Schema | `databricks_schema` | workspace |
| Volume | `databricks_volume` | workspace |
| External location | `databricks_external_location` | workspace |
| Storage credential | `databricks_storage_credential` | workspace |
| Connection | `databricks_connection` | workspace |
| Grants / ownership | `databricks_grants` (+ `owner`) | workspace |

Tables/views are not managed by Terraform.

---

## 1. Prerequisites

- Terraform ≥ 1.5 (native `import {}` blocks); Databricks CLI.
- **Account admin** for metastore + assignments; **metastore admin** in a workspace
  assigned to the target metastore for the rest.
- Two providers (`terraform/providers.tf`): `databricks.account` (account console +
  `account_id`) and `databricks.workspace` (workspace URL).

**Auth** — local dev uses CLI profiles:

```bash
databricks auth login --host https://accounts.cloud.databricks.com --account-id <ID> --profile my-account
databricks auth login --host https://<workspace-host>                                 --profile my-workspace
```

Set `databricks_account_profile` / `databricks_workspace_profile` in `terraform.tfvars`.
For HCP/CI, leave those null and use a service principal:
`DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET`.

---

## 2. Layout

```
terraform/
├── versions.tf      # version constraints + backend (set HCP here)
├── providers.tf     # account + workspace providers
├── variables.tf     # inputs
├── terraform.tfvars.example
├── metastore.tf     # account-level: metastore + assignments
├── catalogs.tf  schemas.tf  volumes.tf
├── external_locations.tf  storage_credentials.tf  connections.tf
├── grants.tf        # authoritative grants + ownership
└── imports.tf       # native import blocks (environment-specific)
```

Backend ships unset (local state). **Configure HCP Terraform in `versions.tf` before
running against the real metastore.**

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

The snapshot is extracted with the provider's experimental **Resource Exporter**,
run with `-native-import` to emit import blocks with correct IDs.

```bash
cd terraform
terraform init
BIN="$PWD/$(find .terraform/providers -name 'terraform-provider-databricks*' -type f | head -1)"

UC="uc-metastores,uc-catalogs,uc-schemas,uc-volumes,uc-connections,uc-storage-credentials,uc-external-locations,uc-grants"
DATABRICKS_CONFIG_PROFILE=my-workspace "$BIN" exporter \
  -directory="../exporter-output" -listing="$UC" -services="$UC" \
  -native-import -generateProviderDeclaration=false
```

Scope with `-match` / `-matchRegex`. Output: `uc-*.tf`, `import.tf`, `import.sh`.

### 4b. CLI/SDK cross-check (find gaps)

The workspace-scope exporter **misses account-level objects**: the metastore itself,
assignments, and metastore-level grants. Build an independent inventory and diff it:

```bash
databricks account metastores get <METASTORE_ID> -p my-account -o json
databricks account metastore-assignments list <METASTORE_ID> -p my-account -o json
databricks catalogs list -p my-workspace -o json
databricks external-locations list -p my-workspace -o json
databricks storage-credentials list -p my-workspace -o json
databricks grants get <securable_type> <full_name> -p my-workspace -o json
```

Every object must end up either managed+imported or consciously excluded.

---

## 5. Reconcile and clean

Fold exporter output into `terraform/` and apply these corrections (each was required
for a clean no-op):

1. **Author account-level objects by hand** (exporter gaps): `databricks_metastore`,
   `databricks_metastore_assignment`, metastore-level `databricks_grants` — all on the
   `databricks.account` provider.
2. **Complete every grants block.** Include all live privileges — system defaults
   (e.g. `account users → USE_MARKETPLACE_ASSETS`) and implicit creator grants.
   **Drop grants the exporter invented but that aren't live** (seen in practice; the
   live `plan` is the source of truth).
3. **Strip system `properties`** on catalogs/schemas (`collation`, `owner="root"`):
   `lifecycle { ignore_changes = [properties] }`.
4. **Ignore provider-defaulted metastore fields**:
   `lifecycle { ignore_changes = [delta_sharing_recipient_token_lifetime_in_seconds] }`.
5. **Secrets aren't exported** (connection `bearer_token`, credential keys). If a plan
   shows secret drift, supply via variable or `ignore_changes = [options]`.
6. **Exclude system objects**: `information_schema`, auto-created `default` schemas,
   the Databricks-managed Default Storage external location + its auto-grant.
7. **Set `owner`** on each resource to the live value.

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
| `databricks_grants` | `<securable_type>/<full_name>` (e.g. `catalog/<name>`, `schema/<cat.schema>`, `metastore/<metastore_id>`, `external_location/<name>`) |

When unsure, use the IDs in the exporter's `import.tf`.

---

## 6. Import safely

```bash
cd terraform
terraform init          # with HCP backend configured
terraform plan          # read every line
```

Iterate §5 until the plan reads exactly:

```
Plan: N to import, 0 to add, 0 to change, 0 to destroy.
```

- `to change` / `to destroy` **must be 0** — anything else means config ≠ reality; fix it.
- A `databricks_grants` block that removes a `grant {}` = a **revoke**. Add the missing grant.

Get sign-off, then `terraform apply` (adopts into state; 0 changes to Databricks).
Import blocks are idempotent.

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

The baseline is **data-driven**: every object type is a single `for_each` resource
fed by a map in `terraform.tfvars`. Adding/removing an object is a one-line map edit,
not new HCL. Map keys are the natural identifiers and double as import IDs.

- `catalogs` — key = catalog name
- `schemas` — key = `catalog.schema`
- `volumes` — key = `catalog.schema.volume`
- `storage_credentials`, `external_locations`, `connections` — key = name
- `grants` — key = `<securable_type>/<full_name>` (also the import ID), e.g.
  `catalog/my_cat`, `schema/my_cat.my_schema`, `metastore/<id>`,
  `external_location/my_el`, `foreign_connection/my_conn`

`imports.tf` uses `for_each` over the same maps (requires Terraform ≥ 1.7), so the
inventory you build in §4 drives both resources and imports. Generate the map
entries from the §4b inventory (exporter output or a script over CLI/SDK JSON) and
batch discovery with `-match` / `-matchRegex`.

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
