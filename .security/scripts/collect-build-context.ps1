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
        finally { Pop-Location }

        $text = ($raw -join "`n").Trim()
        $accepted = $AcceptedExitCodes -contains $exitCode
        $data = $null
        $parseError = $false
        if ($accepted -and $Json -and -not [string]::IsNullOrWhiteSpace($text)) {
            try { $data = $text | ConvertFrom-Json }
            catch { $parseError = $true; $accepted = $false }
        }
        elseif ($accepted -and -not $Json) { $data = $text }

        return [pscustomobject]@{ ok=$accepted; data=$data; exitCode=$exitCode; parseError=$parseError }
    }
    catch { return [pscustomobject]@{ ok=$false; data=$null; exitCode=$null; parseError=$false } }
    finally { $global:LASTEXITCODE = $previousExit }
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Convert-SafeText {
    param($Value, [int]$MaxLength = 300)
    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    $text = [regex]::Replace($text, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '')
    $text = [regex]::Replace($text, '[\r\n\t]+', ' ')
    $text = $text.Trim()
    if ($text.Length -gt $MaxLength) { return $text.Substring(0, $MaxLength) + '…' }
    return $text
}

function Convert-SafeUrl {
    param($Value)
    $text = Convert-SafeText $Value 1000
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try {
        $uri = [Uri]$text
        if ($uri.IsAbsoluteUri -and $uri.Scheme -in @('http','https')) {
            $builder = [UriBuilder]$uri
            $builder.UserName = ''
            $builder.Password = ''
            $builder.Query = ''
            $builder.Fragment = ''
            return $builder.Uri.AbsoluteUri
        }
    } catch { }
    $text = $text -replace '^([a-zA-Z][a-zA-Z0-9+.-]*://)[^/@]+@', '$1[redacted]@'
    $text = ($text -split '[?#]', 2)[0]
    return $text
}

function Get-TrustedBaseRef {
    param([string]$Root)
    $remoteHead = ((git -C $Root symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null) -join '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($remoteHead)) { return $remoteHead }
    foreach ($candidate in @('origin/main','origin/master')) {
        git -C $Root rev-parse --verify --quiet $candidate 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }
    return $null
}

function Convert-GitHubRun {
    param($Run)
    [pscustomobject]@{
        databaseId = Get-PropertyValue $Run 'databaseId'
        number = Get-PropertyValue $Run 'number'
        name = Convert-SafeText (Get-PropertyValue $Run 'name') 160
        workflowName = Convert-SafeText (Get-PropertyValue $Run 'workflowName') 160
        status = Convert-SafeText (Get-PropertyValue $Run 'status') 40
        conclusion = Convert-SafeText (Get-PropertyValue $Run 'conclusion') 40
        headBranch = Convert-SafeText (Get-PropertyValue $Run 'headBranch') 250
        headSha = Convert-SafeText (Get-PropertyValue $Run 'headSha') 80
        event = Convert-SafeText (Get-PropertyValue $Run 'event') 80
        createdAt = Get-PropertyValue $Run 'createdAt'
        updatedAt = Get-PropertyValue $Run 'updatedAt'
        url = Convert-SafeUrl (Get-PropertyValue $Run 'url')
    }
}

function Convert-GitHubPr {
    param($Pr)
    if ($null -eq $Pr) { return $null }
    [pscustomobject]@{
        number = Get-PropertyValue $Pr 'number'
        title = Convert-SafeText (Get-PropertyValue $Pr 'title') 300
        url = Convert-SafeUrl (Get-PropertyValue $Pr 'url')
        headRefName = Convert-SafeText (Get-PropertyValue $Pr 'headRefName') 250
        headRefOid = Convert-SafeText (Get-PropertyValue $Pr 'headRefOid') 80
        baseRefName = Convert-SafeText (Get-PropertyValue $Pr 'baseRefName') 250
        isDraft = Get-PropertyValue $Pr 'isDraft'
        state = Convert-SafeText (Get-PropertyValue $Pr 'state') 40
    }
}

function Convert-GitHubCheck {
    param($Check)
    [pscustomobject]@{
        bucket = Convert-SafeText (Get-PropertyValue $Check 'bucket') 40
        completedAt = Get-PropertyValue $Check 'completedAt'
        description = Convert-SafeText (Get-PropertyValue $Check 'description') 300
        event = Convert-SafeText (Get-PropertyValue $Check 'event') 80
        link = Convert-SafeUrl (Get-PropertyValue $Check 'link')
        name = Convert-SafeText (Get-PropertyValue $Check 'name') 160
        startedAt = Get-PropertyValue $Check 'startedAt'
        state = Convert-SafeText (Get-PropertyValue $Check 'state') 40
        workflow = Convert-SafeText (Get-PropertyValue $Check 'workflow') 160
    }
}

function Convert-AzureRun {
    param($Run, [string]$HeadSha)
    $definition = Get-PropertyValue $Run 'definition'
    $sourceVersion = Convert-SafeText (Get-PropertyValue $Run 'sourceVersion') 80
    [pscustomobject]@{
        id = Get-PropertyValue $Run 'id'
        buildNumber = Convert-SafeText (Get-PropertyValue $Run 'buildNumber') 160
        pipelineId = Get-PropertyValue $definition 'id'
        pipelineName = Convert-SafeText (Get-PropertyValue $definition 'name') 160
        status = Convert-SafeText (Get-PropertyValue $Run 'status') 40
        result = Convert-SafeText (Get-PropertyValue $Run 'result') 40
        sourceBranch = Convert-SafeText (Get-PropertyValue $Run 'sourceBranch') 300
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
$originRaw = ((git -C $root config --get remote.origin.url 2>$null) -join '').Trim()
$origin = Convert-SafeUrl $originRaw
$detached = $branchRaw -eq 'HEAD' -or [string]::IsNullOrWhiteSpace($branchRaw)
$branch = $(if ($detached) { $null } else { Convert-SafeText $branchRaw 250 })
$changedFiles = @((git -C $root status --porcelain=v1 --untracked-files=all 2>$null) | ForEach-Object { if ($_.Length -gt 3) { Convert-SafeText $_.Substring(3) 500 } } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$worktreeDirty = $changedFiles.Count -gt 0

$configRelative = '.security/build-intelligence.json'
$configPath = Join-Path $root $configRelative
$trustedBaseRef = Get-TrustedBaseRef $root
$config = $null
$configTrust = 'absent'
if (Test-Path $configPath) {
    $configDirty = @((git -C $root status --porcelain=v1 -- $configRelative 2>$null)).Count -gt 0
    $defaultBranch = $(if ($trustedBaseRef) { $trustedBaseRef -replace '^origin/','' } else { $null })
    if ($configDirty) {
        $configTrust = 'untrusted-worktree'
    }
    elseif (-not [string]::IsNullOrWhiteSpace($branch) -and (($branch -eq $defaultBranch) -or ($null -eq $trustedBaseRef -and $branch -in @('main','master')))) {
        $configTrust = 'trusted-current'
    }
    elseif ($trustedBaseRef) {
        git -C $root diff --quiet "$trustedBaseRef...HEAD" -- $configRelative 2>$null
        if ($LASTEXITCODE -eq 0) { $configTrust = 'trusted-base' }
        else { $configTrust = 'untrusted-branch' }
    }
    else {
        $configTrust = 'unverified'
    }

    if ($configTrust -in @('trusted-current','trusted-base')) {
        try { $config = Get-Content $configPath -Raw | ConvertFrom-Json }
        catch { throw "Invalid trusted build intelligence config: $configPath" }
    }
}

$github = [ordered]@{ status='unavailable'; correlation='none'; untrustedContent=$true; runs=@(); pr=$null; checks=@(); errors=@() }
$azure = [ordered]@{ status='unavailable'; correlation='none'; untrustedContent=$true; runs=@(); errors=@() }
$jfrog = [ordered]@{ status='unavailable'; untrustedContent=$true; builds=@(); errors=@() }

if (Test-CommandAvailable $GitHubCommand) {
    $auth = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('auth','status') -WorkingDirectory $root
    if ($auth.ok) {
        $github.status = 'available'
        $fields = 'databaseId,number,name,workflowName,status,conclusion,headBranch,headSha,event,createdAt,updatedAt,url'
        if (-not [string]::IsNullOrWhiteSpace($headSha)) {
            $exact = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('run','list','--commit',$headSha,'--limit','10','--json',$fields) -WorkingDirectory $root -Json
            if ($exact.ok) { $github.runs=@($exact.data | ForEach-Object { Convert-GitHubRun $_ }); if ($github.runs.Count -gt 0) { $github.correlation='exact-head' } }
            else { $github.errors += @([pscustomobject]@{ operation='runs-by-commit'; exitCode=$exact.exitCode; parseError=$exact.parseError }) }
        }
        if ($github.runs.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($branch)) {
            $byBranch = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('run','list','--branch',$branch,'--limit','10','--json',$fields) -WorkingDirectory $root -Json
            if ($byBranch.ok) { $github.runs=@($byBranch.data | ForEach-Object { Convert-GitHubRun $_ }); if ($github.runs.Count -gt 0) { $github.correlation='branch' } }
            else { $github.errors += @([pscustomobject]@{ operation='runs-by-branch'; exitCode=$byBranch.exitCode; parseError=$byBranch.parseError }) }
        }
        if (-not [string]::IsNullOrWhiteSpace($branch)) {
            $pr = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('pr','view',$branch,'--json','number,title,url,headRefName,headRefOid,baseRefName,isDraft,state') -WorkingDirectory $root -Json
            if ($pr.ok -and $null -ne $pr.data) {
                $github.pr = Convert-GitHubPr $pr.data
                $checks = Invoke-NativeCommand -Command $GitHubCommand -Arguments @('pr','checks',$branch,'--json','bucket,completedAt,description,event,link,name,startedAt,state,workflow') -WorkingDirectory $root -AcceptedExitCodes @(0,8) -Json
                if ($checks.ok) { $github.checks=@($checks.data | ForEach-Object { Convert-GitHubCheck $_ }) }
                else { $github.errors += @([pscustomobject]@{ operation='pr-checks'; exitCode=$checks.exitCode; parseError=$checks.parseError }) }
            }
            elseif ($pr.exitCode -notin @(0,1)) { $github.errors += @([pscustomobject]@{ operation='pr-view'; exitCode=$pr.exitCode; parseError=$pr.parseError }) }
        }
        if ($github.errors.Count -gt 0 -and $github.runs.Count -eq 0 -and $null -eq $github.pr) { $github.status='query-failed' }
    }
    else { $github.status='not-authenticated' }
}

if (Test-CommandAvailable $AzureCommand) {
    $extension = Invoke-NativeCommand -Command $AzureCommand -Arguments @('extension','show','--name','azure-devops','--output','json','--only-show-errors') -WorkingDirectory $root -Json
    if (-not $extension.ok) { $azure.status='extension-unavailable' }
    elseif ($detached) { $azure.status='no-branch' }
    else {
        $azureConfig = $(if ($null -ne $config) { Get-PropertyValue $config 'azure' } else { $null })
        $originLooksAzure = $originRaw -match '(dev\.azure\.com|visualstudio\.com)'
        $untrustedConfigPresent = (Test-Path $configPath) -and $configTrust -notin @('trusted-current','trusted-base')
        if ($null -eq $azureConfig -and -not $originLooksAzure) { $azure.status=$(if ($untrustedConfigPresent) {'config-untrusted'} else {'not-configured'}) }
        else {
            $args = @('pipelines','runs','list','--branch',$branch,'--top','10','--query-order','QueueTimeDesc','--output','json','--only-show-errors')
            if ($null -ne $azureConfig) {
                $organization=Get-PropertyValue $azureConfig 'organization'; $project=Get-PropertyValue $azureConfig 'project'; $pipelineIds=@(Get-PropertyValue $azureConfig 'pipelineIds')
                if ($organization) { $args += @('--organization',[string]$organization) }
                if ($project) { $args += @('--project',[string]$project) }
                if ($pipelineIds.Count -gt 0 -and $null -ne $pipelineIds[0]) { $args += '--pipeline-ids'; foreach ($pipelineId in $pipelineIds) { $args += [string]$pipelineId } }
                if (-not $organization -and -not $project) { $args += @('--detect','true') }
            } else { $args += @('--detect','true') }
            $runsResult = Invoke-NativeCommand -Command $AzureCommand -Arguments $args -WorkingDirectory $root -Json
            if ($runsResult.ok) {
                $azure.status='available'; $azure.runs=@($runsResult.data | ForEach-Object { Convert-AzureRun -Run $_ -HeadSha $headSha })
                if (@($azure.runs | Where-Object { $_.exactHead }).Count -gt 0) { $azure.correlation='exact-head' } elseif ($azure.runs.Count -gt 0) { $azure.correlation='branch' }
            } else { $azure.status='query-failed'; $azure.errors += @([pscustomobject]@{ operation='pipeline-runs'; exitCode=$runsResult.exitCode; parseError=$runsResult.parseError }) }
        }
    }
}

if (Test-CommandAvailable $JFrogCommand) {
    $jfrog.status='not-resolved'
    $jfrogConfig=$(if ($null -ne $config) { Get-PropertyValue $config 'jfrog' } else { $null })
    if ((Test-Path $configPath) -and $configTrust -notin @('trusted-current','trusted-base')) { $jfrog.status='config-untrusted' }
    $buildName=$(if ($null -ne $jfrogConfig) { Get-PropertyValue $jfrogConfig 'buildName' } else { $null })
    if (-not [string]::IsNullOrWhiteSpace([string]$buildName)) {
        $buildNumber=$null; $source=[string](Get-PropertyValue $jfrogConfig 'buildNumberFrom')
        if ($source -eq 'githubRunNumber' -and $github.runs.Count -gt 0) { $buildNumber=[string]$github.runs[0].number }
        elseif ($source -eq 'githubRunId' -and $github.runs.Count -gt 0) { $buildNumber=[string]$github.runs[0].databaseId }
        elseif ($source -eq 'azureBuildId' -and $azure.runs.Count -gt 0) { $candidate=@($azure.runs | Where-Object { $_.exactHead }); if ($candidate.Count -eq 0) { $candidate=@($azure.runs) }; if ($candidate.Count -gt 0) { $buildNumber=[string]$candidate[0].id } }
        elseif ($source -eq 'azureBuildNumber' -and $azure.runs.Count -gt 0) { $candidate=@($azure.runs | Where-Object { $_.exactHead }); if ($candidate.Count -eq 0) { $candidate=@($azure.runs) }; if ($candidate.Count -gt 0) { $buildNumber=[string]$candidate[0].buildNumber } }
        $fixedBuildNumber=Get-PropertyValue $jfrogConfig 'buildNumber'
        if ([string]::IsNullOrWhiteSpace($buildNumber) -and $fixedBuildNumber) { $buildNumber=[string]$fixedBuildNumber; $source='configured' }
        if (-not [string]::IsNullOrWhiteSpace($buildNumber)) {
            $safeBuildName = Convert-SafeText $buildName 200
            $safeBuildNumber = Convert-SafeText $buildNumber 200
            $scanArgs=@('build-scan',$safeBuildName,$safeBuildNumber,'--format=json','--vuln')
            $serverId=Get-PropertyValue $jfrogConfig 'serverId'; $project=Get-PropertyValue $jfrogConfig 'project'
            if ($serverId) { $scanArgs += @('--server-id',[string]$serverId) }; if ($project) { $scanArgs += @('--project',[string]$project) }
            $scan=Invoke-NativeCommand -Command $JFrogCommand -Arguments $scanArgs -WorkingDirectory $root -AcceptedExitCodes @(0,3) -Json
            $evidenceFile=$null
            if ($scan.ok -and $null -ne $scan.data) { $evidencePath=Join-Path $output 'jfrog-build-scan.json'; $scan.data | ConvertTo-Json -Depth 30 | Set-Content $evidencePath; $evidenceFile='.security/output/jfrog-build-scan.json' }
            if ($scan.ok) { $jfrog.status='available' } else { $jfrog.status='query-failed'; $jfrog.errors += @([pscustomobject]@{ operation='build-scan'; exitCode=$scan.exitCode; parseError=$scan.parseError }) }
            $jfrog.builds=@([pscustomobject]@{ name=$safeBuildName; number=$safeBuildNumber; source=Convert-SafeText $source 80; scanStatus=$(if (-not $scan.ok) {'failed'} elseif ($scan.exitCode -eq 3) {'policy-violation'} else {'completed'}); exitCode=$scan.exitCode; evidenceFile=$evidenceFile })
        }
    }
}

$result=[ordered]@{
    schema=3
    collectedAt=(Get-Date).ToUniversalTime().ToString('o')
    evidenceTrust='untrusted-external-content'
    configuration=[ordered]@{ path=$configRelative; trust=$configTrust; trustedBaseRef=$trustedBaseRef }
    git=[ordered]@{ repositoryRoot='.'; branch=$branch; headSha=$headSha; detached=$detached; origin=$origin; changedFiles=$changedFiles; worktreeDirty=$worktreeDirty; remoteBuildScope=$(if ($worktreeDirty) {'committed-head-only'} else {'head-and-worktree'}) }
    providers=[ordered]@{ github=$github; azure=$azure; jfrog=$jfrog }
}
$path=Join-Path $output 'build-context.json'
$result | ConvertTo-Json -Depth 15 | Set-Content $path
$result
