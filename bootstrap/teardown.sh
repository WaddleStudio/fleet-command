#!/usr/bin/env bash
# bootstrap/teardown.sh — workspace cleanup (dry-run by default).
#
# Usage:
#   teardown.sh [--apply] [--nuke] [--workspace <path>] [--keep <pattern>]... [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

APPLY=false
NUKE=false
WORKSPACE_OVERRIDE=""
KEEP_PATTERNS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply|-Apply) APPLY=true; shift ;;
    --nuke|-Nuke)  NUKE=true; shift ;;
    --workspace|-Workspace) WORKSPACE_OVERRIDE="$2"; shift 2 ;;
    --keep|-Keep) KEEP_PATTERNS+=("$2"); shift 2 ;;
    --verbose|-Verbose) shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

require_jq

assert_safe() {
  local ws="$1"
  [[ "$ws" = /* ]] || { echo "Workspace must be absolute: $ws" >&2; exit 1; }
  local resolved; resolved="$(cd "$ws" && pwd -P)"
  [[ "$resolved" != "/" ]] || { echo "Refusing /." >&2; exit 1; }
  local home_resolved; home_resolved="$(cd "$HOME" && pwd -P)"
  [[ "$resolved" != "$home_resolved" ]] || { echo "Refusing HOME." >&2; exit 1; }
  for p in .ssh .aws .config .claude .codex; do
    [[ "$resolved" != "$home_resolved/$p" ]] || { echo "Refusing $home_resolved/$p." >&2; exit 1; }
  done
  [[ -d "$resolved" ]] || { echo "Not a directory: $resolved" >&2; exit 1; }
  [[ -n "$(ls -A "$resolved" 2>/dev/null)" ]] || { echo "Workspace empty; refusing." >&2; exit 1; }
  printf '%s' "$resolved"
}

if [[ -n "$WORKSPACE_OVERRIDE" ]]; then
  WS="$(assert_safe "$WORKSPACE_OVERRIDE")"
else
  WS="$(assert_safe "$(cd "$SCRIPT_DIR/../.." && pwd -P)")"
fi

MANIFEST_JSON="$(read_manifest "$WS")"
SKILLS_JSON="$(read_skills_lock "$WS")"

targets=()
while IFS=$'\t' read -r name path; do
  if [[ "$name" == "fleet-command" && "$NUKE" != true ]]; then continue; fi
  targets+=("$WS/$path")
done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.repos[] | [.name, .path] | @tsv')

while read -r target; do targets+=("$WS/$target"); done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.agents | to_entries[] | .value.target')
while read -r target; do targets+=("$WS/$target"); done < <(printf '%s' "$SKILLS_JSON" | jq -r '.skills[].target')

for cache in .uv-cache .gstack .superpowers .worktrees .pytest_cache; do
  targets+=("$WS/$cache")
done

filtered=()
for t in "${targets[@]}"; do
  skip=false
  if (( ${#KEEP_PATTERNS[@]} > 0 )); then
    for pat in "${KEEP_PATTERNS[@]}"; do
      [[ "$t" == *"$pat"* ]] && { skip=true; break; }
    done
  fi
  $skip || { [[ -e "$t" ]] && filtered+=("$t"); }
done

printf 'Workspace: %s\n' "$WS"
printf 'Mode:      %s\n\n' "$($APPLY && echo apply || echo dry-run)"

if (( ${#filtered[@]} == 0 )); then echo "Nothing to remove."; exit 0; fi

printf 'Targets:\n'
printf '  %s\n' "${filtered[@]}" | sort -u

$APPLY || { echo; echo "Dry-run only. Re-run with --apply to delete."; exit 0; }

if $NUKE; then
  while IFS=$'\t' read -r name path; do
    [[ -d "$WS/$path" ]] || continue
    if [[ -n "$(git -C "$WS/$path" status --porcelain)" || -n "$(git -C "$WS/$path" log '@{upstream}..' 2>/dev/null)" ]]; then
      echo "Refusing --nuke: $name has uncommitted or unpushed work." >&2
      exit 1
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.repos[] | [.name, .path] | @tsv')
  printf '\nType NUKE to confirm deletion (including fleet-command): '
else
  printf '\nType DELETE to confirm removal: '
fi
read -r confirm
expected="$($NUKE && echo NUKE || echo DELETE)"
[[ "$confirm" == "$expected" ]] || { echo "Confirmation did not match. Aborting." >&2; exit 1; }

for t in "${filtered[@]}"; do
  rm -rf "$t"
  printf '[gone] %s\n' "$t"
done
echo Done.
