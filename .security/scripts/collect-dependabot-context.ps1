param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [string]$GitHubCommand = 'gh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonical = Join-Path $PSScriptRoot '../../pack/.security/scripts/collect-dependabot-context.ps1'
if (-not (Test-Path $canonical)) { throw "Canonical Dependabot collector not found: $canonical" }
& $canonical -RepositoryRoot $RepositoryRoot -GitHubCommand $GitHubCommand
