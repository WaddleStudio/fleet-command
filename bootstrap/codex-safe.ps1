# bootstrap/codex-safe.ps1 — launch Codex CLI with workspace-write sandbox + approval=always.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $repoRoot = (& git rev-parse --show-toplevel 2>$null)
    if (-not $repoRoot) { throw "not a git repo" }
} catch {
    Write-Error "codex-safe.ps1 must run inside a Git repository."
    exit 1
}
Set-Location -LiteralPath $repoRoot

Write-Host @"
Detected workspace: $repoRoot

Safety warnings before launching Codex:
- Codex will be launched with sandbox: workspace-write
- Codex will be launched with approval: always
- Do not approve commands that touch:
  - `$HOME, ~/.ssh, ~/.aws, ~/.config, ~/.claude, ~/.codex
  - browser profiles, Desktop, Downloads, credential stores
- Do not approve sudo, global installs, credential-helper changes, or commands that persist tokens.

Launching: codex --sandbox workspace-write --ask-for-approval always
"@

codex --sandbox workspace-write --ask-for-approval always @args
