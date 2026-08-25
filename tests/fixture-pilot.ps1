Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fixtureRoot = Join-Path $repoRoot 'fixtures/vulnerable-dotnet-angular-monorepo'
$evaluationPath = Join-Path $repoRoot 'evaluations/vulnerable-dotnet-angular-monorepo.json'
$preparePilot = Join-Path $repoRoot 'evaluations/prepare-pilot.ps1'
$apiPath = Join-Path $fixtureRoot 'api/Program.cs'
$guardPath = Join-Path $fixtureRoot 'web/src/app/admin.guard.ts'
$servicePath = Join-Path $fixtureRoot 'web/src/app/api.service.ts'

Assert-True (Test-Path $evaluationPath) 'external evaluation rubric is missing'
Assert-True (Test-Path $preparePilot) 'pilot preparation script is missing'
Assert-True (-not (Test-Path (Join-Path $fixtureRoot 'evaluation.json'))) 'answer key must not live inside the pilot workspace'
$evaluation = Get-Content $evaluationPath -Raw | ConvertFrom-Json
Assert-True (@($evaluation.cases).Count -eq 4) 'fixture must contain exactly four expected security canaries'

$api = Get-Content $apiPath -Raw
$guard = Get-Content $guardPath -Raw
$service = Get-Content $servicePath -Raw

foreach ($id in @('SEC-001','SEC-002','SEC-003','SEC-004')) {
    Assert-True ($api -match $id -or $guard -match $id -or $service -match $id) "fixture marker missing for $id"
}
Assert-True ($api -match 'tenantId' -and $api -match 'RequireAuthorization') 'SEC-001 tenant/auth canary drifted'
Assert-True ($guard -match 'localStorage' -and $api -match '/api/admin/users') 'SEC-002 frontend-only admin canary drifted'
Assert-True ($api -match 'IsAdmin\s*=\s*request\.IsAdmin') 'SEC-003 mass-assignment canary drifted'
Assert-True ($api -match 'GetStringAsync\(url\)') 'SEC-004 SSRF canary drifted'

& dotnet build (Join-Path $fixtureRoot 'api/Fixture.Api.csproj') --nologo --configuration Release
if ($LASTEXITCODE -ne 0) { throw 'fixture .NET API failed to compile' }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-pack-fixture-' + [guid]::NewGuid().ToString('N'))
try {
    & $preparePilot -Destination $tempRoot

    Assert-True (Test-Path (Join-Path $tempRoot '.github/agents/security-reviewer.agent.md')) 'Security Reviewer agent not installed into fixture'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/skills/security-dotnet/SKILL.md')) '.NET skill not installed into fixture'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/skills/security-angular/SKILL.md')) 'Angular skill not installed into fixture'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/skills/security-cross-stack/SKILL.md')) 'cross-stack skill not installed into fixture'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/prompts/security-review-flow.prompt.md')) 'cross-stack review prompt not installed into fixture'

    $installedManifest = Get-Content (Join-Path $tempRoot '.security/copilot-pack.yml') -Raw
    Assert-True ($installedManifest -match 'dotnet:\s*true') 'fixture install did not detect .NET'
    Assert-True ($installedManifest -match 'angular:\s*true') 'fixture install did not detect Angular/Yarn'
    Assert-True ($installedManifest -match 'crossStackSecurity:\s*true') 'fixture install did not detect cross-stack repository'

    # Only the actual external evaluation artifacts are forbidden in the blind workspace.
    # Legitimate installed skill references may contain words such as "rubric".
    $leaks = @(Get-ChildItem -Path $tempRoot -Recurse -File | Where-Object {
        $_.Name -in @('evaluation.json', 'vulnerable-dotnet-angular-monorepo.json', 'RUN_TEMPLATE.md') -or
        $_.FullName -match '[\\/]evaluations[\\/]'
    })
    Assert-True ($leaks.Count -eq 0) 'prepared pilot workspace leaked evaluation material'

    $changed = @(git -C $tempRoot diff --name-only)
    Assert-True ($changed -contains 'api/Program.cs') 'pilot setup did not expose API source as a current change'
    Assert-True ($changed -contains 'web/src/app/api.service.ts') 'pilot setup did not expose Angular service as a current change'

    Write-Host 'Fixture pilot validation passed.'
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force (Join-Path $fixtureRoot 'api/bin') -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force (Join-Path $fixtureRoot 'api/obj') -ErrorAction SilentlyContinue
}
