param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Profile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$output = Join-Path $RepositoryRoot '.security/output/nuget-vulnerabilities.json'
$all = @()
foreach ($solution in $Profile.dotnet.solutions) {
    $major = [int]((& dotnet --version).Split('.')[0])
    if ($major -ge 10) {
        $raw = & dotnet package list $solution --vulnerable --include-transitive --format json 2>&1
    } else {
        $raw = & dotnet list $solution package --vulnerable --include-transitive --format json 2>&1
    }
    $all += [pscustomobject]@{ solution = $solution; output = ($raw -join "`n") }
}
$all | ConvertTo-Json -Depth 10 | Set-Content $output
