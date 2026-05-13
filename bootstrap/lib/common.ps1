# bootstrap/lib/common.ps1 — shared helpers for bootstrap / teardown / update-skill-lock.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-WorkspaceRoot {
    param(
        [Parameter(Mandatory = $false)] [string] $Override
    )
    if ($Override) {
        $resolved = (Resolve-Path -LiteralPath $Override).Path
    } else {
        $libDir = Split-Path -Parent $PSCommandPath
        $bootstrapDir = Split-Path -Parent $libDir
        $fleetCommandDir = Split-Path -Parent $bootstrapDir
        $resolved = (Resolve-Path -LiteralPath (Join-Path $fleetCommandDir '..')).Path
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Workspace path does not exist or is not a directory: $resolved"
    }
    return $resolved
}

function Read-Manifest {
    param([Parameter(Mandatory = $true)] [string] $WorkspaceRoot)
    $path = Join-Path $WorkspaceRoot 'fleet-command/workspace/workspace.manifest.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "workspace.manifest.json not found at $path"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Read-SkillsLock {
    param([Parameter(Mandatory = $true)] [string] $WorkspaceRoot)
    $path = Join-Path $WorkspaceRoot 'fleet-command/workspace/skills.lock.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "skills.lock.json not found at $path"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Write-Stage {
    param([Parameter(Mandatory = $true)] [string] $Name)
    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
}

function Write-DryRun {
    param([Parameter(Mandatory = $true)] [string] $Message)
    Write-Host "[dry-run] $Message" -ForegroundColor Yellow
}

function Test-CommandRuns {
    param([Parameter(Mandatory = $true)] [string] $Command)
    try {
        $null = Invoke-Expression $Command 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-OSKey {
    if ($PSVersionTable.PSEdition -eq 'Desktop') { return 'windows' }
    if ($IsWindows) { return 'windows' }
    if ($IsMacOS) { return 'macos' }
    return 'linux'
}
