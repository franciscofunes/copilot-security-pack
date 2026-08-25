# Copilot Security Pack

Repository-native security pack for **GitHub Copilot Chat in Visual Studio Code**, targeting **.NET API + Angular/Yarn monorepos**.

## Supported host

This project is intentionally designed for the **GitHub Copilot VS Code extension**.

It does not require:

- Copilot CLI.
- A Copilot plugin marketplace.
- MCP servers.
- Git submodules.

The application repository remains self-contained after installation.

## What the pack contains

- `.github/copilot-instructions.md` for small repository-wide rules.
- `.github/instructions/*.instructions.md` for path-specific .NET and Angular rules.
- `.github/prompts/*.prompt.md` for reusable Copilot Chat commands.
- `.github/agents/*.agent.md` for the Security Reviewer custom agent.
- `.github/skills/*/SKILL.md` for progressively loaded .NET, Angular, and cross-stack security expertise.
- `.security/run-security.ps1` as the single deterministic automation entry point.
- NuGet and Yarn dependency vulnerability scanning.
- Normalized findings, policy gating, baselines, and explicit exceptions.
- CI integration templates.

GitHub and VS Code currently discover project skills from `.github/skills/<skill-name>/SKILL.md`; the skills in this repository follow that layout.

## Developer UX

Inside Copilot Chat in VS Code:

- `/security-review-changes`
- `/security-review-dependencies`
- `/security-review-flow`
- `/security-investigate-finding`
- `/security-fix-finding`
- `/security-full-audit`

Developers should not need to remember individual scanner commands. The Security Reviewer runs the repository dispatcher through VS Code's terminal tooling.

Stable automation entry point:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes
```

## Security model

```text
Developer
   |
   v
VS Code Copilot Chat
prompts + Security Reviewer Agent
   |
   +--> on-demand .NET skill
   +--> on-demand Angular skill
   +--> on-demand cross-stack skill
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
   +--> Copilot triage / authorization reasoning / minimal remediation
   +--> CI policy gate
```

For privileged flows, cross-stack review traces Angular component -> service -> HTTP request -> .NET endpoint -> authentication -> authorization -> tenant/object ownership -> database query -> response DTO.

A UI route guard is never treated as a replacement for API authorization.

## Distribution model

Do not manually copy/paste files into every application repository.

The intended lifecycle is:

```text
Canonical copilot-security-pack repository
             |
             | semantic-versioned release
             v
       install.ps1 / upgrade.ps1
             |
             v
     Application repository
             |
             v
VS Code Copilot automatically discovers
instructions + prompts + agents + skills
```

After installation, developers only clone the application repository. They do not need the canonical security-pack repository during normal development.

See **[Distribution and Release Guide](docs/DISTRIBUTION_AND_RELEASES.md)**.

## Current feature-branch structure

```text
.github/
  agents/
    security-reviewer.agent.md
  instructions/
    security-angular.instructions.md
    security-dotnet.instructions.md
  prompts/
    security-review-changes.prompt.md
    security-review-dependencies.prompt.md
    security-review-flow.prompt.md
    security-investigate-finding.prompt.md
    security-fix-finding.prompt.md
    security-full-audit.prompt.md
  skills/
    security-angular/
      SKILL.md
    security-cross-stack/
      SKILL.md
    security-dotnet/
      SKILL.md

.security/
  run-security.ps1
  scripts/
  security-policy.yml
  dependency-baseline.json
  dependency-exceptions.yml
```

If these files are not visible on GitHub, select the `feat/security-pack-v1` branch or open PR #1. They are not yet on `main` while the implementation is under review.

## Pilot flow

1. Harden the pack and installer in this repository.
2. Validate with intentionally vulnerable fixture projects.
3. Install a release candidate into one representative .NET + Angular/Yarn monorepo.
4. Validate VS Code Copilot Chat behavior, terminal approvals, SDK/Yarn compatibility, private feeds, false positives, and token/context usage.
5. Merge and tag the first stable release.
6. Roll out through `install.ps1`; later updates use `upgrade.ps1` and reviewable Git diffs.

## Current status

**v1 development / pilot stage.** A passing scan is not proof that an application is vulnerability-free.
