# Unity Catalog → Terraform: Import Validation Baseline

Produce and validate a Terraform configuration — resources + native `import {}`
blocks — that would adopt existing Unity Catalog (UC) objects into Terraform
**without recreating anything**.

**Scope of this project: everything up to `terraform plan`.** Success is a plan that
shows **only imports**:

```
Plan: N to import, 0 to add, 0 to change, 0 to destroy.
```

That proves every in-scope object would be adopted safely — nothing created, changed,
or destroyed. **Performing the import (`terraform apply`) and ongoing lifecycle
management are out of scope.** Every step in this runbook is **read-only** —
discovery is API/CLI reads, and `terraform plan` modifies neither Databricks nor
state.

- Databricks-side only — AWS/cloud resources are assumed to already exist.
- Grants are **authoritative**: a `databricks_grants` block is a complete snapshot of
  a securable's grants, so an incomplete snapshot shows up in the plan as a change.
  See [§5](#5-build-the-tfvars-and-clean-up).

## What this template supports / doesn't

### Supports
- **Validating the adoption** of existing workspace-level UC objects via a clean plan
  (`N to import, 0 add/change/destroy`): catalogs, schemas, volumes, external
  locations, storage credentials, connections, **workspace bindings**, and
  **grants + ownership** (including metastore-level grants).
- **Data-driven scaling** — objects are map entries in `terraform.tfvars`, not
  hand-written HCL; `for_each` import blocks are derived from the same maps.
- **Authoritative grants** per securable (`databricks_grants`), with `owner` captured.
- **Isolated securables** via `isolation_mode` + `databricks_workspace_binding`.
- **AWS** storage credentials (IAM role, self-assuming UC role pattern).
- **Any auth the Databricks provider accepts** — CLI profile (dev) or service
  principal via env vars (HCP/CI).

### Does NOT support (in this version)
- **`terraform apply` / performing the import, and day-2 lifecycle** (create / update /
  delete) — out of scope. This project stops at a validated `plan`.
- **The metastore object and workspace assignments** (`databricks_metastore`,
  `databricks_metastore_assignment`) — account-level, assumed to already exist and
  managed outside Terraform.
- **Tables, views, materialized views, functions, registered models** — data objects
  are not managed (manage their containers + grants instead).
- **Delta Sharing** shares/recipients/providers, and **system schemas / Lakehouse
  Federation foreign catalogs** beyond the plain `connection` object.
- **Azure / GCP storage credentials** — only `aws_iam_role` is wired in; Azure
  (`azure_managed_identity`) / GCP variants would need to be added.
- **Secret values** (connection `bearer_token`, credential keys) — write-only, not
  stored or managed.
- **Creating the underlying cloud infrastructure** (S3 buckets, IAM roles, workspaces)
  — Databricks-side only; cloud resources are assumed to exist.
- **Non-metastore-admin discovery** — a caller without metastore admin only sees their
  own workspace's objects and must inventory per-workspace ([§4](#4-discover-the-inventory-apicli)).

### Assumptions
- **Metastore admin + workspace-level OAuth** (no account admin required).
- The target metastore and the workspace you connect to already exist and are assigned.
- The workspace you point the provider at can access all in-scope catalogs (they are
  OPEN, or bound to it). Catalogs **isolated to other workspaces** must be imported in
  a separate run pointed at a workspace they are bound to — see [§6](#6-plan--validate-the-deliverable).
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

Backend ships unset (local state).

---

## 3. Workflow

```
4. DISCOVER (API/CLI) → 5. BUILD tfvars + CLEAN → 6. PLAN & VALIDATE (0 add/change/destroy)
```

Everything here is read-only. The project ends at a validated plan — no `apply`.

---

## 4. Discover the inventory (API/CLI)

Build the inventory with read-only Databricks API/CLI calls, then turn it into
`terraform.tfvars` map entries (§7). The map key is also the import ID, so there is no
separate import-ID bookkeeping. Run as a **metastore admin** against one workspace
assigned to the metastore:

```bash
databricks metastores summary -p my-workspace -o json                       # metastore_id/name/region
databricks catalogs list --include-unbound -p my-workspace -o json
databricks schemas list <catalog> -p my-workspace -o json
databricks volumes list <catalog> <schema> -p my-workspace -o json
databricks storage-credentials list --include-unbound -p my-workspace -o json
databricks external-locations list --include-unbound -p my-workspace -o json
databricks connections list -p my-workspace -o json
databricks workspace-bindings get-bindings <securable_type> <name> -p my-workspace -o json
databricks grants get <securable_type> <full_name> -p my-workspace -o json
```

Map each result into the matching tfvars map. For dozens/hundreds of objects, script
the JSON → map transformation (`jq` / Python) instead of hand-editing.

**Helper script.** `scripts/discover.sh` runs all of the above (except the one-time
`metastores summary`) for **each** workspace profile you pass and saves the raw JSON
under `discovery-output/<profile>/` (gitignored). Running it for every workspace covers
the binding blind spots described below — an object a workspace can't see is skipped
and another profile captures it:

```bash
./scripts/discover.sh ws-east ws-west
```

It is read-only and automatically skips system-managed objects (the `system` /
`samples` catalogs and the Default-Storage external location).

> Why not the Terraform Resource Exporter? It only *generates* per-object HCL and
> import IDs — both of which this template already provides (static `for_each`
> resources; import IDs derived from map keys). You would still have to transform its
> output into tfvars, and the API/CLI JSON is easier to script. The exporter also
> misses account-level objects and emits system properties, so it was never the source
> of truth. The API/CLI inventory is.

### Workspace bindings

`list` is binding-aware: add `--include-unbound` (metastore admin) to `catalogs` /
`external-locations` / `storage-credentials` to also return `ISOLATED` objects bound to
other workspaces. But an isolated catalog's **grants, schemas, volumes, and tables are
readable only from a workspace it is bound to** — elsewhere they fail with `Catalog not
accessible in current workspace` (verified; `get-bindings` still works from anywhere).
So pass every binding workspace to the discovery script — its per-workspace dumps cover
these blind spots.

Every object must end up either in the tfvars maps or consciously excluded.

---

## 5. Build the tfvars and clean up

Populate the tfvars maps from the §4 inventory and apply these corrections (each is
needed for a clean no-op plan):

1. **Complete every grants block.** List all live privileges per securable — system
   defaults (e.g. `account users → USE_MARKETPLACE_ASSETS`) and implicit creator
   grants. Include **only** privileges that are actually live; the `plan` is the
   source of truth (a block that would *add* a privilege means it wasn't live — remove
   it). Metastore-level grants (`metastore/<id>`) belong here too.
2. **Strip system `properties`** on catalogs/schemas (`collation`, `owner="root"`):
   `lifecycle { ignore_changes = [properties] }` (already in the resources).
3. **Secrets aren't retrievable** (connection `bearer_token`, credential keys). If a
   plan shows secret drift, supply via variable or `ignore_changes = [options]`.
4. **Bindings:** for every `ISOLATED` securable set `isolation_mode = "ISOLATED"` and
   add its `workspace_bindings` entries.
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

`imports.tf` constructs these IDs automatically from your map keys.

---

## 6. Plan & validate (the deliverable)

```bash
cd terraform
terraform init
terraform plan        # read every line
```

Iterate §5 until the plan reads exactly:

```
Plan: N to import, 0 to add, 0 to change, 0 to destroy.
```

- **Cross-check `N` and the listed resource addresses against your §4 inventory** —
  every in-scope object should appear; nothing missing, nothing extra.
- **`to change` / `to destroy` must be 0.** Anything else means config ≠ reality — fix
  it in §5 (a `databricks_grants` block that would add/remove a `grant {}` means the
  snapshot is wrong).

**Isolated catalogs & the provider workspace.** `plan` reads every object through the
single workspace the provider points at, so a catalog (or its schemas/volumes/grants)
`ISOLATED` to a *different* workspace fails the whole plan with `cannot read catalog:
Catalog '<name>' is not accessible in current workspace` (verified). Point the provider
at a workspace that can access the catalog — and for a metastore with isolated catalogs
spread across workspaces, run the config once per bound workspace (that workspace's
`databricks_workspace_host` + the matching subset of objects), validating each
separately.

This validated plan **is** the deliverable: it proves the configuration would adopt
every object correctly and safely. `terraform plan` writes nothing — it changes
neither Databricks nor state. **Do not run `terraform apply`; it is out of scope for
this project.**

### Guardrail: `prevent_destroy`

Every resource carries `lifecycle { prevent_destroy = true }`. Because the goal is an
import-only plan, nothing should ever be destroyed — so if a plan proposes a destroy or
replace, Terraform **errors and stops** instead of showing an actionable change. That
is the intended outcome: fail loud rather than risk dropping a resource the metastore
relies on. It leaves normal import plans unaffected (verified: the import plan is still
`N to import, 0 add/change/destroy`).

Scope note: `prevent_destroy` blocks destroys/replaces, **not** in-place updates — an
authoritative `databricks_grants` revoke or an `owner` change is an update, so the
`0 to change` gate above is what guards those. For enforcement against updates too
(e.g. on HCP Terraform), add a policy that denies any run whose plan contains a
create/update/delete/replace.

**Toggling the guard.** It is set per object *type* — one `prevent_destroy` line in
each of `catalogs.tf`, `schemas.tf`, `volumes.tf`, `storage_credentials.tf`,
`external_locations.tf`, `connections.tf`, `bindings.tf`, `grants.tf` (8 total, each
covering all instances of that type via `for_each`). Terraform requires a literal here
— it can't be a variable — so flip the whole set with one command when you move past
import validation:

```bash
# lift the guard across all resource types
sed -i '' 's/prevent_destroy = true/prevent_destroy = false/' terraform/*.tf
```

---

## 7. Scaling — data-driven model

Every object type is a single `for_each` resource fed by a map in `terraform.tfvars`.
Adding an object is a one-line map edit, not new HCL; its import block (and import ID)
come from the same key. Map keys:

- `catalogs` — catalog name
- `schemas` — `catalog.schema`
- `volumes` — `catalog.schema.volume`
- `storage_credentials`, `external_locations`, `connections` — name
- `workspace_bindings` — one entry per (securable, workspace)
- `grants` — `<securable_type>/<full_name>` (also the import ID)

Generate the map entries from the §4 inventory with a script over the CLI/SDK JSON.
Each entry you add appears in the plan's import set; keep `grants` entries complete per
securable so the plan stays a clean no-op.

---

## 8. Safety & publishing

- **Never commit:** state, real `*.tfvars`, `.databrickscfg`, secrets, raw discovery
  output (JSON with real identifiers). `.gitignore` enforces this.
- Commit only `*.tfvars.example` and sanitized identifiers.
- Before publishing, scrub metastore/workspace IDs, bucket paths, IdP group names,
  connection hosts/tokens.
