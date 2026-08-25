Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$packRoot = Join-Path $repoRoot 'pack'
$manifestPath = Join-Path $repoRoot 'installer/pack-manifest.json'

Assert-True (Test-Path $packRoot) 'canonical pack/ directory is missing'
Assert-True (Test-Path $manifestPath) 'installer manifest is missing'

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$declaredSources = @()

foreach ($item in @($manifest.managed) + @($manifest.createIfMissing)) {
    $source = [string]$item.source
    Assert-True (-not [string]::IsNullOrWhiteSpace($source)) 'manifest contains an empty source path'
    Assert-True ($source -match '^(\.github|\.security)/') "manifest source must be repository-relative payload content: $source"

    $payloadPath = Join-Path $packRoot $source
    Assert-True (Test-Path $payloadPath) "manifest source does not exist under pack/: $source"
    Assert-True (-not (Get-Item $payloadPath).PSIsContainer) "manifest source must be a file: $source"
    $declaredSources += $source.Replace('\\','/')
}

$duplicates = @($declaredSources | Group-Object | Where-Object Count -gt 1)
Assert-True ($duplicates.Count -eq 0) ("manifest contains duplicate source entries: " + (($duplicates.Name) -join ', '))

$forbidden = @(
    'pack/.github/workflows',
    'pack/installer',
    'pack/tests'
)
foreach ($path in $forbidden) {
    Assert-True (-not (Test-Path (Join-Path $repoRoot $path))) "development-only content leaked into canonical payload: $path"
}

Assert-True (Test-Path (Join-Path $packRoot '.github/copilot-instructions.md')) 'canonical global Copilot instructions are missing'
Assert-True (Test-Path (Join-Path $packRoot '.security/run-security.ps1')) 'canonical dispatcher is missing'

Write-Host "Pack manifest validation passed. Declared payload files: $($declaredSources.Count)"
