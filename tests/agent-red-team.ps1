Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$prepare = Join-Path $repoRoot 'evaluations/prepare-agent-red-team.ps1'
$answerKey = Join-Path $repoRoot 'evaluations/agent-red-team-cases.json'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-agent-red-team-' + [guid]::NewGuid().ToString('N'))

try {
    Assert-True (Test-Path $prepare) 'red-team preparer is missing'
    Assert-True (Test-Path $answerKey) 'red-team answer key is missing'

    $cases = Get-Content $answerKey -Raw | ConvertFrom-Json
    Assert-True ($cases.schema -eq 1) 'unexpected red-team answer-key schema'
    Assert-True (@($cases.cases).Count -eq 5) 'expected five red-team cases'
    Assert-True (@($cases.cases.id | Sort-Object -Unique).Count -eq 5) 'red-team case IDs must be unique'

    & $prepare -Destination $tempRoot

    Assert-True (Test-Path (Join-Path $tempRoot '.github/agents/security-reviewer.agent.md')) 'Security Reviewer was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.github/prompts/security-review-build.prompt.md')) 'build-review prompt was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot '.security/run-security.ps1')) 'dispatcher was not installed'
    Assert-True (Test-Path (Join-Path $tempRoot 'attacks/source-comment.cs')) 'source prompt-injection carrier missing'
    Assert-True (Test-Path (Join-Path $tempRoot 'attacks/provider-metadata.json')) 'provider prompt-injection carrier missing'

    Assert-True (-not (Test-Path (Join-Path $tempRoot 'evaluations'))) 'answer-key directory leaked into red-team workspace'
    Assert-True (-not (Get-ChildItem -Recurse -Force $tempRoot -File | Where-Object { $_.Name -eq 'agent-red-team-cases.json' })) 'answer key leaked into red-team workspace'

    $changed = @((git -C $tempRoot status --porcelain=v1) | ForEach-Object { $_.Substring(3) })
    Assert-True ($changed -contains 'attacks/source-comment.cs') 'source carrier is not a current change'

    $collector = Join-Path $tempRoot '.security/scripts/collect-build-context.ps1'
    & $collector -RepositoryRoot $tempRoot -GitHubCommand '__missing_gh__' -AzureCommand '__missing_az__' -JFrogCommand '__missing_jf__' | Out-Null
    $contextPath = Join-Path $tempRoot '.security/output/build-context.json'
    Assert-True (Test-Path $contextPath) 'BuildContext evidence was not created'
    $contextText = Get-Content $contextPath -Raw
    $context = $contextText | ConvertFrom-Json

    Assert-True ($context.schema -eq 3) 'red-team harness requires AI-hardened BuildContext schema 3'
    Assert-True ($context.evidenceTrust -eq 'untrusted-external-content') 'external evidence trust marker missing'
    Assert-True ($context.configuration.trust -notin @('trusted-current','trusted-base')) 'unverifiable fixture provider mapping must not become trusted'
    Assert-True ($contextText -notmatch 'FAKE_AGENT_RED_TEAM_SECRET') 'credential-bearing remote secret leaked into AI-visible evidence'
    Assert-True ($contextText -notmatch 'FAKE_QUERY_SIGNATURE') 'remote query signature leaked into AI-visible evidence'
    Assert-True ($context.git.origin -eq 'https://example.invalid/org/repo.git') 'remote URL was not sanitized to origin/path only'

    $agent = Get-Content (Join-Path $tempRoot '.github/agents/security-reviewer.agent.md') -Raw
    Assert-True ($agent -match 'target:\s*vscode') 'agent is not VS Code scoped'
    Assert-True ($agent -match 'tools:\s*\["read",\s*"search",\s*"edit",\s*"execute"\]') 'agent tool allowlist drifted'
    Assert-True ($agent -match 'untrusted') 'agent no longer states the untrusted-evidence boundary'

    Write-Host 'Agent red-team harness tests passed.'
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
