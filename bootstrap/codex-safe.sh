#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: codex-safe.sh must be run from inside a Git repository." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

cat <<MSG
Detected workspace: $repo_root

Safety warnings before launching Codex:
- Codex will be launched with sandbox: workspace-write
- Codex will be launched with approval: always
- Do not approve commands that touch:
  - \$HOME
  - ~/.ssh
  - ~/.aws
  - ~/.config
  - ~/.claude
  - ~/.codex
  - browser profiles
  - Desktop
  - Downloads
  - credential stores
- Do not approve sudo, global installs, credential-helper changes, or commands that persist tokens.

Launching: codex --sandbox workspace-write --ask-for-approval always
MSG

exec codex --sandbox workspace-write --ask-for-approval always "$@"
