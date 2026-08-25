param(
    [Parameter(Mandatory)][string]$Destination,
    [switch]$OpenInVSCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fixtureRoot = Join-Path $repoRoot 'fixtures/vulnerable-dotnet-angular-monorepo'
$installer = Join-Path $repoRoot 'installer/install.ps1'

if (-not (Test-Path $fixtureRoot)) { throw "Fixture not found: $fixtureRoot" }
if (-not (Test-Path $installer)) { throw "Installer not found: $installer" }

$destinationFull = [System.IO.Path]::GetFullPath($Destination)
if (Test-Path $destinationFull) {
    $existing = @(Get-ChildItem -Force -Path $destinationFull -ErrorAction Stop)
    if ($existing.Count -gt 0) {
        throw "Destination must not already contain files: $destinationFull"
    }
} else {
    New-Item -ItemType Directory -Force -Path $destinationFull | Out-Null
}

Copy-Item -Path (Join-Path $fixtureRoot '*') -Destination $destinationFull -Recurse -Force

git -C $destinationFull init --quiet
if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
git -C $destinationFull config user.name 'Copilot Security Pilot'
git -C $destinationFull config user.email 'copilot-security-pilot@localhost'
git -C $destinationFull add .
git -C $destinationFull commit --quiet -m 'fixture baseline'
if ($LASTEXITCODE -ne 0) { throw 'fixture baseline commit failed' }

& $installer -TargetRepo $destinationFull

# The pilot evaluates changed-file behavior. Keep the vulnerable source in HEAD,
# then make the two cross-stack source files the active working-tree change.
$apiPath = Join-Path $destinationFull 'api/Program.cs'
$servicePath = Join-Path $destinationFull 'web/src/app/api.service.ts'
Add-Content -Path $apiPath -Value "`n// pilot-review-change"
Add-Content -Path $servicePath -Value "`n// pilot-review-change"

# Block only the actual evaluation answer-key artifacts. Security skills may
# legitimately contain words such as "rubric" in their own reference files.
$forbiddenFiles = @(
    'evaluation.json',
    'vulnerable-dotnet-angular-monorepo.json',
    'RUN_TEMPLATE.md'
)
$answerKeyLeak = @(Get-ChildItem -Path $destinationFull -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $forbiddenFiles -contains $_.Name -or $_.FullName -match '[\\/]evaluations[\\/]'
})
if ($answerKeyLeak.Count -gt 0) {
    throw 'Blind pilot setup failed: evaluation material is present inside the application workspace.'
}

$required = @(
    '.github/agents/security-reviewer.agent.md',
    '.github/prompts/security-review-changes.prompt.md',
    '.github/prompts/security-review-flow.prompt.md',
    '.github/skills/security-dotnet/SKILL.md',
    '.github/skills/security-angular/SKILL.md',
    '.github/skills/security-cross-stack/SKILL.md',
    '.security/run-security.ps1'
)
foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $destinationFull $relative))) {
        throw "Pilot setup missing installed pack file: $relative"
    }
}

Write-Host ''
Write-Host 'Blind VS Code pilot workspace prepared:'
Write-Host "  $destinationFull"
Write-Host ''
Write-Host 'Suggested sequence in GitHub Copilot Chat:'
Write-Host '  1. /security-review-changes'
Write-Host '  2. /security-review-flow'
Write-Host '  3. Select the Security Reviewer agent and ask: Review the current changes for security issues. Do not modify code.'
Write-Host ''
Write-Host 'Record the outputs before opening anything under evaluations/ in the source repository.'

if ($OpenInVSCode) {
    $code = Get-Command code -ErrorAction SilentlyContinue
    if ($null -eq $code) { throw 'VS Code command "code" is not available on PATH.' }
    & code $destinationFull
}
