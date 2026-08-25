# Installer

The installer is the distribution mechanism for the VS Code GitHub Copilot Security Pack. It does not require Copilot CLI, MCP, a marketplace, or Git submodules.

## First installation

From a clone of this repository:

```powershell
pwsh -NoProfile -File ./installer/install.ps1 -TargetRepo C:\src\my-application
```

Preview without modifying the target:

```powershell
pwsh -NoProfile -File ./installer/install.ps1 -TargetRepo C:\src\my-application -WhatIf
```

The installer detects .NET and Angular/Yarn from repository files and installs only applicable VS Code Copilot instructions, prompts, agents, skills, and deterministic security scripts.

## Ownership model

Pack-managed files are reconciled to the current pack version. Repository-owned security policy, baselines, exceptions, and existing `.github/copilot-instructions.md` are preserved.

If the target already has `.github/copilot-instructions.md`, the pack installs its global security rules separately as:

```text
.github/instructions/security-pack-global.instructions.md
```

This avoids silently rewriting application-specific Copilot instructions.

## Upgrade

```powershell
pwsh -NoProfile -File ./installer/upgrade.ps1 -TargetRepo C:\src\my-application
```

`upgrade.ps1` requires an existing `.security/copilot-pack.yml`, refuses accidental downgrades, and delegates reconciliation to the same idempotent installer.

## Target metadata

Each installation records the pack version and detected features in:

```text
.security/copilot-pack.yml
```

Review the target repository Git diff before committing installation or upgrade changes.
