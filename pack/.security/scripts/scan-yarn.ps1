param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Profile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CommandCapture {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $psi.ArgumentList.Add($argument) }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    [pscustomobject]@{
        exitCode = $process.ExitCode
        stdout = $stdout
        stderr = $stderr
    }
}

function Get-YarnGeneration {
    param([Parameter(Mandatory)][string]$WorkspaceRoot)

    $packageJsonPath = Join-Path $WorkspaceRoot 'package.json'
    if (Test-Path $packageJsonPath) {
        try {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            $packageManager = [string]$packageJson.packageManager
            $match = [regex]::Match($packageManager, '^yarn@(\d+)')
            if ($match.Success) {
                $major = [int]$match.Groups[1].Value
                return [pscustomobject]@{ generation = $(if ($major -ge 2) { 'modern' } else { 'classic' }); version = $packageManager.Substring(5) }
            }
        } catch {}
    }

    if (Test-Path (Join-Path $WorkspaceRoot '.yarnrc.yml')) {
        return [pscustomobject]@{ generation = 'modern'; version = $null }
    }
    if (Test-Path (Join-Path $WorkspaceRoot '.yarnrc')) {
        return [pscustomobject]@{ generation = 'classic'; version = $null }
    }

    $versionText = [string]$Profile.angular.yarnVersion
    $match = [regex]::Match($versionText, '^(\d+)')
    if ($match.Success) {
        $major = [int]$match.Groups[1].Value
        return [pscustomobject]@{ generation = $(if ($major -ge 2) { 'modern' } else { 'classic' }); version = $versionText }
    }

    return [pscustomobject]@{ generation = 'unknown'; version = $versionText }
}

$outputDir = Join-Path $RepositoryRoot '.security/output'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$output = Join-Path $outputDir 'yarn-vulnerabilities.json'

$reports = @()
foreach ($lock in @($Profile.angular.yarnLocks)) {
    $workspaceRoot = Split-Path $lock -Parent
    $yarn = Get-YarnGeneration -WorkspaceRoot $workspaceRoot

    if ($yarn.generation -eq 'unknown') {
        $reports += [pscustomobject]@{
            workspaceRoot = $workspaceRoot
            generation = 'unknown'
            yarnVersion = $yarn.version
            installExitCode = $null
            auditExitCode = $null
            stdout = ''
            stderr = 'Unable to determine Yarn generation.'
            scanStatus = 'error'
        }
        continue
    }

    $installArgs = if ($yarn.generation -eq 'modern') { @('install','--immutable') } else { @('install','--frozen-lockfile') }
    $install = Invoke-CommandCapture -FileName 'yarn' -Arguments $installArgs -WorkingDirectory $workspaceRoot

    if ($install.exitCode -ne 0) {
        $reports += [pscustomobject]@{
            workspaceRoot = $workspaceRoot
            generation = $yarn.generation
            yarnVersion = $yarn.version
            installExitCode = $install.exitCode
            auditExitCode = $null
            stdout = ''
            stderr = ($install.stderr + "`n" + $install.stdout).Trim()
            scanStatus = 'error'
        }
        continue
    }

    $auditArgs = if ($yarn.generation -eq 'modern') {
        @('npm','audit','--all','--recursive','--json')
    } else {
        @('audit','--json')
    }

    $audit = Invoke-CommandCapture -FileName 'yarn' -Arguments $auditArgs -WorkingDirectory $workspaceRoot
    $reports += [pscustomobject]@{
        workspaceRoot = $workspaceRoot
        generation = $yarn.generation
        yarnVersion = $yarn.version
        installExitCode = $install.exitCode
        auditExitCode = $audit.exitCode
        stdout = $audit.stdout
        stderr = $audit.stderr.Trim()
        scanStatus = 'completed'
    }
}

[pscustomobject]@{
    schema = 1
    scanner = 'yarn'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    reports = $reports
} | ConvertTo-Json -Depth 20 | Set-Content $output
