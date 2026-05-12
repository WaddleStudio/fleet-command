#!/usr/bin/env bash
# bootstrap/bootstrap.sh — workspace installer (macOS / Linux).
#
# Usage:
#   bootstrap.sh [--install-deps] [--skip-deps] [--skip-repos] [--skip-skills] [--skip-agents]
#                [--update] [--dry-run] [--workspace <path>] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

INSTALL_DEPS=false
SKIP_DEPS=false
SKIP_SKILLS=false
SKIP_REPOS=false
SKIP_AGENTS=false
UPDATE=false
DRY_RUN=false
WORKSPACE_OVERRIDE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-deps)  INSTALL_DEPS=true; shift ;;
    --skip-deps)     SKIP_DEPS=true; shift ;;
    --skip-skills)   SKIP_SKILLS=true; shift ;;
    --skip-repos)    SKIP_REPOS=true; shift ;;
    --skip-agents)   SKIP_AGENTS=true; shift ;;
    --update)        UPDATE=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --workspace)     WORKSPACE_OVERRIDE="$2"; shift 2 ;;
    --verbose)       VERBOSE=true; shift ;;
    -h|--help)       sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

require_jq
WS="$(resolve_workspace_root "$WORKSPACE_OVERRIDE")"
MANIFEST_JSON="$(read_manifest "$WS")"
SKILLS_JSON="$(read_skills_lock "$WS")"
OS_KEY="$(get_os_key)"

echo "Workspace: $WS"
echo "OS:        $OS_KEY"
echo "Mode:      $($DRY_RUN && echo dry-run || echo apply)"

stage_osdeps() {
  write_stage 'Stage 1: OS dependencies'
  local manager
  manager="$(printf '%s' "$MANIFEST_JSON" | jq -r --arg os "$OS_KEY" '.osDeps[$os].manager // empty')"
  if [[ -z "$manager" ]]; then echo "No osDeps for $OS_KEY"; return; fi
  local missing=()
  while IFS=$'\t' read -r id verify optional; do
    if eval "$verify" >/dev/null 2>&1; then
      echo "[ok]   $id"
    elif [[ "$optional" == "true" ]]; then
      echo "[skip] $id (optional)"
    else
      echo "[miss] $id"
      missing+=("$id")
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r --arg os "$OS_KEY" '.osDeps[$os].packages[] | [.id, (.verifyCmd // (.id+" --version")), (.optional // false | tostring)] | @tsv')
  if (( ${#missing[@]} == 0 )); then return; fi
  if ! $INSTALL_DEPS; then
    echo
    echo "Re-run with --install-deps to install via $manager."
    return
  fi
  for id in "${missing[@]}"; do
    if $DRY_RUN; then
      write_dry_run "$manager install $id"
    else
      case "$manager" in
        brew)   brew install "$id" ;;
        winget) winget install --id "$id" --silent --accept-package-agreements --accept-source-agreements ;;
        *) echo "Manager $manager not supported in shell; install $id manually." ;;
      esac
    fi
  done
}

stage_repos() {
  write_stage 'Stage 2: Sub-repositories'
  while IFS=$'\t' read -r name path cloneUrl ref; do
    if [[ "$name" == "fleet-command" ]]; then echo "[self] fleet-command"; continue; fi
    local target="$WS/$path"
    if [[ ! -d "$target" ]]; then
      if $DRY_RUN; then
        write_dry_run "git clone --branch $ref $cloneUrl $target"
      else
        git clone --branch "$ref" "$cloneUrl" "$target"
      fi
      continue
    fi
    local current
    current="$(git -C "$target" rev-parse --abbrev-ref HEAD)"
    if [[ "$current" != "$ref" ]]; then
      echo "[drift] $name: on '$current', manifest '$ref'"
      if $UPDATE && ! $DRY_RUN; then
        git -C "$target" fetch origin
        git -C "$target" switch "$ref"
        git -C "$target" pull --ff-only
      elif $UPDATE; then
        write_dry_run "git -C $target switch $ref && git pull --ff-only"
      fi
    else
      echo "[ok]    $name on $current"
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.repos[] | [.name, .path, .cloneUrl, .ref] | @tsv')
}

stage_skills() {
  write_stage 'Stage 3: Upstream skills'
  while IFS=$'\t' read -r id cloneUrl target sha; do
    local target_abs="$WS/$target"
    if [[ ! -d "$target_abs" ]]; then
      if $DRY_RUN; then
        write_dry_run "git clone $cloneUrl $target_abs && git checkout $sha"
      else
        git clone "$cloneUrl" "$target_abs"
        git -C "$target_abs" checkout --quiet "$sha"
      fi
    else
      local actual
      actual="$(git -C "$target_abs" rev-parse HEAD)"
      if [[ "$actual" != "$sha" ]]; then
        echo "[drift] $id: HEAD $actual, expected $sha"
        if $UPDATE && ! $DRY_RUN; then
          git -C "$target_abs" fetch origin
          git -C "$target_abs" checkout --quiet "$sha"
        elif $UPDATE; then
          write_dry_run "git -C $target_abs checkout $sha"
        fi
      else
        echo "[ok]    $id @ ${sha:0:7}"
      fi
    fi
  done < <(printf '%s' "$SKILLS_JSON" | jq -r '.skills[] | [.id, .cloneUrl, .target, .ref.sha] | @tsv')
}

stage_agents() {
  write_stage 'Stage 4: Agent host configuration'
  while IFS=$'\t' read -r name templateSource target file; do
    local src="$WS/$templateSource/$file"
    local dst="$WS/$target/$file"
    if [[ ! -f "$src" ]]; then echo "[warn] $name: template missing $src"; continue; fi
    mkdir -p "$WS/$target"
    if [[ -e "$dst" ]]; then
      echo "[keep] $name/$file (exists)"
      continue
    fi
    if $DRY_RUN; then
      write_dry_run "copy $src -> $dst"
    else
      cp "$src" "$dst"
      echo "[copy] $name/$file"
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.agents | to_entries[] | .key as $k | .value as $v | $v.files[] | [$k, $v.templateSource, $v.target, .] | @tsv')
}

stage_final() {
  write_stage 'Stage 5: Final checks'
  cat <<'EOM'
- Run 'claude login' to authenticate Claude Code.
- Run 'codex login' to authenticate Codex CLI.
- Re-run with --update to fast-forward refs.

Bootstrap finished.
EOM
}

$SKIP_DEPS   || stage_osdeps
$SKIP_REPOS  || stage_repos
$SKIP_SKILLS || stage_skills
$SKIP_AGENTS || stage_agents
stage_final
