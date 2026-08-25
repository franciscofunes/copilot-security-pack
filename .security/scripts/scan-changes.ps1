param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Profile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$changed = @()
try { $changed = @(git -C $RepositoryRoot diff --name-only HEAD~1 HEAD) } catch {}
if ($changed.Count -eq 0) {
    try { $changed = @(git -C $RepositoryRoot diff --name-only --cached) } catch {}
}
if ($changed.Count -eq 0) {
    try { $changed = @(git -C $RepositoryRoot diff --name-only) } catch {}
}

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
