# bootstrap/teardown.ps1 — workspace cleanup (dry-run by default).
#
# Usage:
#   teardown.ps1 [--apply] [--nuke] [--workspace <path>] [--keep <pattern>]... [--verbose]
#
# Dry-run by default. --apply requires typing DELETE; --nuke requires NUKE and clean+pushed repos.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/common.ps1')

$Apply = $false
$Nuke = $false
$Workspace = ''
$Keep = @()
$VerboseFlag = $false

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch -Regex ($arg) {
        '^(--apply|-Apply)$'         { $Apply = $true; $i++ }
        '^(--nuke|-Nuke)$'           { $Nuke = $true; $i++ }
        '^(--verbose|-Verbose)$'     { $VerboseFlag = $true; $i++ }
        '^(--workspace|-Workspace)$' { $Workspace = $args[$i + 1]; $i += 2 }
        '^(--keep|-Keep)$'           { $Keep += $args[$i + 1]; $i += 2 }
        '^(-h|--help)$' {
            Get-Content -LiteralPath $PSCommandPath -TotalCount 6 | Select-Object -Skip 2
            exit 0
        }
        default {
            Write-Error "Unknown argument: $arg"
            exit 2
        }
    }
}

function Assert-WorkspaceSafe {
    param([string] $Path)
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw "Workspace must be an absolute path: $Path"
    }
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path.TrimEnd('\','/')
    if ($resolved -eq '' -or $resolved -eq '/' -or $resolved -match '^[A-Za-z]:[\\/]?$') {
        throw "Refusing to target filesystem root: $resolved"
    }
    $homeResolved = (Resolve-Path -LiteralPath $HOME).Path.TrimEnd('\','/')
    if ($resolved -ieq $homeResolved) { throw "Refusing to target HOME: $resolved" }
    foreach ($p in @('.ssh','.aws','.config','.claude','.codex')) {
        $protected = Join-Path $homeResolved $p
        if (Test-Path -LiteralPath $protected) {
            $protectedResolved = (Resolve-Path -LiteralPath $protected).Path.TrimEnd('\','/')
            if ($resolved -ieq $protectedResolved) {
                throw "Refusing protected directory under HOME: $resolved"
            }
        }
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Workspace does not exist: $resolved"
    }
    $children = Get-ChildItem -LiteralPath $resolved -Force -ErrorAction SilentlyContinue
    if (-not $children) {
        throw "Refusing to clean empty workspace: $resolved"
    }
    return $resolved
}

$wsArg = if ($Workspace) { $Workspace } else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path }
$workspaceRoot = Assert-WorkspaceSafe -Path $wsArg
$manifest = Read-Manifest -WorkspaceRoot $workspaceRoot
$skillsLock = Read-SkillsLock -WorkspaceRoot $workspaceRoot

$targets = New-Object System.Collections.Generic.List[string]
foreach ($repo in $manifest.repos) {
    if ($repo.name -eq 'fleet-command' -and -not $Nuke) { continue }
    $targets.Add((Join-Path $workspaceRoot $repo.path))
}
foreach ($prop in $manifest.agents.PSObject.Properties) {
    $targets.Add((Join-Path $workspaceRoot $prop.Value.target))
}
foreach ($skill in $skillsLock.skills) {
    $targets.Add((Join-Path $workspaceRoot $skill.target))
}
foreach ($cache in @('.uv-cache','.gstack','.superpowers','.worktrees','.pytest_cache')) {
    $targets.Add((Join-Path $workspaceRoot $cache))
}

if ($Keep.Count -gt 0) {
    $filtered = New-Object System.Collections.Generic.List[string]
    foreach ($t in $targets) {
        $skip = $false
        foreach ($pat in $Keep) {
            if ($t -like "*$pat*") { $skip = $true; break }
        }
        if (-not $skip) { $filtered.Add($t) }
    }
    $targets = $filtered
}

$existing = @($targets | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique)

Write-Host "Workspace: $workspaceRoot"
Write-Host "Mode:      $(if ($Apply) { 'apply' } else { 'dry-run' })"
Write-Host ""

if ($existing.Count -eq 0) {
    Write-Host "Nothing to remove."
    return
}

Write-Host "Targets:"
foreach ($t in $existing) { Write-Host "  $t" }

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry-run only. Re-run with --apply to delete the listed paths."
    return
}

if ($Nuke) {
    foreach ($repo in $manifest.repos) {
        $repoPath = Join-Path $workspaceRoot $repo.path
        if (-not (Test-Path -LiteralPath $repoPath)) { continue }
        Push-Location $repoPath
        try {
            $dirty = (& git status --porcelain).Trim()
            $unpushed = (& git log "@{upstream}..").Trim()
            if ($dirty -or $unpushed) {
                throw "Refusing --nuke: $($repo.name) has uncommitted or unpushed work."
            }
        } finally {
            Pop-Location
        }
    }
    Write-Host ""
    $confirm = Read-Host "Type NUKE to confirm deletion (including fleet-command)"
    if ($confirm -ne 'NUKE') { throw "Confirmation did not match. Aborting." }
} else {
    Write-Host ""
    $confirm = Read-Host "Type DELETE to confirm removal of the listed paths"
    if ($confirm -ne 'DELETE') { throw "Confirmation did not match. Aborting." }
}

foreach ($t in $existing) {
    Remove-Item -LiteralPath $t -Recurse -Force
    Write-Host "[gone] $t"
}
Write-Host "Done."
