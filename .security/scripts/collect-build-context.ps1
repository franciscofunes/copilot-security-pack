param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [string]$GitHubCommand = 'gh',
    [string]$AzureCommand = 'az',
    [string]$JFrogCommand = 'jf'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-JsonCommand {
    param([string]$Command, [string[]]$Arguments)
    try {
        $raw = & $Command @Arguments 2>$null
        $exit = $LASTEXITCODE
        if ($exit -ne 0) { return [pscustomobject]@{ ok = $false; data = $null; exitCode = $exit } }
        $text = ($raw -join "`n").Trim()
        if ([string]::IsNullOrWhiteSpace($text)) { return [pscustomobject]@{ ok = $true; data = $null; exitCode = 0 } }
        return [pscustomobject]@{ ok = $true; data = ($text | ConvertFrom-Json); exitCode = 0 }
    } catch {
        return [pscustomobject]@{ ok = $false; data = $null; exitCode = $null }
    }
}

function Test-CommandAvailable([string]$Command) {
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

$root = (Resolve-Path $RepositoryRoot).Path
$output = Join-Path $root '.security/output'
New-Item -ItemType Directory -Force -Path $output | Out-Null

$branch = ((git -C $root rev-parse --abbrev-ref HEAD 2>$null) -join '').Trim()
$headSha = ((git -C $root rev-parse HEAD 2>$null) -join '').Trim()
$origin = ((git -C $root config --get remote.origin.url 2>$null) -join '').Trim()
$detached = $branch -eq 'HEAD' -or [string]::IsNullOrWhiteSpace($branch)
if ($detached) { $branch = $null }
$changedFiles = @((git -C $root status --porcelain=v1 2>$null) | ForEach-Object { if ($_.Length -gt 3) { $_.Substring(3) } } | Where-Object { $_ })

$configPath = Join-Path $root '.security/build-intelligence.json'
$config = $null
if (Test-Path $configPath) {
    try { $config = Get-Content $configPath -Raw | ConvertFrom-Json } catch { throw "Invalid build intelligence config: $configPath" }
}

$github = [ordered]@{ status = 'unavailable'; runs = @(); pr = $null; checks = @() }
$azure = [ordered]@{ status = 'unavailable'; runs = @() }
$jfrog = [ordered]@{ status = 'unavailable'; builds = @() }

if (Test-CommandAvailable $GitHubCommand) {
    & $GitHubCommand auth status 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $github.status = 'available'
        $fields = 'databaseId,number,name,workflowName,status,conclusion,headBranch,headSha,event,createdAt,updatedAt,url'
        if (-not [string]::IsNullOrWhiteSpace($headSha)) {
            $exact = Invoke-JsonCommand $GitHubCommand @('run','list','--commit',$headSha,'--limit','10','--json',$fields)
            if ($exact.ok -and $null -ne $exact.data) { $github.runs = @($exact.data) }
        }
        if ($github.runs.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($branch)) {
            $byBranch = Invoke-JsonCommand $GitHubCommand @('run','list','--branch',$branch,'--limit','10','--json',$fields)
            if ($byBranch.ok -and $null -ne $byBranch.data) { $github.runs = @($byBranch.data) }
        }
        if (-not [string]::IsNullOrWhiteSpace($branch)) {
            $pr = Invoke-JsonCommand $GitHubCommand @('pr','view',$branch,'--json','number,title,url,headRefName,headRefOid,baseRefName,isDraft,state')
            if ($pr.ok -and $null -ne $pr.data) {
                $github.pr = $pr.data
                $checks = Invoke-JsonCommand $GitHubCommand @('pr','checks',$branch,'--json','bucket,completedAt,description,event,link,name,startedAt,state,workflow')
                if ($checks.ok -and $null -ne $checks.data) { $github.checks = @($checks.data) }
            }
        }
    } else { $github.status = 'not-authenticated' }
}

if (Test-CommandAvailable $AzureCommand) {
    $account = Invoke-JsonCommand $AzureCommand @('account','show','--output','json','--only-show-errors')
    if ($account.ok) {
        if ($detached) {
            $azure.status = 'no-branch'
        } else {
            $azure.status = 'available'
            $args = @('pipelines','runs','list','--branch',$branch,'--top','10','--query-order','QueueTimeDesc','--output','json','--only-show-errors')
            if ($null -ne $config -and $null -ne $config.azure) {
                if ($config.azure.organization) { $args += @('--organization',[string]$config.azure.organization) }
                if ($config.azure.project) { $args += @('--project',[string]$config.azure.project) }
                if ($config.azure.pipelineIds) { $args += @('--pipeline-ids',(@($config.azure.pipelineIds) -join ' ')) }
            } else { $args += @('--detect','true') }
            $runs = Invoke-JsonCommand $AzureCommand $args
            if ($runs.ok -and $null -ne $runs.data) { $azure.runs = @($runs.data) }
            elseif (-not $runs.ok) { $azure.status = 'not-configured' }
        }
    } else { $azure.status = 'not-authenticated' }
}

if (Test-CommandAvailable $JFrogCommand) {
    $jfrog.status = 'not-resolved'
    if ($null -ne $config -and $null -ne $config.jfrog -and $config.jfrog.buildName) {
        $buildNumber = $null
        $source = [string]$config.jfrog.buildNumberFrom
        if ($source -eq 'githubRunNumber' -and $github.runs.Count -gt 0) { $buildNumber = [string]$github.runs[0].number }
        elseif ($source -eq 'githubRunId' -and $github.runs.Count -gt 0) { $buildNumber = [string]$github.runs[0].databaseId }
        elseif ($source -eq 'azureBuildId' -and $azure.runs.Count -gt 0) { $buildNumber = [string]$azure.runs[0].id }
        elseif ($source -eq 'azureBuildNumber' -and $azure.runs.Count -gt 0) { $buildNumber = [string]$azure.runs[0].buildNumber }
        elseif ($config.jfrog.buildNumber) { $buildNumber = [string]$config.jfrog.buildNumber }

        if (-not [string]::IsNullOrWhiteSpace($buildNumber)) {
            $jfrog.status = 'available'
            $serverArgs = @()
            if ($config.jfrog.serverId) { $serverArgs = @('--server-id',[string]$config.jfrog.serverId) }
            $scanArgs = @('build-scan',[string]$config.jfrog.buildName,$buildNumber,'--format=json') + $serverArgs
            if ($config.jfrog.project) { $scanArgs += @('--project',[string]$config.jfrog.project) }
            $scan = Invoke-JsonCommand $JFrogCommand $scanArgs
            $jfrog.builds = @([pscustomobject]@{
                name = [string]$config.jfrog.buildName
                number = $buildNumber
                source = $source
                scanStatus = $(if ($scan.ok) { 'completed' } else { 'failed-or-not-indexed' })
                scan = $scan.data
            })
        }
    }
}

$result = [ordered]@{
    schema = 1
    collectedAt = (Get-Date).ToUniversalTime().ToString('o')
    git = [ordered]@{
        repositoryRoot = '.'
        branch = $branch
        headSha = $headSha
        detached = $detached
        origin = $origin
        changedFiles = $changedFiles
    }
    providers = [ordered]@{
        github = $github
        azure = $azure
        jfrog = $jfrog
    }
}

$path = Join-Path $output 'build-context.json'
$result | ConvertTo-Json -Depth 12 | Set-Content $path
$result
