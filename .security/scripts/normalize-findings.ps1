param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$Mode)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$output = Join-Path $RepositoryRoot '.security/output'
$findings = @()

$nugetPath = Join-Path $output 'nuget-vulnerabilities.json'
if (Test-Path $nugetPath) {
    $entries = Get-Content $nugetPath -Raw | ConvertFrom-Json
    foreach ($entry in @($entries)) {
        $findings += [pscustomobject]@{
            id = "NUGET-$([Math]::Abs($entry.solution.GetHashCode()))"
            source = 'nuget-audit'
            status = 'needs-review'
            severity = 'unknown'
            category = 'dependency'
            project = $entry.solution
            evidence = 'NuGet vulnerability output is available in nuget-vulnerabilities.json.'
        }
    }
}

$yarnPath = Join-Path $output 'yarn-vulnerabilities.jsonl'
if (Test-Path $yarnPath) {
    $yarnFile = Get-Item $yarnPath
    if ($yarnFile.Length -gt 0) {
        $findings += [pscustomobject]@{
            id = 'YARN-AUDIT'
            source = 'yarn-audit'
            status = 'needs-review'
            severity = 'unknown'
            category = 'dependency'
            evidence = 'Yarn audit output is available in yarn-vulnerabilities.jsonl.'
        }
    }
}

$summary = [pscustomobject]@{
    schema = 1
    mode = $Mode
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    findings = $findings
    summary = [pscustomobject]@{
        total = @($findings).Count
        critical = @($findings | Where-Object severity -eq 'critical').Count
        high = @($findings | Where-Object severity -eq 'high').Count
        moderate = @($findings | Where-Object severity -eq 'moderate').Count
        low = @($findings | Where-Object severity -eq 'low').Count
        unknown = @($findings | Where-Object severity -eq 'unknown').Count
    }
}
$summary | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $output 'findings-summary.json')
