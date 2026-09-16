param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [string]$GitHubCommand = 'gh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandAvailable([string]$Command) { return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue) }
function Invoke-Gh {
    param([string[]]$Arguments,[string]$WorkingDirectory,[switch]$Json)
    $previousExit=$global:LASTEXITCODE
    try {
        Push-Location $WorkingDirectory
        try { $raw=& $GitHubCommand @Arguments 2>$null; $exitCode=$LASTEXITCODE } finally { Pop-Location }
        $text=($raw -join "`n").Trim(); $ok=$exitCode -eq 0; $data=$null; $parseError=$false
        if ($ok -and $Json -and -not [string]::IsNullOrWhiteSpace($text)) { try { $data=$text|ConvertFrom-Json } catch { $ok=$false; $parseError=$true } }
        elseif ($ok -and -not $Json) { $data=$text }
        [pscustomobject]@{ok=$ok;exitCode=$exitCode;parseError=$parseError;data=$data}
    } catch { [pscustomobject]@{ok=$false;exitCode=$null;parseError=$false;data=$null} }
    finally { $global:LASTEXITCODE=$previousExit }
}
function Get-PropertyValue { param($Object,[string]$Name); if($null -eq $Object){return $null}; $p=$Object.PSObject.Properties[$Name]; if($null -eq $p){return $null}; $p.Value }
function Convert-SafeText { param($Value,[int]$MaxLength=200); if($null -eq $Value){return $null}; $text=[string]$Value; $text=[regex]::Replace($text,'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',''); $text=[regex]::Replace($text,'[\r\n\t]+',' '); $text=$text.Trim(); if($text.Length -gt $MaxLength){return $text.Substring(0,$MaxLength)+'…'}; $text }
function Convert-Configuration {
    param($Configuration)
    if ($null -eq $Configuration) { return $null }
    [pscustomobject]@{
        id = Get-PropertyValue $Configuration 'id'
        targetType = Convert-SafeText (Get-PropertyValue $Configuration 'target_type') 40
        name = Convert-SafeText (Get-PropertyValue $Configuration 'name') 200
        dependencyGraph = Convert-SafeText (Get-PropertyValue $Configuration 'dependency_graph') 40
        dependabotAlerts = Convert-SafeText (Get-PropertyValue $Configuration 'dependabot_alerts') 40
        dependabotSecurityUpdates = Convert-SafeText (Get-PropertyValue $Configuration 'dependabot_security_updates') 40
        enforcement = Convert-SafeText (Get-PropertyValue $Configuration 'enforcement') 40
    }
}

$root=(Resolve-Path $RepositoryRoot).Path
$output=Join-Path $root '.security/output'; New-Item -ItemType Directory -Force -Path $output | Out-Null
$result=[ordered]@{
    schema=1
    collectedAt=(Get-Date).ToUniversalTime().ToString('o')
    evidenceTrust='untrusted-external-content'
    status='unavailable'
    organization=$null
    repository=$null
    configurations=[ordered]@{status='not-queried';items=@()}
    defaults=[ordered]@{status='not-queried';items=@()}
    repositoryConfiguration=[ordered]@{status='not-queried';attachmentStatus=$null;configuration=$null}
    errors=@()
}

function Write-Result { $result|ConvertTo-Json -Depth 10|Set-Content (Join-Path $output 'dependabot-org-context.json'); $result }

if (-not (Test-CommandAvailable $GitHubCommand)) { Write-Result; exit 0 }
$auth=Invoke-Gh @('auth','status') $root
if (-not $auth.ok) { $result.status='not-authenticated'; Write-Result; exit 0 }
$repo=Invoke-Gh @('repo','view','--json','nameWithOwner') $root -Json
if (-not $repo.ok) { $result.status='repository-unresolved'; Write-Result; exit 0 }
$fullName=[string](Get-PropertyValue $repo.data 'nameWithOwner'); $parts=$fullName -split '/',2
if($parts.Count -ne 2){$result.status='repository-unresolved';Write-Result;exit 0}
$owner=$parts[0]; $result.repository=Convert-SafeText $fullName 300
$ownerResult=Invoke-Gh @('api',"users/$owner",'-H','X-GitHub-Api-Version: 2026-03-10') $root -Json
if(-not $ownerResult.ok){$result.status='owner-unresolved';Write-Result;exit 0}
if((Get-PropertyValue $ownerResult.data 'type') -ne 'Organization'){$result.status='not-applicable';Write-Result;exit 0}
$result.organization=Convert-SafeText $owner 200
$result.status='organization-detected'

$configs=Invoke-Gh @('api',"orgs/$owner/code-security/configurations?per_page=100",'--paginate','--slurp','-H','X-GitHub-Api-Version: 2026-03-10') $root -Json
if($configs.ok){
    $all=@(); foreach($page in @($configs.data)){ $all += @($page) }
    $result.configurations.status='available'
    $result.configurations.items=@($all|ForEach-Object{Convert-Configuration $_})
}else{$result.configurations.status='unavailable-or-no-org-admin';$result.errors+=@([pscustomobject]@{operation='org-code-security-configurations';exitCode=$configs.exitCode})}

$defaults=Invoke-Gh @('api',"orgs/$owner/code-security/configurations/defaults",'-H','X-GitHub-Api-Version: 2026-03-10') $root -Json
if($defaults.ok){
    $result.defaults.status='available'
    $result.defaults.items=@(@($defaults.data)|ForEach-Object{[pscustomobject]@{defaultForNewRepos=Convert-SafeText (Get-PropertyValue $_ 'default_for_new_repos') 60;configuration=Convert-Configuration (Get-PropertyValue $_ 'configuration')}})
}else{$result.defaults.status='unavailable-or-no-org-admin';$result.errors+=@([pscustomobject]@{operation='org-default-code-security-configurations';exitCode=$defaults.exitCode})}

$attached=Invoke-Gh @('api',"repos/$fullName/code-security-configuration",'-H','X-GitHub-Api-Version: 2026-03-10') $root -Json
if($attached.ok){
    $result.repositoryConfiguration.status='available'
    $result.repositoryConfiguration.attachmentStatus=Convert-SafeText (Get-PropertyValue $attached.data 'status') 60
    $result.repositoryConfiguration.configuration=Convert-Configuration (Get-PropertyValue $attached.data 'configuration')
}else{$result.repositoryConfiguration.status='unavailable-or-no-admin-read';$result.errors+=@([pscustomobject]@{operation='repository-code-security-configuration';exitCode=$attached.exitCode})}

$result.status='available-with-permission-limits'
Write-Result
