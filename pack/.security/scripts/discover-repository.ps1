param([Parameter(Mandatory)][string]$RepositoryRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CommandVersion {
    param([Parameter(Mandatory)][string]$FileName,[string[]]$Arguments = @('--version'))
    try {
        $command = Get-Command $FileName -ErrorAction Stop
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $command.Source
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        foreach ($argument in $Arguments) { $psi.ArgumentList.Add($argument) }
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $psi
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        [void]$process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -eq 0) { return ($stdout.Trim() -split "[`r`n]+" | Select-Object -First 1) }
    } catch {}
    return $null
}

$solutions = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Include *.sln,*.slnx -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$projects = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Include *.csproj -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$angularJson = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Filter angular.json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$yarnLocks = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Filter yarn.lock -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$packageJson = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Filter package.json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$yarnVersion = Get-CommandVersion -FileName 'yarn'

[pscustomobject]@{
    repositoryRoot = $RepositoryRoot
    dotnet = [pscustomobject]@{
        present = ($projects.Count -gt 0)
        solutions = $solutions
        projects = $projects
        centralPackageManagement = (Test-Path (Join-Path $RepositoryRoot 'Directory.Packages.props'))
    }
    angular = [pscustomobject]@{
        present = ($angularJson.Count -gt 0)
        angularJson = $angularJson
        packageJson = $packageJson
        yarnLocks = $yarnLocks
        yarnVersion = $yarnVersion
    }
}
