param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,
    [switch]$WhatIf,
    [switch]$ForceManagedOverwrite
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

function Get-Sha256([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Get-RelativePath([string]$Root, [string]$Path) {
    return [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\\','/')
}

$targetRoot = (Resolve-Path $TargetRepo).Path
$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$packRootPath = Join-Path $sourceRepoRoot 'pack'
if (-not (Test-Path $packRootPath)) { throw "Canonical pack payload not found: $packRootPath" }
$packRoot = (Resolve-Path $packRootPath).Path
$manifestPath = Join-Path $PSScriptRoot 'pack-manifest.json'
$versionPath = Join-Path $sourceRepoRoot 'VERSION'
$statePath = Join-Path $targetRoot '.security/copilot-pack-state.json'

if (-not (Test-Path (Join-Path $targetRoot '.git'))) {
    throw "TargetRepo must be the root of a Git repository: $targetRoot"
}
if (-not (Test-Path $manifestPath)) { throw "Installer manifest not found: $manifestPath" }
if (-not (Test-Path $versionPath)) { throw "VERSION file not found: $versionPath" }

$version = (Get-Content $versionPath -Raw).Trim()
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$previousState = $null
$previousHashes = @{}
if (Test-Path $statePath) {
    $previousState = Get-Content $statePath -Raw | ConvertFrom-Json
    foreach ($entry in @($previousState.managedFiles)) {
        $previousHashes[[string]$entry.path] = [string]$entry.sha256
    }
}

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
Write-Step "Payload: $packRoot"
Write-Step "Detected .NET: $($features.dotnet)"
Write-Step "Detected Angular/Yarn: $($features.angular)"
Write-Step "Detected cross-stack monorepo: $($features.crossStack)"

$installed = [System.Collections.Generic.List[string]]::new()
$updated = [System.Collections.Generic.List[string]]::new()
$preserved = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$conflicts = [System.Collections.Generic.List[string]]::new()
$managedState = [System.Collections.Generic.List[object]]::new()

function Install-ManagedContent {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Feature,
        [string]$LogicalSource,
        [switch]$WhatIf,
        [switch]$ForceManagedOverwrite
    )

    if (-not (Test-Path $Source)) { throw "Pack source file not found: $Source" }

    $relative = Get-RelativePath $targetRoot $Destination
    $sourceHash = Get-Sha256 $Source
    $exists = Test-Path $Destination
    $destinationHash = if ($exists) { Get-Sha256 $Destination } else { $null }
    $previousHash = if ($previousHashes.ContainsKey($relative)) { $previousHashes[$relative] } else { $null }

    if ($exists -and $destinationHash -eq $sourceHash) {
        $managedState.Add([pscustomobject]@{ path=$relative; sha256=$sourceHash; feature=$Feature; source=$LogicalSource }) | Out-Null
        return
    }

    if ($exists) {
        $knownManaged = -not [string]::IsNullOrWhiteSpace($previousHash)
        $locallyModified = $knownManaged -and ($destinationHash -ne $previousHash)
        $preExistingUnknown = -not $knownManaged

        if (($locallyModified -or $preExistingUnknown) -and -not $ForceManagedOverwrite) {
            $conflicts.Add($relative) | Out-Null
            return
        }
    }

    if (-not $WhatIf) {
        Ensure-ParentDirectory $Destination
        Copy-Item -Force -Path $Source -Destination $Destination
    }

    if ($exists) { $updated.Add($relative) | Out-Null }
    else { $installed.Add($relative) | Out-Null }

    $managedState.Add([pscustomobject]@{ path=$relative; sha256=$sourceHash; feature=$Feature; source=$LogicalSource }) | Out-Null
}

foreach ($item in @($manifest.managed)) {
    $feature = [string]$item.feature
    if (-not $features[$feature]) {
        $skipped.Add([string]$item.target) | Out-Null
        continue
    }

    $source = Join-Path $packRoot ([string]$item.source)
    $destination = Join-Path $targetRoot ([string]$item.target)
    Install-ManagedContent -Source $source -Destination $destination -Feature $feature -LogicalSource ([string]$item.source) -WhatIf:$WhatIf -ForceManagedOverwrite:$ForceManagedOverwrite
}

foreach ($item in @($manifest.createIfMissing)) {
    $source = Join-Path $packRoot ([string]$item.source)
    $destination = Join-Path $targetRoot ([string]$item.target)
    $relative = [string]$item.target

    if (-not (Test-Path $source)) { throw "Pack source file not found: $source" }
    if (Test-Path $destination) {
        $preserved.Add($relative) | Out-Null
        continue
    }

    if (-not $WhatIf) {
        Ensure-ParentDirectory $destination
        Copy-Item -Path $source -Destination $destination
    }
    $installed.Add($relative) | Out-Null
}

$sourceGlobalInstructions = Join-Path $packRoot '.github/copilot-instructions.md'
$targetGlobalInstructions = Join-Path $targetRoot '.github/copilot-instructions.md'
if (-not (Test-Path $targetGlobalInstructions)) {
    Install-ManagedContent -Source $sourceGlobalInstructions -Destination $targetGlobalInstructions -Feature 'core' -LogicalSource '.github/copilot-instructions.md' -WhatIf:$WhatIf -ForceManagedOverwrite:$ForceManagedOverwrite
} else {
    $globalRelative = '.github/copilot-instructions.md'
    $globalPreviousHash = if ($previousHashes.ContainsKey($globalRelative)) { $previousHashes[$globalRelative] } else { $null }
    if ($globalPreviousHash) {
        Install-ManagedContent -Source $sourceGlobalInstructions -Destination $targetGlobalInstructions -Feature 'core' -LogicalSource '.github/copilot-instructions.md' -WhatIf:$WhatIf -ForceManagedOverwrite:$ForceManagedOverwrite
    } else {
        $fallbackInstruction = Join-Path $targetRoot '.github/instructions/security-pack-global.instructions.md'
        $globalBody = Get-Content $sourceGlobalInstructions -Raw
        $fallbackContent = "---`napplyTo: '**'`n---`n`n$globalBody"
        $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-security-pack-global-" + [guid]::NewGuid().ToString('N') + '.md')
        try {
            Set-Content -Path $temp -Value $fallbackContent -NoNewline
            Install-ManagedContent -Source $temp -Destination $fallbackInstruction -Feature 'core' -LogicalSource '.github/copilot-instructions.md#fallback' -WhatIf:$WhatIf -ForceManagedOverwrite:$ForceManagedOverwrite
            $preserved.Add($globalRelative) | Out-Null
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($conflicts.Count -gt 0) {
    Write-Host ''
    Write-Step 'Managed-file conflicts detected; no state/version metadata will be advanced.'
    foreach ($item in $conflicts) { Write-Host "    ! $item" }
    throw "Refusing to overwrite $($conflicts.Count) existing or locally modified managed file(s). Review them or re-run with -ForceManagedOverwrite after explicit approval."
}

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

    $state = [pscustomobject]@{
        schema = 1
        packVersion = $version
        installedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        host = 'vscode-copilot-extension'
        payloadRoot = 'pack'
        managedFiles = @($managedState | Sort-Object path)
    }
    $state | ConvertTo-Json -Depth 8 | Set-Content -Path $statePath
}

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
    Write-Step "Installed Copilot Security Pack $version from canonical pack/ payload. Managed-file checksums recorded in .security/copilot-pack-state.json. Review the target repository Git diff before committing."
}
