# Bootstrap Prompt — Install Copilot Security Pack

Paste this once into GitHub Copilot Chat Agent mode at the root of a target repository.

---

You are installing the organization-owned Copilot Security Pack into an existing repository.

## Safety rules

- Inspect before modifying.
- Do not overwrite existing Copilot instructions, CI, analyzers, package configuration, or security tooling blindly.
- Do not expose credentials or private-feed secrets.
- Do not install global tools or MCP servers.
- Do not run active scans against production.
- Do not perform automatic major package upgrades or vulnerability suppressions.
- Prefer existing repository tooling and native .NET/Angular capabilities.
- Keep changes minimal and reviewable.

## Discovery

Determine from repository evidence:

- monorepo layout and repository root;
- `.sln`/`.slnx`, `.csproj`, SDK and target frameworks;
- ASP.NET Core APIs, authentication, authorization, data access and tests;
- `angular.json`, `package.json`, `yarn.lock`, Yarn generation/workspaces and Angular tests;
- Central Package Management and NuGet feeds;
- existing GitHub Copilot instructions, prompts, agents and skills;
- existing CodeQL, Dependabot, secret scanning, OSV, SAST, analyzers and CI;
- actual CI provider and required build commands.

Never assume a capability is licensed merely because the repository is hosted on GitHub.

## Install

Adapt and copy the pack's `.github` and `.security` artifacts into the target repository. The target repository must expose one stable command:

`pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes`

The dispatcher must detect and operate on both .NET API and Angular/Yarn portions of the monorepo. Developers must not need to know individual scanner commands.

Preserve and merge compatible existing instructions. Keep repository-wide instructions small; put detailed .NET/Angular rules in path-specific instructions and detailed procedures in skills.

Adapt scripts to actual solution and workspace paths. For NuGet, scan direct and transitive dependencies with the SDK-appropriate command. For Angular, detect Yarn Classic versus modern Yarn and use frozen/immutable installation plus Yarn audit without mutating the lockfile. Detect OSV or other approved scanners when already available, but do not download tools without approval.

Cross-stack security review must trace privileged operations from Angular component/service through the HTTP request to the .NET endpoint, authentication, authorization, tenant/object ownership check, database query, and response DTO. Never treat a UI route guard as sufficient authorization.

## CI

Reuse the repository's existing CI provider. Do not introduce a second CI platform. Configure pull-request security checks using `Changes` mode and default-branch/scheduled checks using `Full` mode where appropriate. Existing findings should be baselined; newly introduced high/critical findings should fail policy evaluation.

## Verify

Run at least:

- `pwsh -NoProfile -File .security/run-security.ps1 -Mode Dependencies`
- `pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes`

Verify scripts and structured output, ensure scans did not modify package manifests/lockfiles, inspect the Git diff, and report skipped checks honestly.

Before pushing or opening a pull request, summarize created/modified files, scan results, tests, limitations, optional unavailable integrations, and any administrator action required. Ask for approval before pushing.
