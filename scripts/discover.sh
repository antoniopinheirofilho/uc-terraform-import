#!/usr/bin/env bash
#
# discover.sh — snapshot the Unity Catalog inventory for Terraform import prep (§4).
#
# Runs the read-only UC list/get commands for each workspace CLI profile you pass and
# writes the raw JSON under ./discovery-output/<profile>/. Running per workspace is
# deliberate: workspace bindings hide ISOLATED catalogs (and their schemas, volumes
# and grants) from workspaces they are not bound to, so a single workspace cannot see
# everything. The redundant per-workspace dumps together give the full picture; an
# object a workspace cannot see is simply skipped (another profile captures it).
# `metastores summary` is identical from every workspace, so it runs only once.
#
# Everything here is READ-ONLY. Output may contain real identifiers — it is gitignored.
#
# Usage:   ./scripts/discover.sh <workspace_profile> [<workspace_profile> ...]
# Example: ./scripts/discover.sh ws-east ws-west
#
set -uo pipefail

OUT="${DISCOVERY_OUT:-discovery-output}"
[ "$#" -ge 1 ] || { echo "usage: $0 <workspace_profile> [workspace_profile ...]" >&2; exit 1; }

# dump <outfile> <databricks args...> : write command JSON, or remove file + return 1
# on failure (e.g. a securable this workspace is not bound to).
dump() {
  local out="$1"; shift
  if databricks "$@" -o json >"$out" 2>/dev/null && [ -s "$out" ]; then return 0; fi
  rm -f "$out"; return 1
}

# field <key> : print one key per line from a JSON array (or array-valued object) on stdin.
field() {
  python3 -I -c "import sys,json
d=json.load(sys.stdin)
d=d if isinstance(d,list) else next((v for v in d.values() if isinstance(v,list)),[])
print(chr(10).join(str(x['$1']) for x in d if isinstance(x,dict) and '$1' in x))"
}

# exclude <file> <key> <value> : rewrite a JSON-array file dropping entries where key==value.
exclude() {
  python3 -I - "$1" "$2" "$3" <<'PY'
import json, sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path))
arr = d if isinstance(d, list) else next((v for v in d.values() if isinstance(v, list)), [])
json.dump([x for x in arr if x.get(key) != val], open(path, "w"), indent=2)
PY
}

mkdir -p "$OUT"

# metastore summary — once (identical from any workspace)
dump "$OUT/metastore_summary.json" metastores summary -p "$1" && echo "metastore_summary.json"
METASTORE_ID=$(python3 -I -c "import json;print(json.load(open('$OUT/metastore_summary.json')).get('metastore_id',''))" 2>/dev/null)

for prof in "$@"; do
  d="$OUT/$prof"; mkdir -p "$d/schemas" "$d/volumes" "$d/grants" "$d/bindings"
  echo "profile: $prof"

  # top-level securables (--include-unbound surfaces ISOLATED ones for a metastore admin)
  dump "$d/catalogs.json"            catalogs list --include-unbound -p "$prof"            && echo "  catalogs"
  dump "$d/storage_credentials.json" storage-credentials list --include-unbound -p "$prof" && echo "  storage_credentials"
  dump "$d/external_locations.json"  external-locations list --include-unbound -p "$prof"   && echo "  external_locations"
  dump "$d/connections.json"         connections list -p "$prof"                            && echo "  connections"

  # drop system-managed objects we never manage (system + samples catalogs are
  # catalog_type SYSTEM_CATALOG; the Default-Storage external location is auto-created)
  [ -f "$d/catalogs.json" ]           && exclude "$d/catalogs.json" catalog_type SYSTEM_CATALOG
  [ -f "$d/external_locations.json" ] && exclude "$d/external_locations.json" name __databricks_managed_storage_location

  # metastore-level grants
  [ -n "$METASTORE_ID" ] && dump "$d/grants/metastore.json" grants get metastore "$METASTORE_ID" -p "$prof"

  # bindings + grants for top-level securables
  [ -f "$d/storage_credentials.json" ] && field name <"$d/storage_credentials.json" | while read -r n; do
    [ -z "$n" ] && continue
    dump "$d/bindings/storage_credential__$n.json" workspace-bindings get-bindings storage_credential "$n" -p "$prof"
    dump "$d/grants/storage_credential__$n.json"   grants get storage_credential "$n" -p "$prof"
  done
  [ -f "$d/external_locations.json" ] && field name <"$d/external_locations.json" | while read -r n; do
    [ -z "$n" ] && continue
    dump "$d/bindings/external_location__$n.json" workspace-bindings get-bindings external_location "$n" -p "$prof"
    dump "$d/grants/external_location__$n.json"   grants get external_location "$n" -p "$prof"
  done
  # note: grants get uses securable type `connection` (the Terraform resource attribute
  # is `foreign_connection`, but the CLI/API securable type is `connection`).
  [ -f "$d/connections.json" ] && field name <"$d/connections.json" | while read -r n; do
    [ -z "$n" ] && continue
    dump "$d/grants/connection__$n.json" grants get connection "$n" -p "$prof"
  done

  # catalogs -> schemas -> volumes, with grants at each level.
  # ISOLATED catalogs not bound to this workspace are skipped (dump returns 1).
  [ -f "$d/catalogs.json" ] && field name <"$d/catalogs.json" | while read -r cat; do
    [ -z "$cat" ] && continue
    dump "$d/bindings/catalog__$cat.json" workspace-bindings get-bindings catalog "$cat" -p "$prof"
    dump "$d/grants/catalog__$cat.json"   grants get catalog "$cat" -p "$prof"
    dump "$d/schemas/$cat.json" schemas list "$cat" -p "$prof" || continue
    field name <"$d/schemas/$cat.json" | while read -r sch; do
      { [ -z "$sch" ] || [ "$sch" = information_schema ]; } && continue
      dump "$d/grants/schema__$cat.$sch.json" grants get schema "$cat.$sch" -p "$prof"
      dump "$d/volumes/$cat.$sch.json" volumes list "$cat" "$sch" -p "$prof" || continue
      field name <"$d/volumes/$cat.$sch.json" | while read -r vol; do
        [ -z "$vol" ] && continue
        dump "$d/grants/volume__$cat.$sch.$vol.json" grants get volume "$cat.$sch.$vol" -p "$prof"
      done
    done
  done
  echo "  -> $d"
done

echo "done. inventory under $OUT/"
