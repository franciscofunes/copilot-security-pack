param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Profile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitLines {
    param([string[]]$Arguments)
    try {
        $lines = @(& git -C $RepositoryRoot @Arguments 2>$null)
        if ($LASTEXITCODE -eq 0) { return @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
    } catch {}
    return @()
}

$changed = @()

if ($env:GITHUB_ACTIONS -eq 'true' -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_BASE_REF)) {
    $baseRef = "origin/$($env:GITHUB_BASE_REF)"
    $mergeBase = @(Get-GitLines -Arguments @('merge-base', $baseRef, 'HEAD')) | Select-Object -First 1
    if ($mergeBase) {
        $changed = @(Get-GitLines -Arguments @('diff', '--name-only', "$mergeBase...HEAD"))
    }
}

if ($changed.Count -eq 0 -and $env:GITHUB_ACTIONS -ne 'true') {
    $workingChanges = @()
    $workingChanges += Get-GitLines -Arguments @('diff', '--name-only', '--cached')
    $workingChanges += Get-GitLines -Arguments @('diff', '--name-only')
    $workingChanges += Get-GitLines -Arguments @('ls-files', '--others', '--exclude-standard')
    $changed = @($workingChanges | Sort-Object -Unique)
}

if ($changed.Count -eq 0) {
    $hasParent = @(Get-GitLines -Arguments @('rev-parse', '--verify', 'HEAD^'))
    if ($hasParent.Count -gt 0) {
        $changed = @(Get-GitLines -Arguments @('diff', '--name-only', 'HEAD^', 'HEAD'))
    }
}

if ($changed.Count -eq 0) {
    $changed = @(Get-GitLines -Arguments @('show', '--pretty=', '--name-only', 'HEAD'))
}

$changed = @($changed | Sort-Object -Unique)
$changed | Set-Content (Join-Path $RepositoryRoot '.security/output/changed-files.txt')

$dotnetChanged = @($changed | Where-Object { $_ -match '\.(cs|csproj|props|targets|json)$' }).Count -gt 0
$depsChanged = @($changed | Where-Object { $_ -match '(\.csproj$|Directory\.Packages\.props$|packages\.lock\.json$|package\.json$|yarn\.lock$|\.yarnrc(\.yml)?$)' }).Count -gt 0
$angularChanged = @($changed | Where-Object { $_ -match '\.(ts|html|scss|css)$' }).Count -gt 0

if ($Profile.dotnet.present -and ($dotnetChanged -or $depsChanged)) {
    & (Join-Path $PSScriptRoot 'scan-nuget.ps1') -RepositoryRoot $RepositoryRoot -Profile $Profile
}
if ($Profile.angular.present -and ($angularChanged -or $depsChanged)) {
    & (Join-Path $PSScriptRoot 'scan-yarn.ps1') -RepositoryRoot $RepositoryRoot -Profile $Profile
}
