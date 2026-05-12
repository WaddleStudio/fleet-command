# scripts/update-skill-lock.ps1 — resolve a tag/SHA for one upstream skill, print diff, do not commit.
#
# Usage:
#   update-skill-lock.ps1 --tool <id> --to <tag|sha|branch> [--dry-run]

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Tool = ''
$To   = ''
$DryRun = $false

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch -Regex ($arg) {
        '^(--tool|-Tool)$'      { $Tool = $args[$i + 1]; $i += 2 }
        '^(--to|-To)$'          { $To   = $args[$i + 1]; $i += 2 }
        '^(--dry-run|-DryRun)$' { $DryRun = $true; $i++ }
        '^(-h|--help)$' {
            Get-Content -LiteralPath $PSCommandPath -TotalCount 5 | Select-Object -Skip 2
            exit 0
        }
        default {
            Write-Error "Unknown argument: $arg"
            exit 2
        }
    }
}
if (-not $Tool -or -not $To) {
    Write-Error "Usage: update-skill-lock.ps1 --tool <id> --to <tag|sha|branch> [--dry-run]"
    exit 2
}

$lockPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../workspace/skills.lock.json')).Path
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json

$skill = $lock.skills | Where-Object { $_.id -eq $Tool }
if (-not $skill) { throw "Tool '$Tool' not found in skills.lock.json." }

$sha = $null
$tag = $null
if ($To -match '^[0-9a-f]{40}$') {
    $sha = $To
} else {
    $tagRef = "refs/tags/$To"
    $line = (& git ls-remote $skill.cloneUrl $tagRef 2>$null) | Select-Object -First 1
    if (-not $line) {
        $line = (& git ls-remote $skill.cloneUrl "refs/heads/$To" 2>$null) | Select-Object -First 1
        if (-not $line) { throw "Could not resolve $To against $($skill.cloneUrl)" }
    } else {
        $tag = $To
    }
    $sha = ($line -split '\s+')[0]
}

$today = (Get-Date -Format 'yyyy-MM-dd')
$old = $skill.ref.sha
$skill.ref = [PSCustomObject]@{ sha = $sha; tag = $tag; resolvedAt = $today }

if ($old -eq $sha) {
    Write-Host "$Tool already pinned at $sha; no change."
    exit 0
}

$json = ($lock | ConvertTo-Json -Depth 10) + "`n"

Write-Host "--- skills.lock.json ($Tool)"
Write-Host "-  sha: $old"
Write-Host "+  sha: $sha"
if ($tag) { Write-Host "+  tag: $tag" }
Write-Host "+  resolvedAt: $today"

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry-run: re-run without --dry-run to write the file. The change is not auto-committed."
    exit 0
}

Set-Content -LiteralPath $lockPath -Value $json -Encoding utf8
Write-Host ""
Write-Host "Wrote $lockPath. Review the diff and commit manually."
