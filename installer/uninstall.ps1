param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,
    [switch]$WhatIf,
    [switch]$ForceManagedRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[copilot-security-pack] $Message"
}

function Get-Sha256([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

$targetRoot = (Resolve-Path $TargetRepo).Path
$statePath = Join-Path $targetRoot '.security/copilot-pack-state.json'
$targetManifest = Join-Path $targetRoot '.security/copilot-pack.yml'

if (-not (Test-Path $statePath)) {
    throw "Managed-file state was not found at '$statePath'. Refusing blind uninstall."
}

$state = Get-Content $statePath -Raw | ConvertFrom-Json
$removed = [System.Collections.Generic.List[string]]::new()
$preserved = [System.Collections.Generic.List[string]]::new()

foreach ($entry in @($state.managedFiles)) {
    $relative = [string]$entry.path
    $expectedHash = [string]$entry.sha256
    $path = Join-Path $targetRoot $relative

    if (-not (Test-Path $path)) { continue }

    $currentHash = Get-Sha256 $path
    if ($currentHash -ne $expectedHash -and -not $ForceManagedRemoval) {
        $preserved.Add($relative) | Out-Null
        continue
    }

    if (-not $WhatIf) {
        Remove-Item -Force -Path $path
    }
    $removed.Add($relative) | Out-Null
}

if (-not $WhatIf) {
    if (Test-Path $targetManifest) { Remove-Item -Force $targetManifest }
    if (Test-Path $statePath) { Remove-Item -Force $statePath }
}

Write-Step 'Uninstall summary'
Write-Host "  Removed managed files: $($removed.Count)"
foreach ($item in $removed) { Write-Host "    - $item" }
Write-Host "  Preserved modified managed files: $($preserved.Count)"
foreach ($item in $preserved) { Write-Host "    = $item" }

if ($preserved.Count -gt 0) {
    Write-Step 'Some managed files were locally modified and were preserved. Remove them manually only after review, or use -ForceManagedRemoval explicitly.'
}

if ($WhatIf) {
    Write-Step 'WhatIf mode: no target files were removed.'
} else {
    Write-Step 'Uninstall complete. Repository-owned policy, baseline, exception, CI, and pre-existing Copilot files were not removed.'
}
