# Changelog

All notable changes to the Copilot Security Pack are documented here.

The project follows semantic versioning once stable releases begin.

## [Unreleased]

### Planned

- Versioned `install.ps1` and `upgrade.ps1` flows.
- Repository fixture/evaluation tests.
- Hardened NuGet and Yarn finding normalization.
- Stable vulnerability fingerprints and baseline comparison.
- Optional approved scanner adapters.
- Pilot validation against a representative .NET + Angular/Yarn monorepo.

## [0.1.0-alpha.1] - 2026-08-24

First architecture preview for VS Code GitHub Copilot Chat.

### Added

- Repository-native Copilot security pack scaffold.
- Security Reviewer custom agent.
- .NET, Angular/Yarn, and cross-stack security skills.
- Reusable security prompt files.
- Path-specific Copilot security instructions.
- Single PowerShell security dispatcher.
- Initial NuGet direct/transitive and Yarn vulnerability scanning.
- Changed-file security review with PR-aware merge-base comparison.
- Security policy, baseline, and exception scaffolding.
- CI security-gate template.
- Distribution and release guidance for VS Code Copilot extension-only usage.
- Public design-reference guide based on mature Copilot/agent-skill repositories.

### Fixed

- GitHub Actions PR scans no longer depend on `HEAD~1`.
- Missing Yarn audit output no longer causes findings normalization to fail.

### Known limitations

- Installer and upgrade scripts are not implemented yet.
- NuGet/Yarn normalized findings are still preliminary.
- No fixture/evaluation suite yet.
- Not yet validated against a representative production-style monorepo.
