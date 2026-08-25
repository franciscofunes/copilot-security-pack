# Copilot Security Pack

Repository-native GitHub Copilot security pack for **.NET API + Angular/Yarn monorepos**.

## What this is

This repository is the canonical source/template for a security capability installed into application repositories. It is not an MCP-dependent scanner and it is not initially a marketplace plugin.

The pack combines:

- GitHub Copilot repository instructions.
- Path-specific .NET and Angular security instructions.
- A Security Reviewer custom agent.
- On-demand .NET, Angular, and cross-stack security skills.
- Reusable Copilot prompt commands.
- One PowerShell security dispatcher.
- Deterministic NuGet/Yarn scanning and normalised findings.
- CI security-gate templates.
- Existing-vulnerability baselines and explicit exceptions.

## Developer UX

In Copilot Chat:

- `/security-review-changes`
- `/security-review-dependencies`
- `/security-review-flow`
- `/security-investigate-finding`
- `/security-fix-finding`
- `/security-full-audit`

Copilot runs the repository dispatcher itself. Developers do **not** need to learn individual scanner commands.

Stable automation entry point:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes
```

## Security model

```text
Developer / CI
     |
     v
Copilot prompts + Security Reviewer
     |
     v
.security/run-security.ps1
     |
     +--> NuGet / .NET checks
     +--> Yarn / Angular checks
     +--> optional approved scanners
     |
     v
Normalized findings
     |
     +--> Copilot triage / cross-stack reasoning / remediation
     +--> CI policy gate
```

For privileged flows, the cross-stack skill traces Angular component -> service -> HTTP request -> .NET endpoint -> authentication -> authorization -> tenant/object ownership -> database query -> response DTO.

A UI route guard is never treated as a replacement for API authorization.

## Rollout

1. Pilot this v1 against one representative company monorepo.
2. Adapt the generated pack to the repository's real SDK, Yarn generation, CI and private feeds.
3. Validate noise, false positives and developer UX.
4. Harden scanner normalization and CI gating.
5. Version the pack and roll it out repository-by-repository.

See [BOOTSTRAP_PROMPT.md](BOOTSTRAP_PROMPT.md) for the one-time installation prompt.

## Current status

**v1 development / pilot stage.** Do not treat a passing scan as proof that an application is vulnerability-free.
