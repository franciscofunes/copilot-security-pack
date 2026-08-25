Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$normalizer = Join-Path $repoRoot 'pack/.security/scripts/normalize-findings.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copilot-security-pack-normalize-' + [guid]::NewGuid().ToString('N'))
$output = Join-Path $tempRoot '.security/output'

try {
    New-Item -ItemType Directory -Force -Path $output | Out-Null

    $nugetReport = [pscustomobject]@{
        schema = 1
        scanner = 'nuget'
        reports = @(
            [pscustomobject]@{
                target = 'App.sln'
                sdkVersion = '10.0.100'
                exitCode = 0
                parseError = $null
                stderr = ''
                report = [pscustomobject]@{
                    version = 1
                    projects = @(
                        [pscustomobject]@{
                            path = 'src/Api/Api.csproj'
                            frameworks = @(
                                [pscustomobject]@{
                                    framework = 'net10.0'
                                    topLevelPackages = @(
                                        [pscustomobject]@{
                                            id = 'Direct.Vulnerable'
                                            resolvedVersion = '1.2.3'
                                            vulnerabilities = @(
                                                [pscustomobject]@{ severity='High'; advisoryurl='https://github.com/advisories/GHSA-abcd-1234-efgh' }
                                            )
                                        }
                                    )
                                    transitivePackages = @(
                                        [pscustomobject]@{
                                            id = 'Transitive.Vulnerable'
                                            resolvedVersion = '4.5.6'
                                            vulnerabilities = @(
                                                [pscustomobject]@{ severity='Moderate'; advisoryurl='https://github.com/advisories/GHSA-wxyz-5678-ijkl' }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }
        )
    }
    $nugetReport | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $output 'nuget-vulnerabilities.json')

    $modernAudit = [pscustomobject]@{
        vulnerabilities = [pscustomobject]@{
            lodash = [pscustomobject]@{
                name = 'lodash'
                severity = 'high'
                isDirect = $true
                range = '<4.17.21'
                nodes = @('node_modules/lodash')
                via = @(
                    [pscustomobject]@{
                        source = 1065
                        title = 'Prototype Pollution'
                        url = 'https://github.com/advisories/GHSA-35jh-r3h4-6jhm'
                        severity = 'high'
                        range = '<4.17.21'
                    }
                )
            }
        }
    }

    $classicEvent = [pscustomobject]@{
        type = 'auditAdvisory'
        data = [pscustomobject]@{
            advisory = [pscustomobject]@{
                id = 9999
                module_name = 'minimist'
                severity = 'critical'
                title = 'Prototype Pollution'
                url = 'https://github.com/advisories/GHSA-vh95-rmgr-6w4m'
                vulnerable_versions = '<1.2.8'
                patched_versions = '>=1.2.8'
                findings = @(
                    [pscustomobject]@{ version='1.2.5'; paths=@('app>tool>minimist'); dev=$false }
                )
            }
        }
    }

    $yarnReport = [pscustomobject]@{
        schema = 1
        scanner = 'yarn'
        reports = @(
            [pscustomobject]@{
                workspaceRoot = 'src/Web'
                generation = 'modern'
                yarnVersion = '4.5.0'
                installExitCode = 0
                auditExitCode = 1
                scanStatus = 'completed'
                stdout = ($modernAudit | ConvertTo-Json -Depth 20 -Compress)
                stderr = ''
            },
            [pscustomobject]@{
                workspaceRoot = 'src/LegacyWeb'
                generation = 'classic'
                yarnVersion = '1.22.22'
                installExitCode = 0
                auditExitCode = 16
                scanStatus = 'completed'
                stdout = ($classicEvent | ConvertTo-Json -Depth 20 -Compress)
                stderr = ''
            }
        )
    }
    $yarnReport | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $output 'yarn-vulnerabilities.json')

    @{ schema=1; generatedAt=$null; findings=@() } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $tempRoot '.security/dependency-baseline.json')

    & $normalizer -RepositoryRoot $tempRoot -Mode Dependencies
    $summaryPath = Join-Path $output 'findings-summary.json'
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json

    Assert-True ($summary.schema -eq 2) 'normalized schema should be 2'
    Assert-True ($summary.summary.total -eq 4) "expected four normalized advisories, got $($summary.summary.total)"
    Assert-True ($summary.summary.high -eq 2) 'expected two high findings'
    Assert-True ($summary.summary.moderate -eq 1) 'expected one moderate finding'
    Assert-True ($summary.summary.critical -eq 1) 'expected one critical finding'
    Assert-True ($summary.summary.new -eq 4) 'first normalization should mark all findings new'

    $direct = @($summary.findings | Where-Object id -eq 'GHSA-ABCD-1234-EFGH')[0]
    $transitive = @($summary.findings | Where-Object id -eq 'GHSA-WXYZ-5678-IJKL')[0]
    Assert-True ($direct.direct -eq $true) 'top-level NuGet package should be direct'
    Assert-True ($transitive.direct -eq $false) 'transitive NuGet package should be transitive'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$direct.fingerprint)) 'finding fingerprint should be populated'

    $baseline = [pscustomobject]@{
        schema = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        findings = @([pscustomobject]@{ fingerprint=$direct.fingerprint; id=$direct.id; package=$direct.package })
    }
    $baseline | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $tempRoot '.security/dependency-baseline.json')

    & $normalizer -RepositoryRoot $tempRoot -Mode Dependencies
    $second = Get-Content $summaryPath -Raw | ConvertFrom-Json
    $sameDirect = @($second.findings | Where-Object id -eq 'GHSA-ABCD-1234-EFGH')[0]
    Assert-True ($sameDirect.fingerprint -eq $direct.fingerprint) 'fingerprint changed across identical evidence'
    Assert-True ($sameDirect.status -eq 'existing') 'baselined finding should become existing'
    Assert-True ($second.summary.existing -eq 1) 'expected exactly one existing finding after baseline'
    Assert-True ($second.summary.new -eq 3) 'expected remaining findings to stay new'

    Write-Host 'Dependency normalization tests passed.'
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
