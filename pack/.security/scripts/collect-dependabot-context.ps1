param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [string]$GitHubCommand = 'gh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandAvailable([string]$Command) {
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Invoke-Gh {
    param(
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [switch]$Json
    )
    $previousExit = $global:LASTEXITCODE
    try {
        Push-Location $WorkingDirectory
        try {
            $raw = & $GitHubCommand @Arguments 2>$null
            $exitCode = $LASTEXITCODE
        }
        finally { Pop-Location }
        $text = ($raw -join "`n").Trim()
        $data = $null
        $ok = $exitCode -eq 0
        $parseError = $false
        if ($ok -and $Json -and -not [string]::IsNullOrWhiteSpace($text)) {
            try { $data = $text | ConvertFrom-Json }
            catch { $ok = $false; $parseError = $true }
        }
        elseif ($ok -and -not $Json) { $data = $text }
        return [pscustomobject]@{ ok=$ok; exitCode=$exitCode; parseError=$parseError; data=$data }
    }
    catch {
        return [pscustomobject]@{ ok=$false; exitCode=$null; parseError=$false; data=$null }
    }
    finally { $global:LASTEXITCODE = $previousExit }
}

function Get-PropertyValue {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Convert-SafeText {
    param($Value,[int]$MaxLength=300)
    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    $text = [regex]::Replace($text, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '')
    $text = [regex]::Replace($text, '[\r\n\t]+', ' ')
    $text = $text.Trim()
    if ($text.Length -gt $MaxLength) { return $text.Substring(0,$MaxLength) + '…' }
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
    } catch {}
    return ($text -split '[?#]',2)[0]
}

function Get-RepoRelativeDirectory([string]$Path) {
    $normalized = $Path -replace '\\','/'
    $dir = [System.IO.Path]::GetDirectoryName($normalized) -replace '\\','/'
    if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { return '/' }
    return '/' + $dir.Trim('/')
}

function Get-DetectedEcosystems([string]$Root) {
    $tracked = @((git -C $Root ls-files 2>$null) | ForEach-Object { $_ -replace '\\','/' })
    $nugetFiles = @($tracked | Where-Object { $_ -match '(^|/)(Directory\.Packages\.props|[^/]+\.csproj)$' })
    $yarnLocks = @($tracked | Where-Object { $_ -match '(^|/)yarn\.lock$' })
    $packageJson = @($tracked | Where-Object { $_ -match '(^|/)package\.json$' })
    $workflowFiles = @($tracked | Where-Object { $_ -match '^\.github/workflows/[^/]+\.ya?ml$' })
    $dockerFiles = @($tracked | Where-Object { $_ -match '(^|/)(Dockerfile|Dockerfile\.[^/]+)$' })

    $items = @()
    if ($nugetFiles.Count -gt 0) {
        $dirs = @($nugetFiles | ForEach-Object { Get-RepoRelativeDirectory $_ } | Select-Object -Unique | Select-Object -First 20)
        $items += [pscustomobject]@{ packageEcosystem='nuget'; directories=$dirs; reason='Detected tracked .NET package/project files.' }
    }
    if ($yarnLocks.Count -gt 0 -or $packageJson.Count -gt 0) {
        $source = $(if ($yarnLocks.Count -gt 0) { $yarnLocks } else { $packageJson })
        $dirs = @($source | ForEach-Object { Get-RepoRelativeDirectory $_ } | Select-Object -Unique | Select-Object -First 20)
        $items += [pscustomobject]@{ packageEcosystem='npm'; directories=$dirs; reason='Detected Yarn/npm package metadata. Dependabot uses package-ecosystem npm for npm, Yarn, and pnpm projects.' }
    }
    if ($workflowFiles.Count -gt 0) {
        $items += [pscustomobject]@{ packageEcosystem='github-actions'; directories=@('/'); reason='Detected GitHub Actions workflow files.' }
    }
    if ($dockerFiles.Count -gt 0) {
        $dirs = @($dockerFiles | ForEach-Object { Get-RepoRelativeDirectory $_ } | Select-Object -Unique | Select-Object -First 20)
        $items += [pscustomobject]@{ packageEcosystem='docker'; directories=$dirs; reason='Detected Dockerfiles.' }
    }
    return @($items)
}

function Convert-DependabotAlert($Alert) {
    $dependency = Get-PropertyValue $Alert 'dependency'
    $package = Get-PropertyValue $dependency 'package'
    $advisory = Get-PropertyValue $Alert 'security_advisory'
    $vulnerability = Get-PropertyValue $Alert 'security_vulnerability'
    $patched = Get-PropertyValue $vulnerability 'first_patched_version'
    return [pscustomobject]@{
        number = Get-PropertyValue $Alert 'number'
        state = Convert-SafeText (Get-PropertyValue $Alert 'state') 40
        ecosystem = Convert-SafeText (Get-PropertyValue $package 'ecosystem') 80
        package = Convert-SafeText (Get-PropertyValue $package 'name') 200
        manifestPath = Convert-SafeText (Get-PropertyValue $dependency 'manifest_path') 400
        scope = Convert-SafeText (Get-PropertyValue $dependency 'scope') 40
        relationship = Convert-SafeText (Get-PropertyValue $dependency 'relationship') 40
        severity = Convert-SafeText (Get-PropertyValue $advisory 'severity') 40
        ghsaId = Convert-SafeText (Get-PropertyValue $advisory 'ghsa_id') 80
        cveId = Convert-SafeText (Get-PropertyValue $advisory 'cve_id') 80
        summary = Convert-SafeText (Get-PropertyValue $advisory 'summary') 300
        vulnerableRange = Convert-SafeText (Get-PropertyValue $vulnerability 'vulnerable_version_range') 200
        firstPatchedVersion = Convert-SafeText (Get-PropertyValue $patched 'identifier') 100
        htmlUrl = Convert-SafeUrl (Get-PropertyValue $Alert 'html_url')
    }
}

$root = (Resolve-Path $RepositoryRoot).Path
$output = Join-Path $root '.security/output'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$configPath = Join-Path $root '.github/dependabot.yml'
$configExists = Test-Path $configPath
$configStatus = 'missing'
if ($configExists) {
    $configText = Get-Content $configPath -Raw
    $hasVersion = $configText -match '(?m)^\s*version\s*:\s*2\s*$'
    $hasUpdates = $configText -match '(?m)^\s*updates\s*:'
    $hasEcosystem = $configText -match '(?m)^\s*-?\s*package-ecosystem\s*:'
    $hasSchedule = $configText -match '(?m)^\s*interval\s*:'
    $configStatus = $(if ($hasVersion -and $hasUpdates -and $hasEcosystem -and $hasSchedule) { 'present-basic-valid' } else { 'present-needs-review' })
}
$detectedEcosystems = Get-DetectedEcosystems $root

$result = [ordered]@{
    schema = 1
    collectedAt = (Get-Date).ToUniversalTime().ToString('o')
    evidenceTrust = 'untrusted-external-content'
    githubCli = [ordered]@{ status='unavailable'; authenticated=$false }
    repository = [ordered]@{ status='unknown'; nameWithOwner=$null; owner=$null; ownerType=$null; private=$null; url=$null; admin=$null }
    configuration = [ordered]@{
        path = '.github/dependabot.yml'
        exists = $configExists
        status = $configStatus
        recommendation = $(if ($configExists) { $null } else { 'Configure .github/dependabot.yml for the detected package ecosystems. Do not confuse missing version-update configuration with disabled Dependabot alerts.' })
        detectedEcosystems = $detectedEcosystems
    }
    alerts = [ordered]@{ status='not-queried'; totalOpen=0; sampled=0; truncated=$false; severityCounts=[ordered]@{critical=0;high=0;medium=0;low=0;unknown=0}; items=@(); errors=@() }
    securityUpdates = [ordered]@{ status='not-queried'; enabled=$null; paused=$null }
    organization = [ordered]@{ status='not-applicable'; name=$null; alertsApiVisible=$null; repositoryAccess=$null; currentRepositoryExplicitlyAccessible=$null; errors=@() }
}

if (-not (Test-CommandAvailable $GitHubCommand)) {
    $result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $output 'dependabot-context.json')
    $result
    exit 0
}

$auth = Invoke-Gh -Arguments @('auth','status') -WorkingDirectory $root
if (-not $auth.ok) {
    $result.githubCli.status = 'not-authenticated'
    $result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $output 'dependabot-context.json')
    $result
    exit 0
}
$result.githubCli.status = 'available'
$result.githubCli.authenticated = $true

$repoView = Invoke-Gh -Arguments @('repo','view','--json','nameWithOwner,isPrivate,url') -WorkingDirectory $root -Json
if (-not $repoView.ok -or $null -eq $repoView.data) {
    $result.repository.status = 'query-failed'
    $result.alerts.status = 'repository-unresolved'
    $result.securityUpdates.status = 'repository-unresolved'
    $result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $output 'dependabot-context.json')
    $result
    exit 0
}

$fullName = [string](Get-PropertyValue $repoView.data 'nameWithOwner')
$parts = $fullName -split '/',2
$owner = $(if ($parts.Count -eq 2) { $parts[0] } else { $null })
$result.repository.status = 'available'
$result.repository.nameWithOwner = Convert-SafeText $fullName 300
$result.repository.owner = Convert-SafeText $owner 200
$result.repository.private = Get-PropertyValue $repoView.data 'isPrivate'
$result.repository.url = Convert-SafeUrl (Get-PropertyValue $repoView.data 'url')

$repoMetadata = Invoke-Gh -Arguments @('api',"repos/$fullName",'-H','X-GitHub-Api-Version: 2026-03-10') -WorkingDirectory $root -Json
if ($repoMetadata.ok) {
    $permissions = Get-PropertyValue $repoMetadata.data 'permissions'
    $result.repository.admin = Get-PropertyValue $permissions 'admin'
}

if ($owner) {
    $ownerResult = Invoke-Gh -Arguments @('api',"users/$owner",'-H','X-GitHub-Api-Version: 2026-03-10') -WorkingDirectory $root -Json
    if ($ownerResult.ok) { $result.repository.ownerType = Convert-SafeText (Get-PropertyValue $ownerResult.data 'type') 40 }
}

$alertsResult = Invoke-Gh -Arguments @('api',"repos/$fullName/dependabot/alerts?state=open&per_page=100",'--paginate','--slurp','-H','X-GitHub-Api-Version: 2026-03-10') -WorkingDirectory $root -Json
if ($alertsResult.ok) {
    $allAlerts = @()
    foreach ($page in @($alertsResult.data)) { $allAlerts += @($page) }
    $normalized = @($allAlerts | ForEach-Object { Convert-DependabotAlert $_ })
    $ordered = @($normalized | Sort-Object @{Expression={ switch ($_.severity) { 'critical' {0}; 'high' {1}; 'medium' {2}; 'low' {3}; default {4} } }}, package)
    $result.alerts.status = 'available'
    $result.alerts.totalOpen = $normalized.Count
    foreach ($item in $normalized) {
        $severity = ([string]$item.severity).ToLowerInvariant()
        if ($severity -in @('critical','high','medium','low')) { $result.alerts.severityCounts[$severity]++ } else { $result.alerts.severityCounts.unknown++ }
    }
    $result.alerts.items = @($ordered | Select-Object -First 50)
    $result.alerts.sampled = $result.alerts.items.Count
    $result.alerts.truncated = $normalized.Count -gt 50
} else {
    $result.alerts.status = 'unavailable-or-not-enabled'
    $result.alerts.errors += @([pscustomobject]@{ operation='repository-alerts'; exitCode=$alertsResult.exitCode; parseError=$alertsResult.parseError })
}

$updatesResult = Invoke-Gh -Arguments @('api',"repos/$fullName/automated-security-fixes",'-H','X-GitHub-Api-Version: 2026-03-10') -WorkingDirectory $root -Json
if ($updatesResult.ok) {
    $result.securityUpdates.status = 'available'
    $result.securityUpdates.enabled = [bool](Get-PropertyValue $updatesResult.data 'enabled')
    $result.securityUpdates.paused = [bool](Get-PropertyValue $updatesResult.data 'paused')
} else {
    $result.securityUpdates.status = $(if ($result.repository.admin -eq $true) { 'disabled' } else { 'unknown-or-no-admin-read' })
}

if ($result.repository.ownerType -eq 'Organization' -and $owner) {
    $result.organization.status = 'querying'
    $result.organization.name = Convert-SafeText $owner 200
    $orgAlerts = Invoke-Gh -Arguments @('api',"orgs/$owner/dependabot/alerts?state=open&per_page=1",'-H','X-GitHub-Api-Version: 2026-03-10') -WorkingDirectory $root -Json
    $result.organization.alertsApiVisible = $orgAlerts.ok
    if (-not $orgAlerts.ok) { $result.organization.errors += @([pscustomobject]@{ operation='organization-alerts'; exitCode=$orgAlerts.exitCode }) }

    $accessResult = Invoke-Gh -Arguments @('api',"orgs/$owner/dependabot/repository-access?per_page=100",'--paginate','--slurp','-H','X-GitHub-Api-Version: 2026-03-10') -WorkingDirectory $root -Json
    if ($accessResult.ok) {
        $pages = @($accessResult.data)
        $defaultLevel = $null
        $accessible = @()
        foreach ($page in $pages) {
            if ($null -eq $defaultLevel) { $defaultLevel = Get-PropertyValue $page 'default_level' }
            $accessible += @((Get-PropertyValue $page 'accessible_repositories'))
        }
        $names = @($accessible | ForEach-Object { Convert-SafeText (Get-PropertyValue $_ 'full_name') 300 } | Where-Object { $_ })
        $result.organization.repositoryAccess = [ordered]@{ status='available'; defaultLevel=Convert-SafeText $defaultLevel 40; accessibleRepositoryCount=$names.Count }
        $result.organization.currentRepositoryExplicitlyAccessible = $names -contains $fullName
    } else {
        $result.organization.repositoryAccess = [ordered]@{ status='unavailable-or-no-org-admin'; defaultLevel=$null; accessibleRepositoryCount=$null }
        $result.organization.errors += @([pscustomobject]@{ operation='organization-repository-access'; exitCode=$accessResult.exitCode })
    }
    $result.organization.status = 'available-with-permission-limits'
}

$path = Join-Path $output 'dependabot-context.json'
$result | ConvertTo-Json -Depth 12 | Set-Content $path
$result
