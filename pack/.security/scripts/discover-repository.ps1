param([Parameter(Mandatory)][string]$RepositoryRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$solutions = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Include *.sln,*.slnx -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$projects = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Include *.csproj -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$angularJson = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Filter angular.json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$yarnLocks = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Filter yarn.lock -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$packageJson = @(Get-ChildItem -Path $RepositoryRoot -Recurse -File -Filter package.json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

$yarnVersion = $null
try { $yarnVersion = (& yarn --version 2>$null | Select-Object -First 1) } catch {}

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
