# Distribution and Release Guide

This project is distributed for **GitHub Copilot Chat in Visual Studio Code**. Copilot CLI and plugin-marketplace installation are intentionally out of scope.

The design uses repository-local Copilot customization because VS Code discovers instructions, prompt files, custom agents, and project skills directly from the application repository.

## 1. Distribution model

Use one canonical security-pack repository as the source of truth, but install a self-contained copy of the applicable runtime files into each application repository.

```text
Canonical copilot-security-pack repository
             |
             | release tag, for example v1.0.0
             v
       install.ps1 / upgrade.ps1
             |
             v
      Application repository
             |
             +-- .github/copilot-instructions.md
             +-- .github/instructions/**
             +-- .github/prompts/**
             +-- .github/agents/**
             +-- .github/skills/**
             +-- .security/**
             |
             v
GitHub Copilot VS Code extension discovers the customization
```

Do not require a developer to clone the canonical pack for normal development after installation.

## 2. VS Code customization locations

The installed repository uses the standard VS Code / GitHub Copilot project locations:

```text
.github/
  copilot-instructions.md
  instructions/
    *.instructions.md
  prompts/
    *.prompt.md
  agents/
    *.agent.md
  skills/
    <skill-name>/
      SKILL.md
```

Project skills are intentionally stored at `.github/skills/<skill-name>/SKILL.md`. VS Code loads relevant skills on demand, which keeps large security procedures out of every conversation.

A skill can also contain its own supporting resources:

```text
.github/skills/security-dotnet/
  SKILL.md
  references/
  scripts/
  examples/
```

Use these supporting folders when the skill grows; keep `SKILL.md` concise and link to resources rather than putting hundreds of lines in the always-read entry file.

## 3. Canonical repository layout

Recommended mature layout:

```text
copilot-security-pack/
  pack/
    .github/
      agents/
      instructions/
      prompts/
      skills/
    .security/
      run-security.ps1
      scripts/
      security-policy.yml

  installer/
    install.ps1
    upgrade.ps1
    uninstall.ps1

  fixtures/
    dotnet-angular-monorepo/

  tests/

  docs/
  CHANGELOG.md
  VERSION
  README.md
```

During v1 development the files may still live directly at the repository root. Before the first stable release, the installer should clearly separate canonical pack templates from installer/test code.

## 4. Installation flow

A user clones or otherwise obtains a tagged version of the canonical pack and runs one installer command:

```powershell
pwsh -NoProfile -File ./installer/install.ps1 -TargetRepo C:\src\my-application
```

The installer must:

1. Validate the target path is a Git repository.
2. Refuse destructive installation when the target has unresolved conflicts.
3. Inspect existing Copilot files before modifying anything.
4. Detect .NET, Angular, Yarn, solution/workspace paths, package-management conventions, and CI.
5. Install only applicable pack components.
6. Merge repository-wide instructions rather than blindly overwrite them.
7. Preserve repository-owned policy, baselines, exceptions, and CI customization.
8. Record the installed pack version and managed-file metadata.
9. Display the resulting Git diff.
10. Never commit, push, or open a pull request automatically unless explicitly requested by the user.

The application repository becomes self-contained after this step.

## 5. Installed manifest

Every installation should create or update `.security/copilot-pack.yml`.

Example:

```yaml
schema: 1
packVersion: 1.0.0
host: vscode-copilot
platform: dotnet-angular-monorepo
installedFeatures:
  dotnet: true
  angular: true
  yarn: true
  crossStackSecurity: true
  customAgent: true
  agentSkills: true
  promptFiles: true
  mcp: false
```

The manifest gives `upgrade.ps1` a stable contract and lets maintainers immediately see which pack generation a repository uses.

## 6. File ownership model

### Pack-managed files

These are normally replaceable by an upgrade when they have not been locally customized:

```text
.github/agents/security-reviewer.agent.md
.github/prompts/security-*.prompt.md
.github/skills/security-dotnet/**
.github/skills/security-angular/**
.github/skills/security-cross-stack/**
.github/instructions/security-*.instructions.md
.security/run-security.ps1
.security/scripts/**
```

The installer should record hashes for managed files so upgrades can detect local modifications.

### Repository-owned files

Never blindly replace these:

```text
.github/copilot-instructions.md
.security/security-policy.yml
.security/dependency-baseline.json
.security/dependency-exceptions.yml
CI workflows
```

When canonical changes conflict with repository-owned content, generate a reviewable proposed merge instead of silently choosing one side.

## 7. Release lifecycle

Use semantic versioning:

```text
v1.0.0  first stable release
v1.0.1  backwards-compatible bug/security fix
v1.1.0  backwards-compatible feature
v2.0.0  breaking installation/runtime contract
```

Recommended flow:

```text
feature branch
      |
      v
pack tests + fixture tests
      |
      v
pilot installation
      |
      v
reviewed merge
      |
      v
v1.x.x release tag
      |
      v
install/upgrade into application repo
      |
      v
reviewable application PR
```

### Before creating a release

Validate:

- PowerShell syntax and automated tests.
- NuGet direct/transitive vulnerability parsing.
- Yarn Classic and modern Yarn audit parsing.
- Baseline/fingerprint behavior.
- Security-policy gates.
- Prompt frontmatter.
- Agent frontmatter.
- Skill frontmatter and folder/name matching.
- Fresh installation into fixture repositories.
- Upgrade from the previous release.
- Rollback/uninstall behavior.
- No secrets or environment-specific credentials are included.

Maintain deliberately vulnerable fixture projects so regression tests prove expected findings are detected.

## 8. Pilot process

Before broad rollout, install a release candidate in a representative application repository and verify:

- VS Code recognizes the `Security Reviewer` agent.
- VS Code discovers the three security skills.
- Prompt commands appear and invoke the intended workflow.
- The agent can run the single `.security/run-security.ps1` dispatcher through terminal tooling.
- Routine commands require no unnecessary manual scripting by developers.
- Terminal approval settings remain appropriately restrictive.
- .NET SDK and Yarn generation are detected correctly.
- Package feeds continue to work without credentials being exposed.
- Findings are actionable and false-positive noise is acceptable.
- Chat responses remain compact and token-efficient.

## 9. Upgrade flow

Upgrades should always be explicit and reviewable:

```powershell
pwsh -NoProfile -File ./installer/upgrade.ps1 \
  -TargetRepo C:\src\my-application \
  -Version 1.1.0
```

`upgrade.ps1` should:

1. Read the installed manifest.
2. Verify the requested source release.
3. Compare hashes of pack-managed files.
4. Replace unchanged managed files safely.
5. Preserve locally modified/repository-owned files.
6. Produce conflicts/proposed merges when needed.
7. Run pack validation.
8. Show `git diff`.
9. Update `packVersion` only when migration succeeds.

Never silently mutate application repositories in the background.

## 10. Rollback

The pack should support rollback to a prior released version without affecting unrelated application code.

Rollback metadata should include:

- Current version.
- Previous version.
- Managed file hashes.
- Repository-owned overrides.

Rollback must never use a destructive repository reset.

## 11. Why not Git submodules

Do not use Git submodules as the primary distribution mechanism.

The Copilot files need to be at specific project locations such as `.github/skills` and `.github/agents`; a submodule does not solve that placement. It also creates extra clone/update steps for developers.

A versioned installer gives the application a self-contained, normal Git tree.

## 12. Why not copy/paste

Manual copying loses provenance and makes upgrades difficult. A few repositories quickly become inconsistent:

```text
Repo A -> 1.0.0
Repo B -> unknown copied version
Repo C -> locally edited scripts
Repo D -> missing a security skill
```

A manifest + installer + semantic version tag avoids this.

## 13. Why no Copilot CLI dependency

The supported user experience is VS Code Copilot Chat. The security pack therefore must not require commands such as `copilot plugin install`, `copilot` CLI sessions, or CLI-specific settings.

PowerShell scripts are ordinary repository automation executed by the Security Reviewer through VS Code terminal tools and by CI. They are not a requirement for developers to interact with a separate Copilot executable.

## 14. Inspiration and upstream patterns

The design intentionally follows patterns visible in mature public Copilot/agent customization projects:

- GitHub `awesome-copilot`: separates agents, instructions, prompts, and on-demand skills instead of one giant prompt.
- Microsoft `vscode-copilot-chat` and VS Code customization specifications: use `.github/agents`, `.github/prompts`, `.github/instructions`, and `.github/skills/<name>/SKILL.md` as distinct primitives.
- Trail of Bits security skills: favor deterministic security tools, scoped review, evidence/false-positive validation, and variant analysis.
- Microsoft/.NET skills projects: package specialized domain workflows as skills rather than always-loaded instructions.
- Superpowers-style agent workflows: explicit workflows, verification gates, and composable procedures rather than an unstructured universal prompt.

External skills or prompt repositories are references only. Do not install third-party code or instructions into production repositories without review.

## 15. Token-efficiency rules

Distribution choices should preserve the runtime token strategy:

- Keep `copilot-instructions.md` small.
- Use path-specific instructions only for applicable files.
- Put detailed security procedures in skills so VS Code loads them only when relevant.
- Run deterministic scanners before asking Copilot to reason.
- Normalize scanner output before exposing it to the agent.
- Review changed files by default.
- Full audits are explicit.
- Limit normal chat findings to the highest-value items.

## 16. Recommended end state

```text
Canonical security pack
        |
        | v1.x release
        v
Versioned installer
        |
        +----> target repo A
        +----> target repo B
        +----> target repo C
                  |
                  v
             normal git clone
                  |
                  v
         VS Code Copilot Chat
                  |
       instructions / prompts
          agent / skills
                  |
                  v
       security dispatcher
                  |
                  v
       deterministic scanners
```

No Copilot CLI and no MCP server are required.

## References

Current GitHub/VS Code documentation confirms that agent skills work in VS Code agent mode and that project skills use `.github/skills/<skill-name>/SKILL.md`. VS Code also documents the separate workspace locations for custom agents, prompt files, path instructions, and skills.

Because Copilot customization evolves quickly, re-check the current VS Code/GitHub Copilot documentation before changing file schemas or discovery paths.
