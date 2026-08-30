param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [string]$GitHubCommand = 'gh',
    [string]$AzureCommand = 'az',
    [string]$JFrogCommand = 'jf'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandAvailable([string]$Command) {
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Invoke-NativeCommand {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int[]]$AcceptedExitCodes = @(0),
        [switch]$Json
    )

    $previousExit = $global:LASTEXITCODE
    try {
        Push-Location $WorkingDirectory
        try {
            $raw = & $Command @Arguments 2>$null
            $exitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        $text = ($raw -join "`n").Trim()
        $accepted = $AcceptedExitCodes -contains $exitCode
        $data = $null
        $parseError = $false

        if ($accepted -and $Json -and -not [string]::IsNullOrWhiteSpace($text)) {
            try { $data = $text | ConvertFrom-Json }
            catch { $parseError = $true; $accepted = $false }
        }
        elseif ($accepted -and -not $Json) {
            $data = $text
        }

        return [pscustomobject]@{
            ok = $accepted
            data = $data
            exitCode = $exitCode
            parseError = $parseError
        }
    }
    catch {
        return [pscustomobject]@{
            ok = $false
            data = $null
            exitCode = $null
            parseError = $false
        }
    }
    finally {
        $global:LASTEXITCODE = $previousExit
    }
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Convert-AzureRun {
    param($Run, [string]$HeadSha)

    $definition = Get-PropertyValue $Run 'definition'
    $sourceVersion = [string](Get-PropertyValue $Run 'sourceVersion')
    return [pscustomobject]@{
        id = Get-PropertyValue $Run 'id'
        buildNumber = Get-PropertyValue $Run 'buildNumber'
        pipelineId = Get-PropertyValue $definition 'id'
        pipelineName = Get-PropertyValue $definition 'name'
        status = Get-PropertyValue $Run 'status'
        result = Get-PropertyValue $Run 'result'
        sourceBranch = Get-PropertyValue $Run 'sourceBranch'
        sourceVersion = $sourceVersion
        queueTime = Get-PropertyValue $Run 'queueTime'
        startTime = Get-PropertyValue $Run 'startTime'
        finishTime = Get-PropertyValue $Run 'finishTime'
        exactHead = (-not [string]::IsNullOrWhiteSpace($HeadSha) -and $sourceVersion -eq $HeadSha)
    }
}

$root = (Resolve-Path $RepositoryRoot).Path
$output = Join-Path $root '.security/output'
New-Item -ItemType Directory -Force -Path $output | Out-Null

$branchRaw = ((git -C $root rev-parse --abbrev-ref HEAD 2>$null) -join '').Trim()
$headSha = ((git -C $root rev-parse HEAD 2>$null) -join '').Trim()
$origin = ((git -C $root config --get remote.origin.url 2>$null) -join '').Trim()
$detached = $branchRaw -eq 'HEAD' -or [string]::IsNullOrWhiteSpace($branchRaw)
$branch = $(if ($detached) { $null } else { $branchRaw })
$changedFiles = @((git -C $root status --porcelain=v1 --untracked-files=all 2>$null) | ForEach-Object {
    if ($_.Length -gt 3) { $_.Substring(3) }
} | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$worktreeDirty = $changedFiles.Count -gt 0

$configPath = Join-Path $root '.security/build-intelligence.json'
$config = $null
if (Test-Path $configPath) {
    try { $config = Get-Content $configPath -Raw | ConvertFrom-Json }
    catch { throw "Invalid build intelligence config: $configPath" }
}

$github = [ordered]@{
    status = 'unavailable'
    correlation = 'none'
    runs = @()
    pr = $null
    checks = @()
    errors = @()
}
$azure = [ordered]@{
    status = 'unavailable'
    correlation = 'none'
    runs = @()
    errors = @()
}
$jfrog = [ordered]@{
    status = 'unavailable'
    builds = @()
    errors = @()
}

if (Test-CommandAvailable $GitHubCommand) {
    $auth = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('auth','status') -WorkingDirectory $root
    if ($auth.ok) {
        $github.status = 'available'
        $fields = 'databaseId,number,name,workflowName,status,conclusion,headBranch,headSha,event,createdAt,updatedAt,url'

        if (-not [string]::IsNullOrWhiteSpace($headSha)) {
            $exact = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('run','list','--commit',$headSha,'--limit','10','--json',$fields) -WorkingDirectory $root -Json
            if ($exact.ok) {
                $github.runs = @($exact.data)
                if ($github.runs.Count -gt 0) { $github.correlation = 'exact-head' }
            }
            else {
                $github.errors += @([pscustomobject]@{ operation = 'runs-by-commit'; exitCode = $exact.exitCode; parseError = $exact.parseError })
            }
        }

        if ($github.runs.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($branch)) {
            $byBranch = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('run','list','--branch',$branch,'--limit','10','--json',$fields) -WorkingDirectory $root -Json
            if ($byBranch.ok) {
                $github.runs = @($byBranch.data)
                if ($github.runs.Count -gt 0) { $github.correlation = 'branch' }
            }
            else {
                $github.errors += @([pscustomobject]@{ operation = 'runs-by-branch'; exitCode = $byBranch.exitCode; parseError = $byBranch.parseError })
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($branch)) {
            $pr = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('pr','view',$branch,'--json','number,title,url,headRefName,headRefOid,baseRefName,isDraft,state') -WorkingDirectory $root -Json
            if ($pr.ok -and $null -ne $pr.data) {
                $github.pr = $pr.data
                $checks = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('pr','checks',$branch,'--json','bucket,completedAt,description,event,link,name,startedAt,state,workflow') -WorkingDirectory $root -AcceptedExitCodes @(0,8) -Json
                if ($checks.ok) { $github.checks = @($checks.data) }
                else { $github.errors += @([pscustomobject]@{ operation = 'pr-checks'; exitCode = $checks.exitCode; parseError = $checks.parseError }) }
            }
            elseif ($pr.exitCode -notin @(0,1)) {
                $github.errors += @([pscustomobject]@{ operation = 'pr-view'; exitCode = $pr.exitCode; parseError = $pr.parseError })
            }
        }

        if ($github.errors.Count -gt 0 -and $github.runs.Count -eq 0 -and $null -eq $github.pr) {
            $github.status = 'query-failed'
        }
    }
    else {
        $github.status = 'not-authenticated'
    }
}

if (Test-CommandAvailable $AzureCommand) {
    $extension = Invoke-NativeCommand -Command $AzureCommand -Arguments @('extension','show','--name','azure-devops','--output','json','--only-show-errors') -WorkingDirectory $root -Json
    if (-not $extension.ok) {
        $azure.status = 'extension-unavailable'
    }
    elseif ($detached) {
        $azure.status = 'no-branch'
    }
    else {
        $azureConfig = $(if ($null -ne $config) { Get-PropertyValue $config 'azure' } else { $null })
        $originLooksAzure = $origin -match '(dev\.azure\.com|visualstudio\.com)'
        if ($null -eq $azureConfig -and -not $originLooksAzure) {
            $azure.status = 'not-configured'
        }
        else {
            $args = @('pipelines','runs','list','--branch',$branch,'--top','10','--query-order','QueueTimeDesc','--output','json','--only-show-errors')
            if ($null -ne $azureConfig) {
                $organization = Get-PropertyValue $azureConfig 'organization'
                $project = Get-PropertyValue $azureConfig 'project'
                $pipelineIds = @(Get-PropertyValue $azureConfig 'pipelineIds')
                if ($organization) { $args += @('--organization',[string]$organization) }
                if ($project) { $args += @('--project',[string]$project) }
                if ($pipelineIds.Count -gt 0 -and $null -ne $pipelineIds[0]) {
                    $args += '--pipeline-ids'
                    foreach ($pipelineId in $pipelineIds) { $args += [string]$pipelineId }
                }
                if (-not $organization -and -not $project) { $args += @('--detect','true') }
            }
            else {
                $args += @('--detect','true')
            }

            $runsResult = Invoke-NativeCommand -Command $AzureCommand -Arguments $args -WorkingDirectory $root -Json
            if ($runsResult.ok) {
                $azure.status = 'available'
                $azure.runs = @($runsResult.data | ForEach-Object { Convert-AzureRun -Run $_ -HeadSha $headSha })
                if (@($azure.runs | Where-Object { $_.exactHead }).Count -gt 0) { $azure.correlation = 'exact-head' }
                elseif ($azure.runs.Count -gt 0) { $azure.correlation = 'branch' }
            }
            else {
                $azure.status = 'query-failed'
                $azure.errors += @([pscustomobject]@{ operation = 'pipeline-runs'; exitCode = $runsResult.exitCode; parseError = $runsResult.parseError })
            }
        }
    }
}

if (Test-CommandAvailable $JFrogCommand) {
    $jfrog.status = 'not-resolved'
    $jfrogConfig = $(if ($null -ne $config) { Get-PropertyValue $config 'jfrog' } else { $null })
    $buildName = $(if ($null -ne $jfrogConfig) { Get-PropertyValue $jfrogConfig 'buildName' } else { $null })

    if (-not [string]::IsNullOrWhiteSpace([string]$buildName)) {
        $buildNumber = $null
        $source = [string](Get-PropertyValue $jfrogConfig 'buildNumberFrom')
        if ($source -eq 'githubRunNumber' -and $github.runs.Count -gt 0) { $buildNumber = [string]$github.runs[0].number }
        elseif ($source -eq 'githubRunId' -and $github.runs.Count -gt 0) { $buildNumber = [string]$github.runs[0].databaseId }
        elseif ($source -eq 'azureBuildId' -and $azure.runs.Count -gt 0) {
            $candidate = @($azure.runs | Where-Object { $_.exactHead })
            if ($candidate.Count -eq 0) { $candidate = @($azure.runs) }
            if ($candidate.Count -gt 0) { $buildNumber = [string]$candidate[0].id }
        }
        elseif ($source -eq 'azureBuildNumber' -and $azure.runs.Count -gt 0) {
            $candidate = @($azure.runs | Where-Object { $_.exactHead })
            if ($candidate.Count -eq 0) { $candidate = @($azure.runs) }
            if ($candidate.Count -gt 0) { $buildNumber = [string]$candidate[0].buildNumber }
        }

        $fixedBuildNumber = Get-PropertyValue $jfrogConfig 'buildNumber'
        if ([string]::IsNullOrWhiteSpace($buildNumber) -and $fixedBuildNumber) {
            $buildNumber = [string]$fixedBuildNumber
            $source = 'configured'
        }

        if (-not [string]::IsNullOrWhiteSpace($buildNumber)) {
            $scanArgs = @('build-scan',[string]$buildName,$buildNumber,'--format=json')
            $serverId = Get-PropertyValue $jfrogConfig 'serverId'
            $project = Get-PropertyValue $jfrogConfig 'project'
            if ($serverId) { $scanArgs += @('--server-id',[string]$serverId) }
            if ($project) { $scanArgs += @('--project',[string]$project) }

            $scan = Invoke-NativeCommand -Command $JFrogCommand -Arguments $scanArgs -WorkingDirectory $root -AcceptedExitCodes @(0,3) -Json
            $evidenceFile = $null
            if ($scan.ok -and $null -ne $scan.data) {
                $evidencePath = Join-Path $output 'jfrog-build-scan.json'
                $scan.data | ConvertTo-Json -Depth 30 | Set-Content $evidencePath
                $evidenceFile = '.security/output/jfrog-build-scan.json'
            }

            if ($scan.ok) {
                $jfrog.status = 'available'
            }
            else {
                $jfrog.status = 'query-failed'
                $jfrog.errors += @([pscustomobject]@{ operation = 'build-scan'; exitCode = $scan.exitCode; parseError = $scan.parseError })
            }

            $jfrog.builds = @([pscustomobject]@{
                name = [string]$buildName
                number = $buildNumber
                source = $source
                scanStatus = $(if (-not $scan.ok) { 'failed' } elseif ($scan.exitCode -eq 3) { 'policy-violation' } else { 'completed' })
                exitCode = $scan.exitCode
                evidenceFile = $evidenceFile
            })
        }
    }
}

$result = [ordered]@{
    schema = 2
    collectedAt = (Get-Date).ToUniversalTime().ToString('o')
    git = [ordered]@{
        repositoryRoot = '.'
        branch = $branch
        headSha = $headSha
        detached = $detached
        origin = $origin
        changedFiles = $changedFiles
        worktreeDirty = $worktreeDirty
        remoteBuildScope = $(if ($worktreeDirty) { 'committed-head-only' } else { 'head-and-worktree' })
    }
    providers = [ordered]@{
        github = $github
        azure = $azure
        jfrog = $jfrog
    }
}

$path = Join-Path $output 'build-context.json'
$result | ConvertTo-Json -Depth 15 | Set-Content $path
$result
