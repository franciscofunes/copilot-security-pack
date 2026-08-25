param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,
    [switch]$AllowDowngrade,
    [switch]$ForceManagedOverwrite,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$targetRoot = (Resolve-Path $TargetRepo).Path
$packRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetManifest = Join-Path $targetRoot '.security/copilot-pack.yml'
$statePath = Join-Path $targetRoot '.security/copilot-pack-state.json'
$versionPath = Join-Path $packRoot 'VERSION'

if (-not (Test-Path $targetManifest)) {
    throw "Copilot Security Pack is not installed in '$targetRoot'. Use installer/install.ps1 for the first installation."
}
if (-not (Test-Path $statePath)) {
    throw "Managed-file state is missing: $statePath. Upgrade cannot safely determine local modifications. Reinstall or reconcile explicitly before upgrading."
}
if (-not (Test-Path $versionPath)) { throw "VERSION file not found: $versionPath" }

$currentText = Get-Content $targetManifest -Raw
$currentMatch = [regex]::Match($currentText, '(?m)^packVersion:\s*(.+?)\s*$')
if (-not $currentMatch.Success) {
    throw "Could not determine installed packVersion from $targetManifest"
}

$currentVersionText = $currentMatch.Groups[1].Value.Trim()
$targetVersionText = (Get-Content $versionPath -Raw).Trim()

function Convert-SemVer([string]$Value) {
    $core = ($Value -split '-', 2)[0]
    try { return [version]$core }
    catch { throw "Unsupported semantic version '$Value'." }
}

$currentVersion = Convert-SemVer $currentVersionText
$targetVersion = Convert-SemVer $targetVersionText

Write-Host "[copilot-security-pack] Installed version: $currentVersionText"
Write-Host "[copilot-security-pack] Available version: $targetVersionText"

if ($targetVersion -lt $currentVersion -and -not $AllowDowngrade) {
    throw "Refusing downgrade from $currentVersionText to $targetVersionText. Re-run with -AllowDowngrade only when rollback is intentional."
}

if ($currentVersionText -eq $targetVersionText) {
    Write-Host '[copilot-security-pack] Versions match. Running idempotent reconciliation of pack-managed files.'
}

& (Join-Path $PSScriptRoot 'install.ps1') `
    -TargetRepo $targetRoot `
    -WhatIf:$WhatIf `
    -ForceManagedOverwrite:$ForceManagedOverwrite

if (-not $WhatIf) {
    Write-Host "[copilot-security-pack] Upgrade/reconciliation complete. Review the Git diff before committing."
}
