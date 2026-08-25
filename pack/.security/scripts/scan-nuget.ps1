param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Profile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-DotnetCapture {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'dotnet'
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

$outputDir = Join-Path $RepositoryRoot '.security/output'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$output = Join-Path $outputDir 'nuget-vulnerabilities.json'

$sdkVersion = (& dotnet --version | Select-Object -First 1).Trim()
$majorMatch = [regex]::Match($sdkVersion, '^(\d+)')
if (-not $majorMatch.Success) { throw "Could not determine .NET SDK major version from '$sdkVersion'." }
$major = [int]$majorMatch.Groups[1].Value

$targets = @($Profile.dotnet.solutions)
if ($targets.Count -eq 0) { $targets = @($Profile.dotnet.projects) }

$reports = @()
foreach ($target in $targets) {
    $arguments = if ($major -ge 10) {
        @('package','list',[string]$target,'--vulnerable','--include-transitive','--format','json','--output-version','1')
    } else {
        @('list',[string]$target,'package','--vulnerable','--include-transitive','--format','json','--output-version','1')
    }

    $capture = Invoke-DotnetCapture -Arguments $arguments
    $parsed = $null
    $parseError = $null
    if (-not [string]::IsNullOrWhiteSpace($capture.stdout)) {
        try { $parsed = $capture.stdout | ConvertFrom-Json }
        catch { $parseError = $_.Exception.Message }
    } else {
        $parseError = 'dotnet package list returned no JSON output.'
    }

    $reports += [pscustomobject]@{
        target = [string]$target
        sdkVersion = $sdkVersion
        command = 'dotnet ' + ($arguments -join ' ')
        exitCode = $capture.exitCode
        report = $parsed
        parseError = $parseError
        stderr = $capture.stderr.Trim()
    }
}

[pscustomobject]@{
    schema = 1
    scanner = 'nuget'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    reports = $reports
} | ConvertTo-Json -Depth 30 | Set-Content $output
