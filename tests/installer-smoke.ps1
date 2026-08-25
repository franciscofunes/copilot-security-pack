Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$installer = Join-Path $repoRoot 'installer/install.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-pack-test-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    git -C $tempRoot init --quiet

    Set-Content (Join-Path $tempRoot 'Api.csproj') '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>'
    Set-Content (Join-Path $tempRoot 'angular.json') '{"version":1,"projects":{}}'
    Set-Content (Join-Path $tempRoot 'yarn.lock') '# fixture'

    $github = Join-Path $tempRoot '.github'
    New-Item -ItemType Directory -Force -Path $github | Out-Null
    $existingInstructions = Join-Path $github 'copilot-instructions.md'
    $sentinel = '# Existing application instructions'
    Set-Content -Path $existingInstructions -Value $sentinel -NoNewline

    & $installer -TargetRepo $tempRoot

    Assert-True (Test-Path (Join-Path $tempRoot '.github/agents/security-reviewer.agent.md')) 'security reviewer agent was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/skills/security-dotnet/SKILL.md')) '.NET skill was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/skills/security-angular/SKILL.md')) 'Angular skill was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/skills/security-cross-stack/SKILL.md')) 'cross-stack skill was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/instructions/security-pack-global.instructions.md')) 'fallback global instructions were not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.security/run-security.ps1')) 'security dispatcher was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.security/security-policy.yml')) 'default security policy was not installed'

    $afterInstructions = Get-Content $existingInstructions -Raw
    Assert-True ($afterInstructions -eq $sentinel) 'existing copilot-instructions.md was modified'

    $packManifest = Get-Content (Join-Path $tempRoot '.security/copilot-pack.yml') -Raw
    Assert-True ($packManifest -match 'dotnet:\s*true') 'target manifest did not record .NET detection'
    Assert-True ($packManifest -match 'angular:\s*true') 'target manifest did not record Angular detection'
    Assert-True ($packManifest -match 'yarn:\s*true') 'target manifest did not record Yarn detection'
    Assert-True ($packManifest -match 'crossStackSecurity:\s*true') 'target manifest did not record cross-stack detection'

    $agentPath = Join-Path $tempRoot '.github/agents/security-reviewer.agent.md'
    $beforeHash = (Get-FileHash -Algorithm SHA256 $agentPath).Hash

    & $installer -TargetRepo $tempRoot

    $afterHash = (Get-FileHash -Algorithm SHA256 $agentPath).Hash
    Assert-True ($beforeHash -eq $afterHash) 'idempotent reinstall changed an unchanged managed file'
    Assert-True ((Get-Content $existingInstructions -Raw) -eq $sentinel) 'idempotent reinstall modified existing application instructions'

    Write-Host 'Installer smoke test passed.'
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
