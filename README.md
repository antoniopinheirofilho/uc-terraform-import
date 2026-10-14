# Unity Catalog → Terraform: Import & Manage Baseline

Adopt **existing**, manually-created Unity Catalog (UC) objects into Terraform **by
importing them (never recreating)**, then manage and extend them going forward.

The safety contract at every step: a `terraform plan` must show **only imports** before
you apply —

```
Plan: N to import, 0 to add, 0 to change, 0 to destroy.
```

— which proves adoption changes nothing live. Discovery and `plan` are read-only;
`apply` only writes once you've reviewed that plan.

- Databricks-side only — AWS/cloud resources are assumed to already exist.
- Grants are **authoritative**: a `databricks_grants` block is a complete snapshot of a
  securable's grants, so an incomplete snapshot shows up in the plan as a change (and on
  apply would revoke). See [§5](#5-build-the-tfvars-and-clean-up).
- Importing is gated **per object** by an `import_id` field, so existing objects are
  imported and brand-new ones are created — from the same config. See [§7](#7-the-import_id-gate--lifecycle).

## What this template supports / doesn't

### Supports
- **Importing existing** workspace-level UC objects to a clean no-op plan, then managing
  them: catalogs, schemas, volumes, external locations, storage credentials, connections,
  **workspace bindings**, and **grants + ownership** (including metastore-level grants).
- **Per-object import gate** (`import_id`): import existing objects and create new ones
  side by side; mixed and incremental migrations.
- **Data-driven, split by resource type** — objects are map entries in per-type
  `*.auto.tfvars` files, not hand-written HCL.
- **Authoritative grants** per securable (`databricks_grants`), with `owner` captured.
- **Isolated securables** via `isolation_mode` + `databricks_workspace_binding`.
- **AWS** storage credentials (IAM role, self-assuming UC role pattern).
- **`prevent_destroy` guard** on every resource — a destroy/replace fails the plan loud.
- **Any auth the Databricks provider accepts** — CLI profile (dev) or service principal
  via env vars (HCP/CI).

### Does NOT support (in this version)
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
  OPEN, or bound to it). Catalogs **isolated to other workspaces** are handled in a
  separate run pointed at a bound workspace — see [§6](#6-plan-then-apply).
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

Set `databricks_workspace_profile` in `provider.auto.tfvars`. For HCP/CI, leave it null
and use a service principal: `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET`.

You'll also need the **metastore ID** to build connection and metastore-grant import IDs.
Get it read-only as a metastore admin:

```bash
databricks metastores summary -p my-workspace -o json   # returns metastore_id, name, region
```

---

## 2. Layout

```
terraform/
├── versions.tf  providers.tf  variables.tf  locals.tf
├── catalogs.tf  schemas.tf  volumes.tf
├── external_locations.tf  storage_credentials.tf  connections.tf
├── bindings.tf  grants.tf  imports.tf
└── *.auto.tfvars.example         # one example per resource type + provider.auto.tfvars.example
```

**Data is split by resource type.** Copy each `*.auto.tfvars.example` to the same name
without `.example` and fill it in: `provider.auto.tfvars`, `catalogs.auto.tfvars`,
`schemas.auto.tfvars`, `volumes.auto.tfvars`, `storage_credentials.auto.tfvars`,
`external_locations.auto.tfvars`, `connections.auto.tfvars`,
`workspace_bindings.auto.tfvars`, `grants.auto.tfvars`. Terraform auto-loads every
`*.auto.tfvars` file and merges them. The real files are gitignored; only the
`.example` templates are committed. Backend ships unset (local state).

---

## 3. Workflow

```
4. DISCOVER (API/CLI) → 5. BUILD tfvars → 6. PLAN (import-only) → review → APPLY (adopt) → 7. MANAGE
```

Discovery and `plan` are read-only. `apply` runs only after the plan is import-only and
reviewed.

---

## 4. Discover the inventory (API/CLI)

Build the inventory with read-only Databricks API/CLI calls, then turn it into the
per-type `*.auto.tfvars` maps (§5). Run as a **metastore admin** against one workspace
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
> import IDs — both of which this template already provides. You would still have to
> transform its output into tfvars, and the API/CLI JSON is easier to script. The
> exporter also misses account-level objects and emits system properties, so it was
> never the source of truth. The API/CLI inventory is.

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

Populate the per-type `*.auto.tfvars` maps from the §4 inventory. **Set `import_id` on
every existing object you are adopting** (see [§7](#7-the-import_id-gate--lifecycle) and
the table below). Then apply these corrections (each is needed for a clean no-op plan):

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

### `import_id` values (what to put in each entry's `import_id`)

| Resource | `import_id` |
| --- | --- |
| `databricks_catalog` | `<catalog>` |
| `databricks_schema` | `<catalog>.<schema>` |
| `databricks_volume` | `<catalog>.<schema>.<volume>` |
| `databricks_connection` | `<metastore_id>\|<name>` |
| `databricks_external_location` | `<name>` |
| `databricks_storage_credential` | `<name>` |
| `databricks_workspace_binding` | `<securable_type>\|<securable_name>\|<workspace_id>` |
| `databricks_grants` | `<securable_type>/<full_name>` (e.g. `catalog/<name>`, `schema/<cat.schema>`, `metastore/<metastore_id>`, `external_location/<name>`) |

`imports.tf` uses each entry's `import_id` verbatim. For most types it equals the map
key; connections and bindings use the composite shown.

---

## 6. Plan, then apply

```bash
cd terraform
terraform init
terraform plan        # read every line
```

Iterate §5 until the plan reads exactly:

```
Plan: N to import, 0 to add, 0 to change, 0 to destroy.
```

- **Cross-check `N` and the listed addresses against your §4 inventory** — every object
  you're adopting should appear; nothing missing, nothing extra.
- **`to change` / `to destroy` must be 0.** Anything else means config ≠ reality — fix
  it in §5 (a `databricks_grants` block that would add/remove a `grant {}` means the
  snapshot is wrong; on apply that would revoke/grant live).

Once the plan is import-only and reviewed/approved, adopt the objects into state:

```bash
terraform apply       # imports only; 0 changes to Databricks
```

**Isolated catalogs & the provider workspace.** `plan` reads every object through the
single workspace the provider points at, so a catalog (or its schemas/volumes/grants)
`ISOLATED` to a *different* workspace fails the whole plan with `cannot read catalog:
Catalog '<name>' is not accessible in current workspace` (verified). Point the provider
at a workspace that can access the catalog — and for a metastore with isolated catalogs
spread across workspaces, run the config once per bound workspace (that workspace's
`databricks_workspace_host` + the matching subset of objects), with its own state.

### Guardrail: `prevent_destroy`

Every resource carries `lifecycle { prevent_destroy = true }`. If a plan ever proposes a
destroy or replace, Terraform **errors and stops** instead of carrying it out (verified)
— fail loud rather than risk dropping a resource the metastore relies on. It leaves
imports, creates, and in-place updates unaffected. Keep it on as a standing guard; flip a
single type off only when you deliberately intend to destroy/replace:

```bash
# one prevent_destroy line per type file (8 total); flip the whole set if needed
sed -i '' 's/prevent_destroy = true/prevent_destroy = false/' terraform/*.tf
```

Scope note: `prevent_destroy` blocks destroys/replaces, **not** in-place updates — an
authoritative `databricks_grants` revoke or an `owner` change is an update, so the
`0 to change` plan review is what guards those. For enforcement against updates too
(e.g. on HCP Terraform), add a policy that denies any run whose plan contains a
create/update/delete/replace.

---

## 7. The `import_id` gate & lifecycle

Importing is controlled **per object** by the optional `import_id` field on each map
entry — not by editing `imports.tf` (which stays in the repo permanently):

- **`import_id` set** → the object is **imported** using that ID (adopt existing).
- **`import_id` unset** → the object is **created** on apply (brand-new object).

This lets existing and new objects live in the same config, and supports incremental
migration (populate `import_id` on the batch you're adopting now). The validated flow:

1. **Adopt an existing object** — add its map entry **with** `import_id`; `plan` shows
   `1 to import, 0 change`; `apply` imports it into state.
2. **Steady state** — `plan` shows `No changes` (whether you keep or drop the
   `import_id`; the import is idempotent, so removing it is optional hygiene — do it only
   *after* the object is confirmed in state).
3. **Add a new object** — add a map entry **without** `import_id`; `plan` shows
   `1 to add`; `apply` creates it.

> Removing an `import_id` before the object is in state (or if state is lost/rebuilt)
> makes Terraform plan to **create** it — which against an existing object is the
> dangerous case. Only drop `import_id` after a confirmed apply, and keep state remote
> (e.g. HCP) and backed up.

---

## 8. Scaling — data-driven model

Every object type is a single `for_each` resource fed by a per-type `*.auto.tfvars`
map. Adding an object is a one-line map edit, not new HCL. Splitting by type keeps each
file small and lets different owners maintain different files; Terraform merges them.
Map keys:

- `catalogs` — catalog name
- `schemas` — `catalog.schema`
- `volumes` — `catalog.schema.volume`
- `storage_credentials`, `external_locations`, `connections` — name
- `workspace_bindings` — one entry per (securable, workspace)
- `grants` — `<securable_type>/<full_name>`

Generate the entries from the §4 inventory with a script over the CLI/SDK JSON. Keep
`grants` entries complete per securable so the plan stays clean.

---

## 9. Safety & publishing

- **Never commit:** state, real `*.auto.tfvars`, `.databrickscfg`, secrets, raw discovery
  output (JSON with real identifiers). `.gitignore` enforces this.
- Commit only `*.auto.tfvars.example` and sanitized identifiers.
- Before publishing, scrub metastore/workspace IDs, bucket paths, IdP group names,
  connection hosts/tokens.
- Treat `apply` of authoritative grants like a production access change — review the
  plan, apply during a change window.
