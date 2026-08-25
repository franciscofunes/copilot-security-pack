# Copilot Security Pack

Repository-native GitHub Copilot security pack for .NET API + Angular/Yarn monorepos.

## Goals

- One-command developer security review from Copilot Chat.
- Deterministic scanners first; AI reasoning second.
- Direct + transitive NuGet and Yarn dependency vulnerability scanning.
- Cross-stack authorization review between Angular UI and .NET APIs.
- Minimal developer effort and compact Copilot context usage.
- CI enforcement even if developers never run the local review.
- MCP optional and disabled by default.

## Core developer commands

- `/security-review-changes`
- `/security-review-dependencies`
- `/security-review-flow`
- `/security-investigate-finding`
- `/security-fix-finding`
- `/security-full-audit`

## Architecture

The pack is installed into each application repository. The stable runtime contract is:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes
```

Copilot prompt files and agents call the dispatcher automatically. CI calls the same dispatcher.

## Status

Initial v1 implementation. Pilot against one representative company monorepo before broad rollout.
