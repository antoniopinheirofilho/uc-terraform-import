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
- The object inventory is a **YAML data tree** (`data/<env>/<type>/*.yaml`), read via
  `fileset()`+`yamldecode()` and passed through a **typed module** so the data is
  validated. See [§5](#5-build-the-data-tree).
- **One state manages the whole metastore, even with workspace-catalog bindings.** UC
  management APIs run through a workspace, and bindings gate what each workspace can
  see — so you declare one provider alias + module instance per workspace you route
  through, all in a single state. This template ships **dev / sit / stg / prod** as the
  worked example (four workspaces on one metastore, catalogs bound per environment); use
  one environment if that's all you have. See [§6](#6-plan-then-apply).
- Grants are **authoritative**: a `databricks_grants` block is a complete snapshot of a
  securable's grants, so an incomplete snapshot shows up in the plan as a change (and on
  apply would revoke).
- Importing is gated **per object** by an `import_id` field, so existing objects are
  imported and brand-new ones are created — from the same config. See [§7](#7-the-import_id-gate--lifecycle).

## What this template supports / doesn't

### Supports
- **Importing existing** workspace-level UC objects to a clean no-op plan, then managing
  them: catalogs, schemas, volumes, external locations, storage credentials, connections,
  **workspace bindings**, and **grants + ownership** (including metastore-level grants).
- **Per-object import gate** (`import_id`): import existing objects and create new ones
  side by side; mixed and incremental migrations.
- **YAML data tree, validated** — the inventory lives in per-type YAML files, read by
  the root and passed through a typed module whose `variable` type constraints validate
  it (missing/mistyped/unknown fields fail the plan). Scales to many files/objects.
- **Authoritative grants** per securable (`databricks_grants`), with `owner` captured.
- **Privilege presets** — named, securable-type-aware privilege bundles (`DATA_READER` /
  `DATA_EDITOR`, mirroring the Catalog Explorer "Privilege presets") so grant YAML
  references a preset instead of raw UC privileges. See
  [§5.1](#51-privilege-presets-grant-aliases).
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
- **Metastore admin + workspace-level OAuth** (no account admin required). The same
  principal is used for every workspace alias; it must be entitled into each workspace
  it routes through.
- The target metastore and the workspace(s) you connect to already exist and are assigned.
- Each in-scope catalog is reachable from the workspace alias that manages it — OPEN
  catalogs from any assigned workspace, ISOLATED catalogs from a workspace they're bound
  to. One state spans all of them via multiple aliases — see [§6](#6-plan-then-apply).
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

Copy `provider.auto.tfvars.example` to `provider.auto.tfvars` and fill in
`workspace_connections` — one entry per environment/workspace you route through
(`dev`/`sit`/`stg`/`prod` in the shipped example). For HCP/CI, omit `profile` and use a
service principal: `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET`.

You'll also need the **metastore ID** to build connection and metastore-grant import IDs:

```bash
databricks metastores summary -p my-workspace -o json   # returns metastore_id, name, region
```

---

## 2. Layout

```
terraform/
├── versions.tf  variables.tf                  # root: requirements + workspace_connections var
├── providers.tf                               # root: one provider alias per environment (dev/sit/stg/prod)
├── main.tf                                     # root: one modules/uc instance per environment
├── imports.tf                                  # root: import blocks per environment (import_id gate)
├── privilege_presets.tf                        # root: named privilege bundles for grants (governance vocabulary)
├── data.tf                                    # root: reads data/<env>/<type>/*.yaml; builds inventory + import maps
├── provider.auto.tfvars.example               # workspace_connections template (dev/sit/stg/prod)
├── data/                                      # THE INVENTORY (YAML), gitignored; *.yaml.example committed
│   ├── dev/                                   # one folder per environment (= a provider alias + connection key)
│   │   ├── catalogs/   schemas/   volumes/
│   │   ├── storage_credentials/   external_locations/   connections/
│   │   └── workspace_bindings/   grants/
│   ├── sit/   stg/   prod/                    # same structure per environment
└── modules/uc/                                # typed resources (one for_each resource per type), reused per environment
    ├── versions.tf  variables.tf  locals.tf
    └── catalogs.tf schemas.tf volumes.tf storage_credentials.tf
        external_locations.tf connections.tf bindings.tf grants.tf
```

**How it fits together:** `data.tf` reads every `*.yaml` under `data/<env>/<type>/` and
merges them into one map per env+type (`local.inventory`), plus a per-env import map
(`local._import`). `providers.tf` declares one provider alias per environment; `main.tf`
passes each environment's slice of the inventory into its own `modules/uc` instance
(routed through that alias); `imports.tf` holds each environment's import blocks. The
typed module `variable`s validate the decoded data. All environments share **one
state**. Backend ships unset (local state).

**Adding or removing an environment:** add (or delete) a provider block in
`providers.tf`, a module instance in `main.tf`, and its import blocks in `imports.tf`,
plus a `workspace_connections` entry and a `data/<env>/` folder. This per-environment
wiring is static because Terraform can't `for_each` over providers; the object inventory
itself stays data-driven (YAML, no HCL edits).

---

## 3. Workflow

```
4. DISCOVER (API/CLI) → 5. BUILD data/*.yaml → 6. PLAN (import-only) → review → APPLY (adopt) → 7. MANAGE
```

Discovery and `plan` are read-only. `apply` runs only after the plan is import-only and
reviewed.

---

## 4. Discover the inventory (API/CLI)

Build the inventory with read-only Databricks API/CLI calls, then write it into the
YAML data tree (§5). Run as a **metastore admin** against one workspace assigned to the
metastore:

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

**Helper script.** `scripts/discover.sh` runs all of the above (except the one-time
`metastores summary`) for **each** workspace profile you pass and saves the raw JSON
under `discovery-output/<profile>/` (gitignored). It is read-only and skips
system-managed objects (the `system` / `samples` catalogs and the Default-Storage
external location). For many objects, script the JSON → YAML transformation.

```bash
./scripts/discover.sh ws-east ws-west
```

> Why not the Terraform Resource Exporter? It only *generates* per-object HCL and
> import IDs — both of which this template already provides. You would still have to
> transform its output, and the API/CLI JSON is easier to script. The exporter also
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

Every object must end up either in the YAML tree or consciously excluded.

---

## 5. Build the data tree

For each object, add an entry to a `*.yaml` file under
`data/<env>/<type>/` — where `<env>` is the environment/workspace that can reach it
(`dev`/`sit`/`stg`/`prod`; use the workspace a catalog is bound to for ISOLATED
catalogs, or any environment for OPEN ones). Copy the `example.yaml.example` in each
folder to start. A file holds one or many entries, and all files in a folder are merged
— so you can split by domain/team (e.g. `data/prod/catalogs/finance.yaml`,
`data/prod/catalogs/hr.yaml`). The top-level key of each entry is the object identifier;
**set `import_id` to adopt an existing object** (see the table). Then apply these
corrections (each is needed for a clean no-op plan):

1. **Complete every grants entry.** List all live privileges per securable — system
   defaults (e.g. `account users → USE_MARKETPLACE_ASSETS`) and implicit creator
   grants. Include **only** privileges that are actually live; the `plan` is the source
   of truth. Metastore-level grants (`metastore/<id>`) belong here too.
2. **Strip system `properties`** on catalogs/schemas (`collation`, `owner="root"`):
   handled by `lifecycle { ignore_changes = [properties] }` in the module.
3. **Secrets aren't retrievable** (connection `bearer_token`, credential keys). If a
   plan shows secret drift, add `ignore_changes = [options]` in the module.
4. **Bindings:** for every `ISOLATED` securable set `isolation_mode: ISOLATED` and add
   its `workspace_bindings` entries.
5. **Exclude system objects**: `information_schema`, auto-created `default` schemas,
   the Databricks-managed Default Storage external location + its auto-grant.
6. **Set `owner`** on each entry to the live value.

### `import_id` values (set this on each entry you are adopting)

| Resource | `import_id` |
| --- | --- |
| catalog | `<catalog>` |
| schema | `<catalog>.<schema>` |
| volume | `<catalog>.<schema>.<volume>` |
| connection | `<metastore_id>\|<name>` |
| external location | `<name>` |
| storage credential | `<name>` |
| workspace binding | `<securable_type>\|<securable_name>\|<workspace_id>` |
| grants | `<securable_type>/<full_name>` (= the entry's key) |

The typed module validates every entry; the import blocks in `imports.tf` use each
entry's `import_id` verbatim.

### 5.1 Privilege presets (grant aliases)

Instead of repeating raw UC privileges in every grant, a grant can reference a named
**privilege preset**. This keeps the YAML readable and stops privilege sets being
copy-pasted without understanding what they contain.

The two shipped presets — **`DATA_READER`** and **`DATA_EDITOR`** — mirror the
Databricks Catalog Explorer "Privilege presets" of the same names. Those UI presets are
a convenience that ticks a bundle of individual privileges; there is no grantable
"preset" object, so Terraform lists the raw privileges. These reproduce the bundle in
version-controlled form (`DATA_READER` = read-only, `DATA_EDITOR` = read + modify).

**The registry — `privilege_presets.tf`** (root, committed, governed vocabulary). Each
preset is **securable-type-aware**: it maps a securable type to the privileges that
apply *for that type* (read on a catalog ≠ read on a volume). The catalog/schema sets
match the documented presets exactly:

```hcl
locals {
  privilege_presets = {
    DATA_READER = {   # read-only
      catalog           = ["USE_CATALOG", "USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
      schema            = ["USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
      volume            = ["READ_VOLUME"]
      external_location = ["READ_FILES"]
    }
    DATA_EDITOR = { ... }   # read + modify (DATA_READER + APPLY_TAG, MODIFY, REFRESH, WRITE_VOLUME)
  }
}
```

**Using it in grant YAML.** Each grant sets **exactly one** of `presets` (preset names)
or `privileges` (raw) — not both, not neither:

```yaml
catalog/finance:
  grants:
    - principal: data_engineers
      presets: [DATA_EDITOR]          # preferred: resolved to DATA_EDITOR.catalog
    - principal: analysts
      presets: [DATA_READER]
  import_id: catalog/finance

metastore/<metastore_id>:
  grants:
    - principal: account users
      privileges: [USE_MARKETPLACE_ASSETS]   # raw escape hatch — fits no preset
  import_id: metastore/<metastore_id>
```

- `presets` resolves to the union of each preset's privileges **for that securable's
  type**; multiple presets are allowed (`presets: [DATA_READER, SHARE_ACCESS]`).
- **`privileges` (raw) is the escape hatch** for existing grants that don't match a
  preset — use it to reach a clean import no-op, then migrate to `presets` where it
  fits. Remember grants are authoritative, so the resolved set must equal the live set.
- **Fail-loud validation:** an undefined preset, a preset with no entry for the
  securable's type, or an empty set **fails the plan** (resource precondition) — a typo
  never silently grants nothing. Setting both `presets` and `privileges` fails variable
  validation.

To add a capability, edit `privilege_presets.tf` (one reviewed change) rather than every
grant entry.

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
  the YAML (a `databricks_grants` entry that would add/remove a `grant` means the
  snapshot is wrong; on apply that would revoke/grant live).

Once the plan is import-only and reviewed/approved, adopt the objects into state:

```bash
terraform apply       # imports only; 0 changes to Databricks
```

**Isolated catalogs — one state, multiple environments.** Each `main.tf` module
instance reads through its own workspace alias (`providers.tf`), so an object `ISOLATED` to a workspace
must be placed under that environment's `data/<env>/` folder and is managed by that
environment's module instance. Routing it through a workspace that can't see it fails
the plan with `cannot read catalog: Catalog '<name>' is not accessible in current
workspace`. OPEN catalogs can go under any environment (visible from every assigned
workspace). All environments share one state, so the whole metastore is still managed
from a single `terraform apply`. (Verified end-to-end: one state importing an OPEN
catalog via the `dev` workspace and a catalog isolated to the `prod` workspace,
together, clean.)

### Guardrail: `prevent_destroy`

Every resource carries `lifecycle { prevent_destroy = true }`. If a plan ever proposes a
destroy or replace, Terraform **errors and stops** instead of carrying it out (verified)
— fail loud rather than risk dropping a resource the metastore relies on. It leaves
imports, creates, and in-place updates unaffected. Keep it on as a standing guard; flip a
single type off only when you deliberately intend to destroy/replace:

```bash
# one prevent_destroy line per type file under modules/uc/ (8 total)
sed -i '' 's/prevent_destroy = true/prevent_destroy = false/' modules/uc/*.tf
```

Scope note: `prevent_destroy` blocks destroys/replaces, **not** in-place updates — an
authoritative `databricks_grants` revoke or an `owner` change is an update, so the
`0 to change` plan review is what guards those. For enforcement against updates too
(e.g. on HCP Terraform), add a policy that denies any run whose plan contains a
create/update/delete/replace.

---

## 7. The `import_id` gate & lifecycle

Importing is controlled **per object** by the optional `import_id` field in each YAML
entry — not by editing the import blocks (they stay in `imports.tf` permanently):

- **`import_id` set** → the object is **imported** using that ID (adopt existing).
- **`import_id` unset** → the object is **created** on apply (brand-new object).

This lets existing and new objects live in the same config, and supports incremental
migration (populate `import_id` on the batch you're adopting now). The validated flow:

1. **Adopt an existing object** — add its YAML entry **with** `import_id`; `plan` shows
   `1 to import, 0 change`; `apply` imports it into state.
2. **Steady state** — `plan` shows `No changes` (whether you keep or drop the
   `import_id`; the import is idempotent, so removing it is optional hygiene — do it only
   *after* the object is confirmed in state).
3. **Add a new object** — add a YAML entry **without** `import_id`; `plan` shows
   `1 to add`; `apply` creates it.

> Removing an `import_id` before the object is in state (or if state is lost/rebuilt)
> makes Terraform plan to **create** it — dangerous against an existing object. Only drop
> `import_id` after a confirmed apply, and keep state remote (e.g. HCP) and backed up.

---

## 8. Scaling

The YAML data tree scales to hundreds/thousands of objects: one entry per object, files
grouped by domain/team under each `data/<env>/<type>/` folder, discovered automatically
by `fileset()` (no per-file wiring). Validation is preserved because the decoded data
flows through the typed `modules/uc` variables. Generate the YAML from the §4 inventory
with a script over the CLI/SDK JSON.

Environments add a second axis: a provider alias (`providers.tf`) + module instance
(`main.tf`) + import blocks (`imports.tf`) per workspace, all in **one state** (§6).
Adding an environment is a small static edit to those three files; the per-object
inventory stays data-driven.

For a very large estate, you can instead segment **state** by bounded context — e.g. a
root per business unit, each reusing `modules/uc` with its own `data/` tree and backend.
That keeps plans small and bounds blast radius; it does not change the module.

---

## 9. Safety & publishing

- **Never commit:** state, real `data/**/*.yaml`, real `*.auto.tfvars`, `.databrickscfg`,
  secrets, raw discovery output. `.gitignore` enforces this.
- Commit only `*.example` templates and sanitized identifiers.
- Before publishing, scrub metastore/workspace IDs, bucket paths, IdP group names,
  connection hosts/tokens.
- Treat `apply` of authoritative grants like a production access change — review the
  plan, apply during a change window.
