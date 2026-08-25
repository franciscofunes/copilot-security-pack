# Changelog

All notable changes to the Copilot Security Pack are documented here.

The project follows semantic versioning once stable releases begin.

## [Unreleased]

### Added

- Versioned, non-destructive installer development for v0.2.0.
- `installer/install.ps1` with .NET/Angular/Yarn feature detection and `-WhatIf` support.
- `installer/upgrade.ps1` with installed-version checks and downgrade protection.
- Installer ownership model that preserves repository-owned security policy, baselines, exceptions, and existing `copilot-instructions.md`.
- Target `.security/copilot-pack.yml` installation metadata.
- Installer idempotency smoke test and GitHub Actions workflow.

### Planned

- Managed-file checksum tracking and local-edit conflict detection.
- Safe uninstall/rollback behavior.
- .NET-only and Angular-only installation fixtures.
- Dedicated `pack/` source layout after the installer contract stabilizes.

## [0.1.0-alpha.1] - 2026-08-24

### Added

- Repository-native Copilot security pack scaffold.
- Security Reviewer custom agent.
- .NET, Angular/Yarn, and cross-stack security skills.
- Reusable security prompt files.
- Single PowerShell security dispatcher.
- Initial NuGet and Yarn vulnerability scanning.
- Security policy, baseline, and exception scaffolding.
- CI security-gate template.
- VS Code-only distribution and release guidance.
- Public design-reference guide.

### Fixed

- Changed-file detection now works in GitHub Actions PR checkouts and compares against the PR base merge-base.
- Missing Yarn scanner output no longer causes normalization to fail.

### Known limitations

- Installer and upgrade flow are not included in this release.
- NuGet/Yarn finding normalization is preliminary.
- Stable vulnerability fingerprints and baseline comparison are not yet implemented.
- Fixture/evaluation suite is not yet implemented.
- The pack has not yet been validated against a production-style .NET + Angular/Yarn monorepo.

### Planned before v1.0.0

- Hardened NuGet and Yarn finding normalization.
- Stable vulnerability fingerprints and baseline comparison.
- Versioned installation and upgrade flows.
- Fixture repositories and automated pack tests.
- Optional approved scanner adapters.
- Pilot validation against a representative .NET + Angular/Yarn monorepo.
