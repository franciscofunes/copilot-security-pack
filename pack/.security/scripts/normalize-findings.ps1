param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$Mode)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256Text([string]$Value) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

function Normalize-Severity([string]$Value) {
    switch (($Value ?? '').Trim().ToLowerInvariant()) {
        'critical' { return 'critical' }
        'high' { return 'high' }
        'moderate' { return 'moderate' }
        'medium' { return 'moderate' }
        'low' { return 'low' }
        'info' { return 'low' }
        'informational' { return 'low' }
        default { return 'unknown' }
    }
}

function Get-AdvisoryId([string]$Url, [string]$Fallback) {
    if (-not [string]::IsNullOrWhiteSpace($Url)) {
        $ghsa = [regex]::Match($Url, '(?i)GHSA-[0-9a-z]+-[0-9a-z]+-[0-9a-z]+')
        if ($ghsa.Success) { return $ghsa.Value.ToUpperInvariant() }
        $cve = [regex]::Match($Url, '(?i)CVE-\d{4}-\d{4,}')
        if ($cve.Success) { return $cve.Value.ToUpperInvariant() }
    }
    if (-not [string]::IsNullOrWhiteSpace($Fallback)) { return $Fallback }
    return 'ADVISORY-' + (Get-Sha256Text(($Url ?? 'unknown'))).Substring(0,12).ToUpperInvariant()
}

$output = Join-Path $RepositoryRoot '.security/output'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$findings = [System.Collections.Generic.List[object]]::new()

$baselineFingerprints = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$baselinePath = Join-Path $RepositoryRoot '.security/dependency-baseline.json'
if (Test-Path $baselinePath) {
    try {
        $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
        foreach ($entry in @($baseline.findings)) {
            $fingerprint = [string]$entry.fingerprint
            if (-not [string]::IsNullOrWhiteSpace($fingerprint)) { [void]$baselineFingerprints.Add($fingerprint) }
        }
    } catch {
        throw "Could not parse dependency baseline '$baselinePath': $($_.Exception.Message)"
    }
}

function Add-DependencyFinding {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Ecosystem,
        [Parameter(Mandatory)][string]$Package,
        [Parameter(Mandatory)][string]$AdvisoryId,
        [string]$Severity,
        [string]$InstalledVersion,
        [Nullable[bool]]$Direct,
        [string]$Project,
        [string]$Framework,
        [string]$Workspace,
        [string]$AdvisoryUrl,
        [string]$Title,
        [string]$VulnerableRange,
        [string]$FixedRange,
        [string]$DependencyPath
    )

    $scope = @($Project,$Framework,$Workspace,$Package,$AdvisoryId) | ForEach-Object { [string]($_ ?? '') }
    $fingerprint = Get-Sha256Text(($Source + '|' + ($scope -join '|')).ToLowerInvariant())
    $status = if ($baselineFingerprints.Contains($fingerprint)) { 'existing' } else { 'new' }

    $findings.Add([pscustomobject]@{
        id = $AdvisoryId
        fingerprint = $fingerprint
        source = $Source
        ecosystem = $Ecosystem
        category = 'dependency'
        status = $status
        severity = Normalize-Severity $Severity
        package = $Package
        installedVersion = $InstalledVersion
        direct = $Direct
        introducedBy = $null
        project = $Project
        framework = $Framework
        workspace = $Workspace
        advisoryUrl = $AdvisoryUrl
        title = $Title
        vulnerableRange = $VulnerableRange
        fixedVersion = $null
        fixedRange = $FixedRange
        dependencyPath = $DependencyPath
    }) | Out-Null
}

function Add-ScannerError {
    param([string]$Source,[string]$Area,[string]$Message)
    $fingerprint = Get-Sha256Text("scanner-error|$Source|$Area")
    $findings.Add([pscustomobject]@{
        id = ('SCANNER-' + $Source.ToUpperInvariant() + '-' + $fingerprint.Substring(0,8).ToUpperInvariant())
        fingerprint = $fingerprint
        source = $Source
        ecosystem = $Source
        category = 'scanner-error'
        status = 'needs-review'
        severity = 'unknown'
        package = $null
        installedVersion = $null
        direct = $null
        introducedBy = $null
        project = $Area
        framework = $null
        workspace = $null
        advisoryUrl = $null
        title = $Message
        vulnerableRange = $null
        fixedVersion = $null
        fixedRange = $null
        dependencyPath = $null
    }) | Out-Null
}

# NuGet output-version 1: projects -> frameworks -> topLevelPackages/transitivePackages -> vulnerabilities.
$nugetPath = Join-Path $output 'nuget-vulnerabilities.json'
if (Test-Path $nugetPath) {
    $wrapper = Get-Content $nugetPath -Raw | ConvertFrom-Json
    foreach ($scan in @($wrapper.reports)) {
        if ($null -eq $scan.report) {
            Add-ScannerError -Source 'nuget' -Area ([string]$scan.target) -Message ([string]($scan.parseError ?? $scan.stderr ?? 'NuGet scan did not produce a report.'))
            continue
        }

        foreach ($project in @($scan.report.projects)) {
            foreach ($framework in @($project.frameworks)) {
                foreach ($kind in @('topLevelPackages','transitivePackages')) {
                    $isDirect = ($kind -eq 'topLevelPackages')
                    $packages = @($framework.$kind)
                    foreach ($package in $packages) {
                        foreach ($vulnerability in @($package.vulnerabilities)) {
                            $url = [string]$vulnerability.advisoryurl
                            $advisoryId = Get-AdvisoryId -Url $url -Fallback $null
                            Add-DependencyFinding -Source 'nuget' -Ecosystem 'nuget' -Package ([string]$package.id) -AdvisoryId $advisoryId -Severity ([string]$vulnerability.severity) -InstalledVersion ([string]$package.resolvedVersion) -Direct $isDirect -Project ([string]$project.path) -Framework ([string]$framework.framework) -AdvisoryUrl $url
                        }
                    }
                }
            }
        }
    }
}

# Yarn wrapper supports modern npm audit JSON and Yarn Classic JSON-lines.
$yarnPath = Join-Path $output 'yarn-vulnerabilities.json'
if (Test-Path $yarnPath) {
    $wrapper = Get-Content $yarnPath -Raw | ConvertFrom-Json
    foreach ($scan in @($wrapper.reports)) {
        $workspace = [string]$scan.workspaceRoot
        if ([string]$scan.scanStatus -eq 'error') {
            Add-ScannerError -Source 'yarn' -Area $workspace -Message ([string]($scan.stderr ?? 'Yarn scan failed.'))
            continue
        }

        $raw = [string]$scan.stdout
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }

        if ([string]$scan.generation -eq 'modern') {
            $audit = $null
            try { $audit = $raw | ConvertFrom-Json } catch {
                # Some Yarn versions describe --json as NDJSON. Use the first object containing vulnerabilities/advisories.
                foreach ($line in @($raw -split "[`r`n]+")) {
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    try {
                        $candidate = $line | ConvertFrom-Json
                        if ($candidate.PSObject.Properties.Name -contains 'vulnerabilities' -or $candidate.PSObject.Properties.Name -contains 'advisories') { $audit = $candidate; break }
                    } catch {}
                }
            }

            if ($null -eq $audit) {
                Add-ScannerError -Source 'yarn' -Area $workspace -Message 'Modern Yarn audit output could not be parsed as JSON.'
                continue
            }

            if ($audit.PSObject.Properties.Name -contains 'vulnerabilities' -and $null -ne $audit.vulnerabilities) {
                foreach ($property in @($audit.vulnerabilities.PSObject.Properties)) {
                    $vuln = $property.Value
                    $packageName = if (-not [string]::IsNullOrWhiteSpace([string]$vuln.name)) { [string]$vuln.name } else { [string]$property.Name }
                    $objectVia = @($vuln.via | Where-Object { $_ -isnot [string] })
                    if ($objectVia.Count -eq 0) {
                        $viaRefs = @($vuln.via | ForEach-Object { [string]$_ }) -join ','
                        $fallback = 'NPM-' + (Get-Sha256Text("$packageName|$viaRefs")).Substring(0,12).ToUpperInvariant()
                        Add-DependencyFinding -Source 'yarn' -Ecosystem 'npm' -Package $packageName -AdvisoryId $fallback -Severity ([string]$vuln.severity) -Direct ([Nullable[bool]]$vuln.isDirect) -Workspace $workspace -VulnerableRange ([string]$vuln.range) -DependencyPath (@($vuln.nodes)[0])
                    } else {
                        foreach ($via in $objectVia) {
                            $url = [string]$via.url
                            $fallback = if ($null -ne $via.source) { 'NPM-' + [string]$via.source } else { $null }
                            $advisoryId = Get-AdvisoryId -Url $url -Fallback $fallback
                            Add-DependencyFinding -Source 'yarn' -Ecosystem 'npm' -Package $packageName -AdvisoryId $advisoryId -Severity ([string]($via.severity ?? $vuln.severity)) -Direct ([Nullable[bool]]$vuln.isDirect) -Workspace $workspace -AdvisoryUrl $url -Title ([string]$via.title) -VulnerableRange ([string]($via.range ?? $vuln.range)) -DependencyPath (@($vuln.nodes)[0])
                        }
                    }
                }
            } elseif ($audit.PSObject.Properties.Name -contains 'advisories' -and $null -ne $audit.advisories) {
                foreach ($property in @($audit.advisories.PSObject.Properties)) {
                    $advisory = $property.Value
                    $url = [string]$advisory.url
                    $advisoryId = Get-AdvisoryId -Url $url -Fallback ('NPM-' + [string]$property.Name)
                    Add-DependencyFinding -Source 'yarn' -Ecosystem 'npm' -Package ([string]$advisory.module_name) -AdvisoryId $advisoryId -Severity ([string]$advisory.severity) -Workspace $workspace -AdvisoryUrl $url -Title ([string]$advisory.title) -VulnerableRange ([string]$advisory.vulnerable_versions) -FixedRange ([string]$advisory.patched_versions)
                }
            }
        } else {
            foreach ($line in @($raw -split "[`r`n]+")) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $event = $null
                try { $event = $line | ConvertFrom-Json } catch { continue }
                if ([string]$event.type -ne 'auditAdvisory') { continue }

                $advisory = $event.data.advisory
                $url = [string]$advisory.url
                $fallback = if ($null -ne $advisory.id) { 'NPM-' + [string]$advisory.id } else { $null }
                $advisoryId = Get-AdvisoryId -Url $url -Fallback $fallback
                $classicFindings = @($advisory.findings)
                if ($classicFindings.Count -eq 0) {
                    Add-DependencyFinding -Source 'yarn' -Ecosystem 'npm' -Package ([string]$advisory.module_name) -AdvisoryId $advisoryId -Severity ([string]$advisory.severity) -Workspace $workspace -AdvisoryUrl $url -Title ([string]$advisory.title) -VulnerableRange ([string]$advisory.vulnerable_versions) -FixedRange ([string]$advisory.patched_versions)
                } else {
                    foreach ($classicFinding in $classicFindings) {
                        $path = @($classicFinding.paths)[0]
                        Add-DependencyFinding -Source 'yarn' -Ecosystem 'npm' -Package ([string]$advisory.module_name) -AdvisoryId $advisoryId -Severity ([string]$advisory.severity) -InstalledVersion ([string]$classicFinding.version) -Workspace $workspace -AdvisoryUrl $url -Title ([string]$advisory.title) -VulnerableRange ([string]$advisory.vulnerable_versions) -FixedRange ([string]$advisory.patched_versions) -DependencyPath ([string]$path)
                    }
                }
            }
        }
    }
}

$summary = [pscustomobject]@{
    schema = 2
    mode = $Mode
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    findings = @($findings | Sort-Object source, package, id, project, framework, workspace)
    summary = [pscustomobject]@{
        total = $findings.Count
        new = @($findings | Where-Object status -eq 'new').Count
        existing = @($findings | Where-Object status -eq 'existing').Count
        scannerErrors = @($findings | Where-Object category -eq 'scanner-error').Count
        critical = @($findings | Where-Object severity -eq 'critical').Count
        high = @($findings | Where-Object severity -eq 'high').Count
        moderate = @($findings | Where-Object severity -eq 'moderate').Count
        low = @($findings | Where-Object severity -eq 'low').Count
        unknown = @($findings | Where-Object severity -eq 'unknown').Count
    }
}
$summary | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $output 'findings-summary.json')
