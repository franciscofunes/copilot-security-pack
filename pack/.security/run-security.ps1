param(
    [ValidateSet('Changes','Dependencies','Full','Finding','InitializeBaseline')]
    [string]$Mode = 'Changes',
    [string]$FindingId,
    [switch]$ConfirmBaseline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output = Join-Path $repoRoot '.security/output'
$scripts = Join-Path $repoRoot '.security/scripts'
New-Item -ItemType Directory -Force -Path $output | Out-Null

Write-Host "Security Pack: $Mode"
$profile = & (Join-Path $scripts 'discover-repository.ps1') -RepositoryRoot $repoRoot
$profile | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output 'repository-profile.json')

function Invoke-DependencyScans {
    if ($profile.dotnet.present) { & (Join-Path $scripts 'scan-nuget.ps1') -RepositoryRoot $repoRoot -Profile $profile }
    if ($profile.angular.present) { & (Join-Path $scripts 'scan-yarn.ps1') -RepositoryRoot $repoRoot -Profile $profile }
}

switch ($Mode) {
    'Changes' {
        & (Join-Path $scripts 'scan-changes.ps1') -RepositoryRoot $repoRoot -Profile $profile
    }
    'Dependencies' {
        Invoke-DependencyScans
    }
    'Full' {
        if ($profile.dotnet.present) {
            & (Join-Path $scripts 'scan-nuget.ps1') -RepositoryRoot $repoRoot -Profile $profile
            foreach ($solution in $profile.dotnet.solutions) {
                dotnet restore $solution
                dotnet build $solution --no-restore
                dotnet test $solution --no-build
            }
        }
        if ($profile.angular.present) {
            & (Join-Path $scripts 'scan-yarn.ps1') -RepositoryRoot $repoRoot -Profile $profile
        }
    }
    'Finding' {
        if ([string]::IsNullOrWhiteSpace($FindingId)) { throw 'FindingId is required for Finding mode.' }
    }
    'InitializeBaseline' {
        if (-not $ConfirmBaseline) {
            throw 'InitializeBaseline is a first-adoption operation and requires -ConfirmBaseline after reviewing the dependency findings that will become legacy baseline entries.'
        }
        Invoke-DependencyScans
    }
}

& (Join-Path $scripts 'normalize-findings.ps1') -RepositoryRoot $repoRoot -Mode $Mode
$summaryPath = Join-Path $output 'findings-summary.json'

if ($Mode -eq 'Finding') {
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    $finding = @($summary.findings | Where-Object { $_.id -eq $FindingId })
    if ($finding.Count -eq 0) { throw "Finding '$FindingId' was not found." }
    $finding | ConvertTo-Json -Depth 8
}

if ($Mode -eq 'InitializeBaseline') {
    & (Join-Path $scripts 'write-dependency-baseline.ps1') -RepositoryRoot $repoRoot -FindingsPath $summaryPath
    & (Join-Path $scripts 'normalize-findings.ps1') -RepositoryRoot $repoRoot -Mode $Mode
}

& (Join-Path $scripts 'enforce-policy.ps1') -RepositoryRoot $repoRoot -FindingsPath $summaryPath
