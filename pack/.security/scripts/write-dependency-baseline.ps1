param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$FindingsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $FindingsPath)) { throw "Normalized findings file not found: $FindingsPath" }
$summary = Get-Content $FindingsPath -Raw | ConvertFrom-Json

$baselinePath = Join-Path $RepositoryRoot '.security/dependency-baseline.json'
if (Test-Path $baselinePath) {
    $existing = Get-Content $baselinePath -Raw | ConvertFrom-Json
    if (@($existing.findings).Count -gt 0) {
        throw "Dependency baseline already contains findings. Refusing to replace an established baseline. Use explicit reviewed exceptions for accepted risk instead of re-baselining new vulnerabilities."
    }
}

$dependencyFindings = @($summary.findings | Where-Object {
    $_.category -eq 'dependency' -and -not [string]::IsNullOrWhiteSpace([string]$_.fingerprint)
})

$baselineFindings = @(
    $dependencyFindings |
        Sort-Object fingerprint -Unique |
        ForEach-Object {
            [pscustomobject]@{
                fingerprint = [string]$_.fingerprint
                id = [string]$_.id
                source = [string]$_.source
                ecosystem = [string]$_.ecosystem
                severity = [string]$_.severity
                package = [string]$_.package
                project = [string]$_.project
                framework = [string]$_.framework
                workspace = [string]$_.workspace
                advisoryUrl = [string]$_.advisoryUrl
            }
        }
)

$baseline = [pscustomobject]@{
    schema = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    sourceFindingsSchema = $summary.schema
    findings = $baselineFindings
}

$baseline | ConvertTo-Json -Depth 12 | Set-Content $baselinePath
Write-Host "Dependency baseline initialized with $($baselineFindings.Count) finding(s): $baselinePath"
