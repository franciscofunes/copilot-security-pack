# Changelog

All notable changes to the Copilot Security Pack are documented here.

The project follows semantic versioning once stable releases begin.

## [Unreleased]

### Added

- `v0.4.0-alpha.1` architecture/documentation hardening line.
- MIT open-source license.
- Mermaid architecture catalog covering distribution, developer review, deterministic evidence, cross-stack authorization, dependency baselines, upgrade ownership, and the blind VS Code pilot.
- Open-source design/reference policy documenting which patterns are adopted from public Copilot/agent projects and which incompatible distribution mechanisms remain excluded.
- Progressive-disclosure `references/` for .NET, Angular/Yarn, and cross-stack security skills.
- Installer manifest support for distributing skill reference files with the applicable stack feature.

### Changed

- README now uses architecture diagrams for the main distribution, review, and upgrade-safety concepts.
- Skill bodies remain compact while detailed review checklists load only when relevant.

## [0.3.0-alpha.1] - 2026-08-25

### Added

- Intentionally vulnerable .NET + Angular/Yarn monorepo fixture for repeatable security evaluation.
- Four source-review canaries covering tenant isolation, frontend-only authorization, privilege-changing mass assignment, and SSRF.
- External machine-readable evaluation rubric kept outside the pilot application workspace.
- Blind VS Code Copilot pilot protocol with a 20-point scoring rubric.
- `evaluations/prepare-pilot.ps1` for one-command blind workspace setup, pack installation, Git baseline creation, and changed-file preparation.
- Reusable pilot result template under `evaluations/RUN_TEMPLATE.md`.
- CI validation that the fixture compiles, preserves expected canaries, excludes the answer key, installs all applicable pack components, and leaves the intended API/UI files as current changes.

### Fixed

- Yarn discovery no longer leaks a failed native `yarn --version` exit code into an otherwise successful security run.
- Modern Yarn scanning uses `corepack yarn` when Corepack is available, avoiding conflicts with stale globally installed Yarn 1.
- Dependency-free Yarn workspaces skip unnecessary install/audit execution.

## [0.2.0-alpha.1] - 2026-08-25

### Added

- Canonical distributable payload under `pack/`, separated from this repository's development/self-test configuration.
- Versioned, stack-aware `installer/install.ps1` for .NET-only, Angular/Yarn-only, and combined monorepos.
- `installer/upgrade.ps1` with installed-version checks and downgrade protection.
- `installer/uninstall.ps1` with preservation of locally modified files.
- Managed-file SHA-256 state tracking and conflict detection.
- Explicit `-ForceManagedOverwrite` override for reviewed managed-file conflicts.
- Preservation of repository-owned security policy, baselines, exceptions, and existing `copilot-instructions.md`.
- Target `.security/copilot-pack.yml` and `.security/copilot-pack-state.json` installation metadata.
- `-WhatIf` installation preview.
- Installer idempotency, stack-selection, manifest-integrity, normalization, and baseline-initialization tests.
- Per-advisory NuGet normalization using versioned machine-readable package-list JSON.
- Yarn Classic and modern Yarn audit normalization.
- Stable SHA-256 dependency fingerprints and `new` versus `existing` baseline status.
- Repository-relative scanner evidence so fingerprints remain stable across developer workspaces and CI runners.
- Guarded first-adoption `InitializeBaseline` dispatcher mode and Copilot prompt.
- Refusal to initialize or replace a baseline when scanner evidence is incomplete or an established baseline already exists.
- Policy failure when deterministic scanners fail, preventing false-green security results.

### Known limitations

- Real VS Code Copilot behavior still requires representative blind fixture/VDI pilots before a stable v1 release.
- Source-level authorization/business-logic findings still depend on Copilot reasoning rather than deterministic scanner output alone.

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
