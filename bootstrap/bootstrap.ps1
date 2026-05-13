# bootstrap/bootstrap.ps1 — workspace installer for Windows / macOS / Linux (PowerShell 5.1+).
#
# Usage:
#   bootstrap.ps1 [--install-deps] [--skip-deps] [--skip-repos] [--skip-skills] [--skip-agents]
#                 [--update] [--dry-run] [--workspace <path>] [--verbose]
#
# Stages: osDeps -> repos -> skills -> agents -> final checks.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/common.ps1')

$InstallDeps = $false
$SkipDeps    = $false
$SkipSkills  = $false
$SkipRepos   = $false
$SkipAgents  = $false
$Update      = $false
$DryRun      = $false
$Workspace   = ''
$VerboseFlag = $false

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch -Regex ($arg) {
        '^(--install-deps|-InstallDeps)$' { $InstallDeps = $true; $i++ }
        '^(--skip-deps|-SkipDeps)$'       { $SkipDeps    = $true; $i++ }
        '^(--skip-skills|-SkipSkills)$'   { $SkipSkills  = $true; $i++ }
        '^(--skip-repos|-SkipRepos)$'     { $SkipRepos   = $true; $i++ }
        '^(--skip-agents|-SkipAgents)$'   { $SkipAgents  = $true; $i++ }
        '^(--update|-Update)$'            { $Update      = $true; $i++ }
        '^(--dry-run|-DryRun)$'           { $DryRun      = $true; $i++ }
        '^(--verbose|-Verbose)$'          { $VerboseFlag = $true; $i++ }
        '^(--workspace|-Workspace)$'      { $Workspace   = $args[$i + 1]; $i += 2 }
        '^(-h|--help)$' {
            Get-Content -LiteralPath $PSCommandPath -TotalCount 8 | Select-Object -Skip 2
            exit 0
        }
        default {
            Write-Error "Unknown argument: $arg"
            exit 2
        }
    }
}

$workspaceRoot = Resolve-WorkspaceRoot -Override $Workspace
$manifest      = Read-Manifest    -WorkspaceRoot $workspaceRoot
$skillsLock    = Read-SkillsLock  -WorkspaceRoot $workspaceRoot
$osKey         = Get-OSKey

Write-Host "Workspace: $workspaceRoot"
Write-Host "OS:        $osKey"
Write-Host "Mode:      $(if ($DryRun) { 'dry-run' } else { 'apply' })"

function Invoke-OsDepsStage {
    Write-Stage 'Stage 1: OS dependencies'
    $osDeps = $manifest.osDeps.$osKey
    if (-not $osDeps) {
        Write-Host "No osDeps declared for $osKey; skipping."
        return
    }
    $missing = @()
    foreach ($pkg in $osDeps.packages) {
        $ok = Test-CommandRuns $pkg.verifyCmd
        if ($ok) {
            Write-Host "[ok]   $($pkg.id)"
        } else {
            $isOptional = $false
            if ($pkg.PSObject.Properties.Name -contains 'optional') { $isOptional = [bool]$pkg.optional }
            if ($isOptional) {
                Write-Host "[skip] $($pkg.id) (optional, not installed)"
            } else {
                Write-Host "[miss] $($pkg.id)" -ForegroundColor Yellow
                $missing += $pkg
            }
        }
    }
    if ($missing.Count -eq 0) { return }
    if (-not $InstallDeps) {
        Write-Host ""
        Write-Host "Missing packages above. Re-run with --install-deps to install via $($osDeps.manager)." -ForegroundColor Yellow
        return
    }
    foreach ($pkg in $missing) {
        if ($DryRun) {
            Write-DryRun "$($osDeps.manager) install $($pkg.id)"
        } else {
            switch ($osDeps.manager) {
                'winget' { winget install --id $pkg.id --silent --accept-package-agreements --accept-source-agreements }
                'brew'   { brew install $pkg.id }
                default  { Write-Host "Manager '$($osDeps.manager)' not yet supported; install manually: $($pkg.id)" }
            }
        }
    }
}

function Invoke-ReposStage {
    Write-Stage 'Stage 2: Sub-repositories'
    foreach ($repo in $manifest.repos) {
        if ($repo.name -eq 'fleet-command') {
            Write-Host "[self] fleet-command (already cloned)"
            continue
        }
        $target = Join-Path $workspaceRoot $repo.path
        if (-not (Test-Path -LiteralPath $target)) {
            if ($DryRun) {
                Write-DryRun "git clone --branch $($repo.ref) $($repo.cloneUrl) $target"
            } else {
                git clone --branch $repo.ref $repo.cloneUrl $target
            }
            continue
        }
        Push-Location $target
        try {
            $current = (& git rev-parse --abbrev-ref HEAD).Trim()
            if ($current -ne $repo.ref) {
                Write-Host "[drift] $($repo.name): on '$current', manifest says '$($repo.ref)'" -ForegroundColor Yellow
                if ($Update -and -not $DryRun) {
                    git fetch origin
                    git switch $repo.ref
                    git pull --ff-only
                } elseif ($Update -and $DryRun) {
                    Write-DryRun "git switch $($repo.ref) && git pull --ff-only ($target)"
                }
            } else {
                Write-Host "[ok]    $($repo.name) on $current"
            }
        } finally {
            Pop-Location
        }
    }
}

function Invoke-SkillsStage {
    Write-Stage 'Stage 3: Upstream skills'
    foreach ($skill in $skillsLock.skills) {
        $target = Join-Path $workspaceRoot $skill.target
        $expectedSha = $skill.ref.sha
        if (-not (Test-Path -LiteralPath $target)) {
            if ($DryRun) {
                Write-DryRun "git clone $($skill.cloneUrl) $target && git checkout $expectedSha"
            } else {
                git clone $skill.cloneUrl $target
                Push-Location $target
                try { git checkout --quiet $expectedSha } finally { Pop-Location }
            }
        } else {
            Push-Location $target
            try {
                $actualSha = (& git rev-parse HEAD).Trim()
                if ($actualSha -ne $expectedSha) {
                    Write-Host "[drift] $($skill.id): HEAD $actualSha, expected $expectedSha" -ForegroundColor Yellow
                    if ($Update -and -not $DryRun) {
                        git fetch origin
                        git checkout --quiet $expectedSha
                    } elseif ($Update -and $DryRun) {
                        Write-DryRun "git checkout $expectedSha ($target)"
                    }
                } else {
                    Write-Host "[ok]    $($skill.id) @ $($expectedSha.Substring(0,7))"
                }
            } finally {
                Pop-Location
            }
        }
        $hasPostClone = $skill.PSObject.Properties.Name -contains 'postClone'
        if ($hasPostClone -and $skill.postClone) {
            foreach ($post in $skill.postClone) {
                $postCwd = Join-Path $workspaceRoot $post.cwd
                if ($DryRun) {
                    Write-DryRun "($postCwd) $($post.cmd)"
                } else {
                    Push-Location $postCwd
                    try { Invoke-Expression $post.cmd } finally { Pop-Location }
                }
            }
        }
    }
}

function Invoke-AgentsStage {
    Write-Stage 'Stage 4: Agent host configuration'
    foreach ($prop in $manifest.agents.PSObject.Properties) {
        $name = $prop.Name
        $agent = $prop.Value
        $sourceDir = Join-Path $workspaceRoot $agent.templateSource
        $targetDir = Join-Path $workspaceRoot $agent.target
        if (-not (Test-Path -LiteralPath $sourceDir)) {
            Write-Host "[skip] ${name}: template source missing at $sourceDir"
            continue
        }
        if (-not (Test-Path -LiteralPath $targetDir)) {
            if ($DryRun) { Write-DryRun "mkdir $targetDir" } else { New-Item -ItemType Directory -Path $targetDir | Out-Null }
        }
        foreach ($file in $agent.files) {
            $src = Join-Path $sourceDir $file
            $dst = Join-Path $targetDir $file
            if (-not (Test-Path -LiteralPath $src)) {
                Write-Host "[warn] ${name}: template missing $src"
                continue
            }
            if (Test-Path -LiteralPath $dst) {
                Write-Host "[keep] $name/$file (exists; use sync-config to overwrite — deferred)" -ForegroundColor Yellow
                continue
            }
            if ($DryRun) {
                Write-DryRun "copy $src -> $dst"
            } else {
                Copy-Item -LiteralPath $src -Destination $dst -Force
                Write-Host "[copy] $name/$file"
            }
        }
    }
}

function Invoke-FinalChecks {
    Write-Stage 'Stage 5: Final checks'
    Write-Host "- Run 'claude login' if you have not authenticated Claude Code on this machine."
    Write-Host "- Run 'codex login' if you have not authenticated Codex CLI."
    Write-Host "- Re-run with --update to fast-forward repos and skills to manifest refs."
    Write-Host ""
    Write-Host "Bootstrap finished."
}

if (-not $SkipDeps)    { Invoke-OsDepsStage }
if (-not $SkipRepos)   { Invoke-ReposStage }
if (-not $SkipSkills)  { Invoke-SkillsStage }
if (-not $SkipAgents)  { Invoke-AgentsStage }
Invoke-FinalChecks
