#!/usr/bin/env bash
# scripts/update-skill-lock.sh — resolve tag/SHA for one upstream skill, print diff, no commit.

set -euo pipefail

TOOL=""
TO=""
DRY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="$2"; shift 2 ;;
    --to)   TO="$2"; shift 2 ;;
    --dry-run) DRY=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$TOOL" && -n "$TO" ]] || { echo "Usage: $0 --tool <id> --to <tag|sha> [--dry-run]" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "jq required." >&2; exit 1; }

LOCK="$(cd "$(dirname "$0")/.." && pwd -P)/workspace/skills.lock.json"
[[ -f "$LOCK" ]] || { echo "skills.lock.json missing: $LOCK" >&2; exit 1; }

clone_url=$(jq -r --arg id "$TOOL" '.skills[] | select(.id==$id) | .cloneUrl' "$LOCK")
old_sha=$(jq -r --arg id "$TOOL" '.skills[] | select(.id==$id) | .ref.sha' "$LOCK")
[[ -n "$clone_url" ]] || { echo "Tool '$TOOL' not in lock." >&2; exit 1; }

if [[ "$TO" =~ ^[0-9a-f]{40}$ ]]; then
  sha="$TO"; tag="null"
else
  line=$(git ls-remote "$clone_url" "refs/tags/$TO" | head -n1 || true)
  if [[ -n "$line" ]]; then tag="\"$TO\""; else
    line=$(git ls-remote "$clone_url" "refs/heads/$TO" | head -n1 || true)
    [[ -n "$line" ]] || { echo "Cannot resolve $TO against $clone_url" >&2; exit 1; }
    tag="null"
  fi
  sha=$(printf '%s' "$line" | awk '{print $1}')
fi

today=$(date +%F)

if [[ "$old_sha" == "$sha" ]]; then
  echo "$TOOL already pinned at $sha; no change."
  exit 0
fi

echo "--- skills.lock.json ($TOOL)"
echo "-  sha: $old_sha"
echo "+  sha: $sha"
echo "+  tag: $tag"
echo "+  resolvedAt: $today"

if $DRY; then
  echo
  echo "Dry-run: re-run without --dry-run to write."
  exit 0
fi

tmp=$(mktemp)
jq --arg id "$TOOL" --arg sha "$sha" --argjson tag "$tag" --arg at "$today" \
   '(.skills[] | select(.id==$id) | .ref) = {sha:$sha, tag:$tag, resolvedAt:$at}' \
   "$LOCK" > "$tmp"
mv "$tmp" "$LOCK"
echo
echo "Wrote $LOCK. Review and commit manually."
