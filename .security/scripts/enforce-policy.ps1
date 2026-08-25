param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$FindingsPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $FindingsPath)) { throw "Findings file not found: $FindingsPath" }
$summary = Get-Content $FindingsPath -Raw | ConvertFrom-Json
$blocking = @($summary.findings | Where-Object { $_.status -eq 'new' -and $_.severity -in @('critical','high') })
if ($blocking.Count -gt 0) {
    Write-Error "Security policy failed: $($blocking.Count) new high/critical finding(s)."
    exit 2
}
Write-Host "Security policy passed. Findings: $(@($summary.findings).Count)"
