# Installer Design

The installer is intentionally repository-native and VS Code Copilot extension-first.

## Principles

- No Copilot CLI requirement.
- No MCP requirement.
- No Git submodules.
- No manual copy/paste between releases.
- Target repositories remain self-contained after installation.
- Pack-managed files may be reconciled by upgrades.
- Repository-owned files are preserved and require explicit review for policy changes.

## Ownership

Pack-managed:

- `.github/agents/security-reviewer.agent.md`
- `.github/prompts/security-*.prompt.md`
- `.github/skills/security-*/**`
- `.github/instructions/security-dotnet.instructions.md`
- `.github/instructions/security-angular.instructions.md`
- `.security/run-security.ps1`
- `.security/scripts/**`

Repository-owned or create-if-missing:

- `.github/copilot-instructions.md`
- `.security/security-policy.yml`
- `.security/dependency-baseline.json`
- `.security/dependency-exceptions.yml`
- CI workflows

When `.github/copilot-instructions.md` already exists, the installer preserves it and installs pack-wide rules as `.github/instructions/security-pack-global.instructions.md` with `applyTo: '**'`.

## Idempotency

Running the same installer version repeatedly should result in no semantic changes when the target already matches the pack. Upgrades use the same reconciliation engine so install and upgrade behavior cannot drift.
