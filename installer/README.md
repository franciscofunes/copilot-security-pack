# Installer

The installer is the distribution mechanism for the **VS Code GitHub Copilot Security Pack**. It does not require Copilot CLI, MCP, a marketplace, or Git submodules.

The installer copies only from the canonical `pack/` payload. Root `.github/` and `.security/` belong to this source repository and are not distribution input.

## First installation

Preview:

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

The installer detects:

- .NET projects/solutions.
- Angular/Yarn workspaces.
- Combined .NET + Angular/Yarn monorepos.

Only applicable skills, path instructions, scanners, and cross-stack assets are installed.

## Ownership model

### Pack-managed

Examples:

```text
.github/agents/security-reviewer.agent.md
.github/prompts/security-*.prompt.md
.github/skills/security-*/**
.github/instructions/security-*.instructions.md
.security/run-security.ps1
.security/scripts/**
```

Pack-managed files are recorded with SHA-256 values in:

```text
.security/copilot-pack-state.json
```

### Repository-owned

These are never blindly replaced:

```text
.github/copilot-instructions.md        # when it existed before installation
.security/security-policy.yml
.security/dependency-baseline.json
.security/dependency-exceptions.yml
CI workflows
```

If `.github/copilot-instructions.md` already exists, the security pack leaves it untouched and installs its global security rules at:

```text
.github/instructions/security-pack-global.instructions.md
```

## Upgrade

```powershell
pwsh -NoProfile -File ./installer/upgrade.ps1 `
  -TargetRepo C:\src\my-application
```

Upgrade refuses:

- Accidental downgrade unless explicitly allowed.
- Overwriting a pack-managed file that was edited locally.
- Overwriting a pre-existing target file whose ownership is unknown.

After human review, an intentional managed-file replacement can be requested with the installer/upgrade `-ForceManagedOverwrite` option. Do not use that switch as routine upgrade behavior.

## Uninstall

```powershell
pwsh -NoProfile -File ./installer/uninstall.ps1 `
  -TargetRepo C:\src\my-application
```

Uninstall removes unchanged pack-managed files. Locally modified managed files and repository-owned policy/baseline/exception files are preserved.

## Target metadata

Each installation records detected features and version in:

```text
.security/copilot-pack.yml
```

Managed-file ownership/checksums are stored separately in:

```text
.security/copilot-pack-state.json
```

## First-adoption dependency baseline

Do **not** manually copy current findings into the baseline.

From VS Code Copilot Chat use:

```text
/security-initialize-baseline
```

The workflow first runs dependency scanning, shows exactly which findings would become legacy baseline entries, checks that scanners succeeded, and requests explicit approval.

The underlying confirmed dispatcher operation is:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 `
  -Mode InitializeBaseline `
  -ConfirmBaseline
```

The baseline initializer refuses to:

- Run without explicit confirmation.
- Baseline partial results when a deterministic scanner failed.
- Replace an already established non-empty baseline.

After initialization, matching fingerprints become `existing`; vulnerabilities introduced later remain `new` and are subject to policy gating.

## Required review step

Installation, upgrade, and uninstall intentionally do not commit or push changes. Always inspect the target repository Git diff before committing the resulting changes.
