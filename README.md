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
- Deterministic NuGet/Yarn scanning and normalized findings.
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

## Distribution model

Do not manually copy/paste the pack into each application repository.

The intended lifecycle is:

```text
Canonical repository
      |
      | semantic-versioned release
      v
Versioned installer
      |
      v
Self-contained application repository
```

Project-local installation remains the IDE-compatible baseline. Reusable agents and skills can additionally be packaged as a native Copilot plugin for Copilot hosts that support plugin installation.

See **[Distribution and Release Guide](docs/DISTRIBUTION_AND_RELEASES.md)** for:

- Project-local versus plugin distribution.
- Recommended installer and upgrade flow.
- Semantic versioning and release tags.
- Plugin repository installation.
- Declarative plugin enablement.
- Plugin marketplaces.
- Skills-only distribution.
- Rollback and supply-chain guidance.

## Pilot flow

1. Validate this v1 against one representative .NET + Angular/Yarn monorepo.
2. Adapt the generated pack to the repository's real SDK, Yarn generation, CI, and package feeds.
3. Validate noise, false positives, scanner runtime, and developer UX.
4. Harden scanner normalization and CI gating.
5. Build the versioned installer and upgrade flow.
6. Tag the first stable release.
7. Roll out through reviewable repository changes rather than manual copy/paste.

See [BOOTSTRAP_PROMPT.md](BOOTSTRAP_PROMPT.md) for the one-time bootstrap workflow used during the pilot stage.

## Current status

**v1 development / pilot stage.** Do not treat a passing scan as proof that an application is vulnerability-free.
