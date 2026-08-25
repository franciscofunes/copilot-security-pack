Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$installer = Join-Path $repoRoot 'installer/install.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-pack-selection-' + [guid]::NewGuid().ToString('N'))

try {
    # .NET-only repository
    $dotnetRepo = Join-Path $root 'dotnet-only'
    New-Item -ItemType Directory -Force -Path $dotnetRepo | Out-Null
    git -C $dotnetRepo init --quiet
    Set-Content (Join-Path $dotnetRepo 'Api.csproj') '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>'

    & $installer -TargetRepo $dotnetRepo

    Assert-True (Test-Path (Join-Path $dotnetRepo '.github/skills/security-dotnet/SKILL.md')) '.NET-only repo did not receive .NET skill'
    Assert-True (-not (Test-Path (Join-Path $dotnetRepo '.github/skills/security-angular/SKILL.md'))) '.NET-only repo incorrectly received Angular skill'
    Assert-True (-not (Test-Path (Join-Path $dotnetRepo '.github/skills/security-cross-stack/SKILL.md'))) '.NET-only repo incorrectly received cross-stack skill'
    Assert-True (-not (Test-Path (Join-Path $dotnetRepo '.security/scripts/scan-yarn.ps1'))) '.NET-only repo incorrectly received Yarn scanner'
    $dotnetManifest = Get-Content (Join-Path $dotnetRepo '.security/copilot-pack.yml') -Raw
    Assert-True ($dotnetManifest -match 'dotnet:\s*true') '.NET-only manifest did not record dotnet=true'
    Assert-True ($dotnetManifest -match 'angular:\s*false') '.NET-only manifest did not record angular=false'
    Assert-True ($dotnetManifest -match 'crossStackSecurity:\s*false') '.NET-only manifest did not record crossStackSecurity=false'

    # Angular/Yarn-only repository
    $angularRepo = Join-Path $root 'angular-only'
    New-Item -ItemType Directory -Force -Path $angularRepo | Out-Null
    git -C $angularRepo init --quiet
    Set-Content (Join-Path $angularRepo 'angular.json') '{"version":1,"projects":{}}'
    Set-Content (Join-Path $angularRepo 'yarn.lock') '# fixture'

    & $installer -TargetRepo $angularRepo

    Assert-True (Test-Path (Join-Path $angularRepo '.github/skills/security-angular/SKILL.md')) 'Angular-only repo did not receive Angular skill'
    Assert-True (-not (Test-Path (Join-Path $angularRepo '.github/skills/security-dotnet/SKILL.md'))) 'Angular-only repo incorrectly received .NET skill'
    Assert-True (-not (Test-Path (Join-Path $angularRepo '.github/skills/security-cross-stack/SKILL.md'))) 'Angular-only repo incorrectly received cross-stack skill'
    Assert-True (-not (Test-Path (Join-Path $angularRepo '.security/scripts/scan-nuget.ps1'))) 'Angular-only repo incorrectly received NuGet scanner'
    $angularManifest = Get-Content (Join-Path $angularRepo '.security/copilot-pack.yml') -Raw
    Assert-True ($angularManifest -match 'dotnet:\s*false') 'Angular-only manifest did not record dotnet=false'
    Assert-True ($angularManifest -match 'angular:\s*true') 'Angular-only manifest did not record angular=true'
    Assert-True ($angularManifest -match 'crossStackSecurity:\s*false') 'Angular-only manifest did not record crossStackSecurity=false'

    Write-Host 'Installer selection tests passed.'
}
finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}
