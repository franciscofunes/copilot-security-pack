param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [string]$GitHubCommand = 'gh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonical = Join-Path $PSScriptRoot '../../pack/.security/scripts/collect-dependabot-org-context.ps1'
if (-not (Test-Path $canonical)) { throw "Canonical Dependabot organization collector not found: $canonical" }
& $canonical -RepositoryRoot $RepositoryRoot -GitHubCommand $GitHubCommand
