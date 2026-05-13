#!/usr/bin/env bash
# bootstrap/lib/common.sh — shared helpers for bootstrap / teardown / update-skill-lock.

set -euo pipefail

resolve_workspace_root() {
  local override="${1:-}"
  local resolved
  if [[ -n "$override" ]]; then
    resolved="$(cd "$override" && pwd -P)"
  else
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
    resolved="$(cd "$script_dir/../.." && pwd -P)"
  fi
  if [[ ! -d "$resolved" ]]; then
    echo "Workspace path does not exist: $resolved" >&2
    return 1
  fi
  if [[ -f "$resolved/workspace/workspace.manifest.json" && "$(basename "$resolved")" == "fleet-command" ]]; then
    resolved="$(cd "$resolved/.." && pwd -P)"
  fi
  printf '%s' "$resolved"
}

read_manifest() {
  local ws="$1"
  local path="$ws/fleet-command/workspace/workspace.manifest.json"
  if [[ ! -f "$path" ]]; then
    echo "workspace.manifest.json not found at $path" >&2
    return 1
  fi
  cat "$path"
}

read_skills_lock() {
  local ws="$1"
  local path="$ws/fleet-command/workspace/skills.lock.json"
  if [[ ! -f "$path" ]]; then
    echo "skills.lock.json not found at $path" >&2
    return 1
  fi
  cat "$path"
}

write_stage() {
  printf '\n=== %s ===\n' "$1"
}

write_dry_run() {
  printf '[dry-run] %s\n' "$1"
}

get_os_key() {
  case "$(uname -s)" in
    Darwin*) echo macos ;;
    Linux*)  echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required by bootstrap/teardown scripts on Unix." >&2
    echo "Install via:  brew install jq  (macOS)  or  apt-get install jq  (Linux)" >&2
    return 1
  fi
}
