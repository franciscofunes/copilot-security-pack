Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$writer = Join-Path $repoRoot 'pack/.security/scripts/write-dependency-baseline.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-pack-baseline-' + [guid]::NewGuid().ToString('N'))
$output = Join-Path $tempRoot '.security/output'

try {
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    @{ schema=1; generatedAt=$null; findings=@() } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $tempRoot '.security/dependency-baseline.json')

    $summary = [pscustomobject]@{
        schema = 2
        findings = @(
            [pscustomobject]@{
                id='GHSA-AAAA-BBBB-CCCC'; fingerprint='fp-one'; source='nuget'; ecosystem='nuget'; category='dependency'; status='new'; severity='high'; package='Example.Package'; project='src/Api/Api.csproj'; framework='net10.0'; workspace=$null; advisoryUrl='https://github.com/advisories/GHSA-AAAA-BBBB-CCCC'
            },
            [pscustomobject]@{
                id='GHSA-DDDD-EEEE-FFFF'; fingerprint='fp-two'; source='yarn'; ecosystem='npm'; category='dependency'; status='new'; severity='moderate'; package='example-js'; project=$null; framework=$null; workspace='src/Web'; advisoryUrl='https://github.com/advisories/GHSA-DDDD-EEEE-FFFF'
            }
        )
    }
    $findingsPath = Join-Path $output 'findings-summary.json'
    $summary | ConvertTo-Json -Depth 12 | Set-Content $findingsPath

    & $writer -RepositoryRoot $tempRoot -FindingsPath $findingsPath
    $baselinePath = Join-Path $tempRoot '.security/dependency-baseline.json'
    $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
    Assert-True (@($baseline.findings).Count -eq 2) 'initial baseline did not contain both dependency findings'
    Assert-True (@($baseline.findings | Where-Object fingerprint -eq 'fp-one').Count -eq 1) 'NuGet fingerprint missing from baseline'
    Assert-True (@($baseline.findings | Where-Object fingerprint -eq 'fp-two').Count -eq 1) 'Yarn fingerprint missing from baseline'

    $replaceRefused = $false
    try { & $writer -RepositoryRoot $tempRoot -FindingsPath $findingsPath } catch { $replaceRefused = $true }
    Assert-True $replaceRefused 'writer did not refuse replacing a non-empty baseline'

    @{ schema=1; generatedAt=$null; findings=@() } | ConvertTo-Json -Depth 5 | Set-Content $baselinePath
    $summaryWithScannerError = [pscustomobject]@{
        schema = 2
        findings = @(
            $summary.findings[0],
            [pscustomobject]@{ id='SCANNER-YARN-ERROR'; fingerprint='err'; source='yarn'; ecosystem='yarn'; category='scanner-error'; status='needs-review'; severity='unknown'; title='audit failed' }
        )
    }
    $summaryWithScannerError | ConvertTo-Json -Depth 12 | Set-Content $findingsPath
    $partialRefused = $false
    try { & $writer -RepositoryRoot $tempRoot -FindingsPath $findingsPath } catch { $partialRefused = $true }
    Assert-True $partialRefused 'writer allowed baseline initialization with scanner errors'
    $afterError = Get-Content $baselinePath -Raw | ConvertFrom-Json
    Assert-True (@($afterError.findings).Count -eq 0) 'baseline changed after scanner-error refusal'

    Write-Host 'Baseline initialization tests passed.'
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
