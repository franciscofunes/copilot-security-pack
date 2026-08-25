param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Profile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$output = Join-Path $RepositoryRoot '.security/output/yarn-vulnerabilities.jsonl'
Remove-Item $output -Force -ErrorAction SilentlyContinue
foreach ($lock in $Profile.angular.yarnLocks) {
    $dir = Split-Path $lock -Parent
    Push-Location $dir
    try {
        $version = if ($Profile.angular.yarnVersion) { [version]$Profile.angular.yarnVersion } else { $null }
        if ($version -and $version.Major -ge 2) {
            & yarn install --immutable
            & yarn npm audit --all --recursive --json 2>&1 | Add-Content $output
        } else {
            & yarn install --frozen-lockfile
            & yarn audit --json 2>&1 | Add-Content $output
        }
    } finally { Pop-Location }
}
