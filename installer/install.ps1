param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[copilot-security-pack] $Message"
}

function Ensure-ParentDirectory([string]$Path) {
    $parent = Split-Path $Path -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function Copy-ManagedFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$Installed,
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$Updated,
        [switch]$WhatIf
    )

    if (-not (Test-Path $Source)) {
        throw "Pack source file not found: $Source"
    }

    $exists = Test-Path $Destination
    $sourceHash = (Get-FileHash -Algorithm SHA256 -Path $Source).Hash
    $same = $false
    if ($exists) {
        $destinationHash = (Get-FileHash -Algorithm SHA256 -Path $Destination).Hash
        $same = ($sourceHash -eq $destinationHash)
    }

    if ($same) { return }

    if (-not $WhatIf) {
        Ensure-ParentDirectory $Destination
        Copy-Item -Force -Path $Source -Destination $Destination
    }

    if ($exists) { $Updated.Add($Destination) | Out-Null }
    else { $Installed.Add($Destination) | Out-Null }
}

$targetRoot = (Resolve-Path $TargetRepo).Path
$packRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $PSScriptRoot 'pack-manifest.json'
$versionPath = Join-Path $packRoot 'VERSION'

if (-not (Test-Path (Join-Path $targetRoot '.git'))) {
    throw "TargetRepo must be the root of a Git repository: $targetRoot"
}
if (-not (Test-Path $manifestPath)) { throw "Installer manifest not found: $manifestPath" }
if (-not (Test-Path $versionPath)) { throw "VERSION file not found: $versionPath" }

$version = (Get-Content $versionPath -Raw).Trim()
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$dotnetProjects = @(Get-ChildItem -Path $targetRoot -Recurse -File -Filter *.csproj -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|\.git)[\\/]' })
$angularFiles = @(Get-ChildItem -Path $targetRoot -Recurse -File -Filter angular.json -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git)[\\/]' })
$yarnLocks = @(Get-ChildItem -Path $targetRoot -Recurse -File -Filter yarn.lock -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git)[\\/]' })

$features = @{
    core = $true
    dotnet = ($dotnetProjects.Count -gt 0)
    angular = (($angularFiles.Count -gt 0) -or ($yarnLocks.Count -gt 0))
    crossStack = (($dotnetProjects.Count -gt 0) -and (($angularFiles.Count -gt 0) -or ($yarnLocks.Count -gt 0)))
}

Write-Step "Target: $targetRoot"
Write-Step "Pack version: $version"
Write-Step "Detected .NET: $($features.dotnet)"
Write-Step "Detected Angular/Yarn: $($features.angular)"
Write-Step "Detected cross-stack monorepo: $($features.crossStack)"

$installed = [System.Collections.Generic.List[string]]::new()
$updated = [System.Collections.Generic.List[string]]::new()
$preserved = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

foreach ($item in @($manifest.managed)) {
    $feature = [string]$item.feature
    if (-not $features[$feature]) {
        $skipped.Add([string]$item.target) | Out-Null
        continue
    }

    $source = Join-Path $packRoot ([string]$item.source)
    $destination = Join-Path $targetRoot ([string]$item.target)
    Copy-ManagedFile -Source $source -Destination $destination -Installed $installed -Updated $updated -WhatIf:$WhatIf
}

foreach ($item in @($manifest.createIfMissing)) {
    $source = Join-Path $packRoot ([string]$item.source)
    $destination = Join-Path $targetRoot ([string]$item.target)

    if (Test-Path $destination) {
        $preserved.Add([string]$item.target) | Out-Null
        continue
    }

    Copy-ManagedFile -Source $source -Destination $destination -Installed $installed -Updated $updated -WhatIf:$WhatIf
}

# Repository-wide instructions are repository-owned. Never overwrite an existing file.
$sourceGlobalInstructions = Join-Path $packRoot '.github/copilot-instructions.md'
$targetGlobalInstructions = Join-Path $targetRoot '.github/copilot-instructions.md'
if (-not (Test-Path $targetGlobalInstructions)) {
    Copy-ManagedFile -Source $sourceGlobalInstructions -Destination $targetGlobalInstructions -Installed $installed -Updated $updated -WhatIf:$WhatIf
} else {
    $fallbackInstruction = Join-Path $targetRoot '.github/instructions/security-pack-global.instructions.md'
    $globalBody = Get-Content $sourceGlobalInstructions -Raw
    $fallbackContent = "---`napplyTo: '**'`n---`n`n$globalBody"
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-security-pack-global-" + [guid]::NewGuid().ToString('N') + '.md')
    try {
        Set-Content -Path $temp -Value $fallbackContent -NoNewline
        Copy-ManagedFile -Source $temp -Destination $fallbackInstruction -Installed $installed -Updated $updated -WhatIf:$WhatIf
        $preserved.Add('.github/copilot-instructions.md') | Out-Null
    } finally {
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
    }
}

# Generated installation metadata is pack-managed but contains target-specific detection results.
$targetManifest = Join-Path $targetRoot '.security/copilot-pack.yml'
$manifestText = @"
schema: 1
packVersion: $version
source: copilot-security-pack
host: vscode-copilot-extension
installedFeatures:
  dotnet: $($features.dotnet.ToString().ToLowerInvariant())
  angular: $($features.angular.ToString().ToLowerInvariant())
  yarn: $(($yarnLocks.Count -gt 0).ToString().ToLowerInvariant())
  crossStackSecurity: $($features.crossStack.ToString().ToLowerInvariant())
  mcp: false
"@
if (-not $WhatIf) {
    Ensure-ParentDirectory $targetManifest
    Set-Content -Path $targetManifest -Value $manifestText -NoNewline
}
if (Test-Path $targetManifest) { $updated.Add('.security/copilot-pack.yml') | Out-Null }
else { $installed.Add('.security/copilot-pack.yml') | Out-Null }

Write-Host ''
Write-Step 'Installation summary'
Write-Host "  Installed: $($installed.Count)"
foreach ($item in $installed) { Write-Host "    + $item" }
Write-Host "  Updated: $($updated.Count)"
foreach ($item in $updated) { Write-Host "    ~ $item" }
Write-Host "  Preserved: $($preserved.Count)"
foreach ($item in $preserved) { Write-Host "    = $item" }
Write-Host "  Skipped (not applicable): $($skipped.Count)"
foreach ($item in $skipped) { Write-Host "    - $item" }

if ($WhatIf) {
    Write-Step 'WhatIf mode: no target files were modified.'
} else {
    Write-Step "Installed Copilot Security Pack $version. Review the target repository Git diff before committing."
}
