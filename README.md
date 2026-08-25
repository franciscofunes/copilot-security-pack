# Copilot Security Pack

Repository-native security pack for **GitHub Copilot Chat in Visual Studio Code**, targeting **.NET API + Angular/Yarn repositories and monorepos**.

## Supported host

This project is intentionally designed for the **GitHub Copilot VS Code extension**.

It does not require Copilot CLI, a Copilot plugin marketplace, MCP servers, or Git submodules. After installation, the application repository is self-contained.

## Architecture

```text
copilot-security-pack
  pack/                  canonical distributable payload
  installer/             install / upgrade / uninstall
  tests/                 pack and normalization verification
       |
       v
application repository
  .github/
    instructions/
    prompts/
    agents/
    skills/
  .security/
    run-security.ps1
    scripts/
    security-policy.yml
    dependency-baseline.json
       |
       v
VS Code GitHub Copilot Chat + deterministic local/CI evidence
```

Root `.github/` and `.security/` configure and test this source repository. **`pack/` is the source of truth for files distributed to application repositories.**

## What the pack provides

- Small repository-wide and path-specific Copilot security instructions.
- A `Security Reviewer` custom agent.
- On-demand .NET, Angular/Yarn, and cross-stack security skills.
- Reusable prompt commands for changed-code review, dependencies, privileged flows, finding investigation/remediation, full audits, and initial baseline adoption.
- `.security/run-security.ps1` as the single automation entry point.
- Direct and transitive NuGet vulnerability evidence.
- Yarn Classic and modern Yarn audit evidence.
- Per-advisory normalized findings with stable SHA-256 fingerprints.
- Existing-vulnerability baseline support without suppressing newly introduced risk.
- CI policy gating that fails new high/critical findings and scanner failures.

## Developer UX

Inside Copilot Chat in VS Code:

```text
/security-review-changes
/security-review-dependencies
/security-review-flow
/security-investigate-finding
/security-fix-finding
/security-full-audit
/security-initialize-baseline
```

Developers should not need to learn individual scanner commands. Copilot runs the stable dispatcher itself through VS Code's terminal tooling:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes
```

Detailed scanner evidence remains under `.security/output`; chat responses should stay compact and evidence-based.

## Install

Clone or check out the desired version of this repository, then preview the target change:

```powershell
pwsh -NoProfile -File ./installer/install.ps1 `
  -TargetRepo C:\src\my-application `
  -WhatIf
```

Install:

```powershell
pwsh -NoProfile -File ./installer/install.ps1 `
  -TargetRepo C:\src\my-application
```

The installer detects .NET, Angular/Yarn, and combined repositories, installs only applicable payload files, preserves repository-owned policy/baseline/exception files, and does not blindly overwrite an existing `.github/copilot-instructions.md`.

## Upgrade safety

```powershell
pwsh -NoProfile -File ./installer/upgrade.ps1 `
  -TargetRepo C:\src\my-application
```

Managed files are tracked by SHA-256. If an installed managed file was edited locally, upgrade stops instead of overwriting it. `-ForceManagedOverwrite` exists only for an explicitly reviewed conflict.

Uninstall removes unchanged pack-managed files while preserving locally modified and repository-owned files:

```powershell
pwsh -NoProfile -File ./installer/uninstall.ps1 `
  -TargetRepo C:\src\my-application
```

See [installer/README.md](installer/README.md) and [docs/DISTRIBUTION_AND_RELEASES.md](docs/DISTRIBUTION_AND_RELEASES.md).

## Dependency adoption model

Normal dependency review:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Dependencies
```

For a repository adopting the pack for the first time, existing dependency debt can be established once through the `/security-initialize-baseline` prompt. Copilot first shows exactly what would be grandfathered and asks for explicit approval. The underlying confirmed operation is:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 `
  -Mode InitializeBaseline `
  -ConfirmBaseline
```

Safety rules:

- Scanner errors cannot be baselined.
- A non-empty baseline cannot be replaced by the initialization workflow.
- New vulnerabilities discovered after initialization remain `new`.
- New high/critical findings remain blocking.
- Baseline is legacy-debt classification, not proof that a vulnerability is acceptable.

## Security review model

```text
changed files / dependency manifests
        |
        v
deterministic scanners
        |
        v
normalized findings + fingerprints
        |
        v
Copilot validates exploitability / traces cross-stack boundaries
        |
        +--> compact findings
        +--> minimal remediation when requested
        +--> focused verification
```

For privileged flows, cross-stack review traces Angular component -> service -> HTTP request -> .NET endpoint -> authentication -> authorization -> tenant/object ownership -> database query -> response DTO. UI guards are never treated as API authorization.

## Release maturity

- `v0.1.0-alpha.1`: architecture preview.
- `v0.2.0-alpha.1`: versioned installer, canonical payload, dependency normalization, fingerprints, and guarded baseline workflow.
- Stable `v1.0.0`: only after representative real-repository/VDI validation and additional hardening.

A passing scan is evidence from the checks that ran; it is never proof that an application is vulnerability-free.
