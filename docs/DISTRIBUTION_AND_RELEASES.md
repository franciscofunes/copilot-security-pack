# Distribution and Release Guide

This guide explains how to distribute, install, version, upgrade, and eventually package the Copilot Security Pack using the distribution mechanisms currently supported by GitHub Copilot.

The goal is to avoid manual copy/paste while keeping target repositories self-contained and usable from IDE-based Copilot Chat.

## 1. Understand the two distribution layers

GitHub currently supports two relevant models:

1. **Project-local Copilot customization**
   - Instructions, prompt files, custom agents, and project skills are committed directly to the application repository.
   - Project skills live under `.github/skills`, `.claude/skills`, or `.agents/skills`.
   - This is the most portable baseline for IDE-first usage because the customization travels with the repository.

2. **Copilot plugins**
   - Plugins are installable bundles of reusable agents, skills, hooks, MCP configuration, and related integrations.
   - GitHub documents plugins as a distribution mechanism for Copilot CLI and the Copilot cloud agent.
   - Plugins can be installed from a repository, a local path, or a registered plugin marketplace.

These mechanisms are complementary.

For this security pack, use a **hybrid release model**:

```text
Canonical security-pack repository
           |
           | tagged release
           v
   Versioned pack release
           |
     +-----+--------------------+
     |                          |
     v                          v
Project-local installer      Copilot plugin
(IDE-first baseline)         (CLI/cloud enhancement)
     |                          |
     v                          v
Target application repo      Installed reusable plugin
```

The project-local installation is the compatibility baseline. Plugin packaging is an additional distribution option, not a replacement for repository-local security policy, baselines, CI configuration, or scanner scripts.

## 2. What belongs in the canonical repository

The canonical pack should contain the source-of-truth versions of:

```text
.github/
  agents/
  prompts/
  skills/
  instructions/

.security/
  run-security.ps1
  scripts/
  security-policy.yml

installer/
  install.ps1
  upgrade.ps1

plugin/
  plugin.json          # when plugin packaging is enabled

CHANGELOG.md
README.md
```

Target application repositories should receive only the project-local files that are applicable to that repository.

Do not require target applications to reference the canonical repository at runtime.

## 3. Recommended installation model for IDE-first projects

The desired installation experience is one command from the canonical pack:

```powershell
pwsh -NoProfile -File ./installer/install.ps1 -TargetRepo C:\src\my-application
```

The installer should:

1. Inspect the target repository before modifying it.
2. Detect .NET, Angular, Yarn, CI, and existing Copilot customization.
3. Select only applicable pack components.
4. Merge existing Copilot instructions instead of overwriting them.
5. Copy repository-local agents, skills, prompt files, and security automation.
6. Generate `.security/copilot-pack.yml` with the installed version.
7. Preserve repository-specific policy and baseline files.
8. Show the resulting Git diff.
9. Never commit, push, or open a pull request without explicit approval.

After installation, the target repository is self-contained:

```text
application-repository/
  .github/
    copilot-instructions.md
    instructions/
    prompts/
    agents/
    skills/
  .security/
    run-security.ps1
    scripts/
    security-policy.yml
    dependency-baseline.json
```

Developers cloning the application repository receive the security capability automatically. They do not need to separately clone the canonical pack for normal use.

## 4. Why not use Git submodules

Avoid distributing the pack as a Git submodule.

Project-level Copilot customization is discovered from defined project locations such as `.github/skills`, and application-specific security policy and CI integration must live with the application.

Submodules also add lifecycle friction:

```text
git clone --recurse-submodules
git submodule update
```

A versioned installer provides a simpler developer experience and makes the resulting repository self-contained.

## 5. Release lifecycle

Use semantic versioning for the pack:

```text
v1.0.0  first stable release
v1.0.1  backwards-compatible fix
v1.1.0  backwards-compatible feature
v2.0.0  breaking pack contract or migration
```

Each release should follow this sequence.

### Step 1 - Develop on a feature branch

Example:

```text
feat/security-pack-v1
```

Changes should be reviewed through a pull request before becoming a release candidate.

### Step 2 - Validate the pack itself

Before release, test:

- PowerShell syntax and unit tests.
- NuGet output parsing.
- Yarn Classic and modern Yarn output parsing.
- Baseline comparison.
- Policy gating.
- Prompt and skill frontmatter.
- Installation into fixture repositories.
- Upgrade from the previous released version.
- Uninstall or rollback behavior.

Maintain intentionally vulnerable fixture projects so tests prove that known findings are detected.

### Step 3 - Pilot a release candidate

Install the candidate into one representative application repository.

Validate:

- Copilot Chat UX.
- .NET SDK compatibility.
- Yarn generation.
- Package feeds.
- CI behavior.
- False-positive rate.
- Execution permissions.
- Scanner runtime.
- Token/context usage.

Do not promote the release if the installer rewrites unrelated files or creates excessive security noise.

### Step 4 - Merge the canonical implementation

Merge the reviewed pull request into the canonical branch only after the pilot is acceptable.

### Step 5 - Create a release tag

Create an immutable version tag:

```text
v1.0.0
```

The tag is the identity recorded by target repositories.

Example target manifest:

```yaml
schema: 1
packVersion: 1.0.0
source: copilot-security-pack
installedFeatures:
  dotnet: true
  angular: true
  yarn: true
  crossStackSecurity: true
```

### Step 6 - Publish release notes

Release notes should include:

- Added capabilities.
- Changed scanner behavior.
- Fixed false positives.
- New required prerequisites.
- Breaking changes.
- Security-policy changes.
- Migration instructions.
- Known limitations.

Maintain a `CHANGELOG.md` in the canonical repository.

### Step 7 - Upgrade target repositories through pull requests

Do not silently mutate application repositories.

For each upgrade:

```powershell
pwsh -NoProfile -File ./installer/upgrade.ps1 \
  -TargetRepo C:\src\my-application \
  -Version 1.1.0
```

The upgrade process should produce a reviewable Git diff and update `packVersion` only after a successful migration.

## 6. Upgrade ownership model

Classify installed files into two groups.

### Pack-managed files

Normally replaced or migrated by the installer:

```text
.github/agents/security-reviewer.agent.md
.github/skills/security-dotnet/**
.github/skills/security-angular/**
.github/skills/security-cross-stack/**
.github/prompts/security-*.prompt.md
.security/run-security.ps1
.security/scripts/**
```

### Repository-owned files

Never blindly overwrite:

```text
.github/copilot-instructions.md
.security/security-policy.yml
.security/dependency-baseline.json
.security/dependency-exceptions.yml
CI workflows
```

The installer should merge or request human review when a repository-owned file changes.

## 7. Plugin packaging

After the reusable agent/skill layer is stable, it can also be packaged as a Copilot plugin.

GitHub Copilot plugins may contain reusable:

- Agents.
- Skills.
- Hooks.
- MCP configuration.
- LSP configuration.
- Extensions and other plugin resources supported by the plugin manifest.

A plugin manifest can be stored at one of the supported plugin manifest locations, such as `.github/plugin/plugin.json` or `plugin.json`.

A simplified future layout could be:

```text
.github/plugin/plugin.json
agents/
skills/
hooks/
```

The plugin should contain reusable Copilot behavior only.

Do **not** move these application-specific artifacts into the plugin:

- Vulnerability baseline.
- Approved exceptions.
- Repository security policy overrides.
- Application CI workflow.
- Target-specific package configuration.

## 8. Direct plugin installation

GitHub supports installing plugins directly from a GitHub repository, Git URL, or local path.

Supported plugin specifications include forms such as:

```text
OWNER/REPO
OWNER/REPO:PATH/TO/PLUGIN
https://github.com/owner/repo.git
./local-plugin
```

The Copilot CLI uses `copilot plugin install` for direct plugin installation.

Direct repository installation is appropriate while a plugin is being piloted and does not yet need marketplace discovery.

## 9. Declarative plugin installation

For supported Copilot plugin hosts, plugins can also be enabled declaratively from repository configuration using:

```text
.github/copilot/settings.json
```

GitHub documents the `enabledPlugins` field for declarative plugin enablement in Copilot CLI and the cloud agent.

This provides a repository-controlled way to declare the expected plugin set instead of requiring every user to remember an install command.

Do not rely on this mechanism as the sole distribution path until all target IDE workflows support the required plugin behavior.

## 10. Plugin marketplaces

When several reusable plugins need discoverability and centralized versioning, create a Copilot plugin marketplace.

GitHub defines marketplaces with a `marketplace.json` manifest. Supported locations include `.github/plugin/marketplace.json` and other documented marketplace manifest paths.

Typical flow:

```text
Plugin repository/repositories
          |
          v
marketplace.json
          |
          v
Registered Copilot marketplace
          |
          v
copilot plugin install plugin-name@marketplace-name
```

A marketplace becomes valuable when:

- Multiple plugins are maintained.
- Users need discovery.
- Consistent version metadata is required.
- Updates should be manageable through Copilot's plugin commands.

For a single pack under active development, direct repository installation is simpler.

## 11. Skills-only distribution

GitHub also supports distributing agent skills independently of a full plugin.

Project skills can be installed under:

```text
.github/skills/
```

GitHub CLI provides `gh skill` for discovering, installing, updating, and publishing skills, and Copilot CLI supports installing a skill into project scope.

Skills are appropriate when the reusable unit is primarily specialized instructions plus scripts/resources and does not require the larger plugin bundle.

This pack uses several skills, but they operate together with repository policy, prompt files, scanners, and CI. Therefore distributing only the skills would provide an incomplete security solution.

## 12. Recommended distribution maturity model

### Stage A - Development

```text
Canonical repository
        |
        v
Manual pilot installation
```

Purpose: validate architecture.

### Stage B - Versioned installer

```text
Tagged canonical release
        |
        v
install.ps1 / upgrade.ps1
        |
        v
Self-contained application repositories
```

Purpose: primary IDE-compatible distribution model.

### Stage C - Plugin package

```text
Reusable agents + skills
        |
        v
Copilot plugin
```

Purpose: eliminate manual duplication on plugin-capable Copilot hosts.

### Stage D - Marketplace, if needed

```text
Versioned plugins
      |
      v
Plugin marketplace
```

Purpose: discovery and centralized plugin management when the plugin catalog grows.

## 13. Security requirements for distribution

Treat the pack itself as a software supply-chain component.

Before release:

- Review all scripts and agent tool permissions.
- Keep MCP disabled unless explicitly required and reviewed.
- Never package credentials.
- Never embed registry secrets.
- Avoid runtime downloads of unpinned executables.
- Pin external CI actions according to repository policy.
- Validate all plugin or skill dependencies before publication.
- Keep agent tool permissions minimal.
- Require explicit justification for security suppressions.
- Maintain a changelog for security-affecting behavior.

Installing a third-party plugin or skill means trusting its instructions, scripts, hooks, and tool usage. Review external components before including them in the pack.

## 14. Rollback

Every release should be reversible.

The installer should preserve enough metadata to identify:

- Installed version.
- Pack-managed files.
- Repository-owned overrides.
- Previous version.

A rollback should restore the previous pack-managed version while preserving repository-owned policy, baselines, and exceptions.

Never implement rollback by resetting or discarding unrelated application changes.

## 15. Recommended end state

For an IDE-first security workflow, the recommended final architecture is:

```text
Canonical Copilot Security Pack
          |
          | semantic-versioned releases
          |
          +----------------------------+
          |                            |
          v                            v
Versioned project installer       Copilot plugin
          |                      reusable agents/skills
          v                            |
Application repositories              v
.instructions/prompts/skills      CLI/cloud hosts
.security scripts/policy
CI security gate
```

This keeps the application repository independently secure and operational while also taking advantage of GitHub's native plugin distribution model where it is supported.

## References

This distribution model follows current GitHub documentation for:

- GitHub Copilot plugins and their repository/local/marketplace installation models.
- Copilot plugin manifests and marketplaces.
- Declarative `enabledPlugins` configuration for supported plugin hosts.
- Project agent skills and their `.github/skills` location.
- `gh skill` and Copilot CLI skill installation.

Because Copilot customization capabilities are evolving quickly, re-check the current GitHub Copilot documentation before changing the supported-host matrix or making plugin installation mandatory.
