Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$collector = Join-Path $repoRoot 'pack/.security/scripts/collect-build-context.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-build-context-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    git -C $tempRoot init --quiet
    git -C $tempRoot config user.name 'Build Intelligence Test'
    git -C $tempRoot config user.email 'build-intelligence@localhost'
    Set-Content (Join-Path $tempRoot 'README.md') '# fixture'
    git -C $tempRoot add .
    git -C $tempRoot commit --quiet -m baseline
    git -C $tempRoot branch -M 'feature/build-intelligence'
    Add-Content (Join-Path $tempRoot 'README.md') 'working tree change'

    & $collector -RepositoryRoot $tempRoot -GitHubCommand '__missing_gh__' -AzureCommand '__missing_az__' -JFrogCommand '__missing_jf__' | Out-Null

    $path = Join-Path $tempRoot '.security/output/build-context.json'
    Assert-True (Test-Path $path) 'collector did not create build-context.json'
    $context = Get-Content $path -Raw | ConvertFrom-Json
    Assert-True ($context.schema -eq 1) 'unexpected build-context schema'
    Assert-True ($context.git.branch -eq 'feature/build-intelligence') 'branch correlation failed'
    Assert-True (-not [string]::IsNullOrWhiteSpace($context.git.headSha)) 'HEAD SHA was not captured'
    Assert-True (@($context.git.changedFiles).Count -gt 0) 'working-tree changes were not captured'
    Assert-True ($context.providers.github.status -eq 'unavailable') 'missing GitHub CLI should be unavailable'
    Assert-True ($context.providers.azure.status -eq 'unavailable') 'missing Azure CLI should be unavailable'
    Assert-True ($context.providers.jfrog.status -eq 'unavailable') 'missing JFrog CLI should be unavailable'

    Write-Host 'Build intelligence fallback tests passed.'
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
