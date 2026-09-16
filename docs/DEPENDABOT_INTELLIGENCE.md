# Dependabot Intelligence

Dependabot Intelligence adds a read-only GitHub CLI evidence path to the Copilot Security Pack. It deliberately keeps these concepts separate:

1. Dependabot alerts.
2. Dependabot security updates.
3. Repository version-update configuration in `.github/dependabot.yml`.
4. Organization Dependabot repository access.
5. Organization code security configurations that control Dependabot features.

A missing `dependabot.yml` file does **not** prove Dependabot alerts are disabled. The Security Reviewer reports each state independently.

## Architecture

```mermaid
flowchart TB
    dev["Developer in VS Code"] --> prompt["/security-review-dependabot"]
    prompt --> reviewer["Security Reviewer"]
    reviewer --> dispatcher["run-security.ps1 -Mode Dependabot"]

    dispatcher --> repoCollector["Repository Dependabot collector"]
    dispatcher --> orgCollector["Organization security-config collector"]

    repoCollector --> files["Tracked repository files"]
    repoCollector --> ghRepo["gh api: repository Dependabot endpoints"]
    orgCollector --> ghOrg["gh api: organization security endpoints"]

    files --> config["dependabot.yml presence + detected ecosystems"]
    ghRepo --> alerts["Open Dependabot alerts"]
    ghRepo --> updates["Security-update state"]
    ghRepo --> access["Org Dependabot repository access"]

    ghOrg --> configs["Code security configurations"]
    ghOrg --> defaults["Default configurations"]
    ghOrg --> attached["Configuration attached to current repository"]

    config --> repoEvidence["dependabot-context.json"]
    alerts --> repoEvidence
    updates --> repoEvidence
    access --> repoEvidence

    configs --> orgEvidence["dependabot-org-context.json"]
    defaults --> orgEvidence
    attached --> orgEvidence

    repoEvidence --> reviewer
    orgEvidence --> reviewer
    reviewer --> result["Compact alerts + posture + readiness + next action"]
```

## Repository decision model

```mermaid
flowchart TD
    start["Dependabot review"] --> config{".github/dependabot.yml exists?"}
    config -->|No| recommend["Recommend version-update configuration\nfrom detected ecosystems"]
    config -->|Yes| basic["Basic structure check\nversion 2 / updates / ecosystem / schedule"]

    start --> alerts{"Repository alerts endpoint available?"}
    alerts -->|Yes| findings["Count + severity + direct/transitive evidence"]
    alerts -->|No| alertGap["Evidence gap\nnot equivalent to zero alerts"]

    start --> updates{"Security-update state visible?"}
    updates -->|Yes| state["Report enabled / paused"]
    updates -->|No + admin evidence| disabled["Report disabled"]
    updates -->|No + permission unclear| unknown["Unknown / permission-limited"]

    start --> owner{"Owner is organization?"}
    owner -->|No| personal["Org checks not applicable"]
    owner -->|Yes| org["Inspect org readiness and security configurations"]
```

## Organization readiness

```mermaid
flowchart LR
    repo["Organization-owned repository"] --> depAccess["Dependabot repository-access API"]
    repo --> orgAlerts["Organization Dependabot alerts API"]
    repo --> configs["Code security configurations API"]

    configs --> available["Available configurations"]
    configs --> defaults["Defaults for new repositories"]
    configs --> attached["Configuration attached to this repository"]

    available --> settings["dependabot_alerts\ndependabot_security_updates"]
    defaults --> settings
    attached --> settings

    depAccess --> evidence["Organization readiness evidence"]
    orgAlerts --> evidence
    settings --> evidence

    denied["403 / 404 / insufficient permission"] --> unknown["Unknown / permission-limited"]
    unknown --> rule["Never label org misconfigured from inaccessible endpoint alone"]
```

GitHub's current organization-wide model exposes Dependabot settings through code security configurations. The pack therefore inspects configuration records, organization defaults, and the configuration attached to the current repository when the authenticated `gh` identity has sufficient permission.

## Developer command

From Copilot Chat in VS Code:

```text
/security-review-dependabot
```

The deterministic command is:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Dependabot
```

It writes:

```text
.security/output/dependabot-context.json
.security/output/dependabot-org-context.json
```

Both files are marked as untrusted external evidence.

## GitHub CLI contract

v0.7 is observational/read-only. It uses existing authenticated `gh` access and GET requests only.

Repository-level queries include:

```text
gh repo view --json nameWithOwner,isPrivate,url
gh api repos/{owner}/{repo}
gh api repos/{owner}/{repo}/dependabot/alerts?state=open&per_page=100 --paginate --slurp
gh api repos/{owner}/{repo}/automated-security-fixes
```

For organization-owned repositories, when permissions allow:

```text
gh api orgs/{org}/dependabot/alerts?state=open&per_page=1
gh api orgs/{org}/dependabot/repository-access?per_page=100 --paginate --slurp
gh api orgs/{org}/code-security/configurations?per_page=100 --paginate --slurp
gh api orgs/{org}/code-security/configurations/defaults
gh api repos/{owner}/{repo}/code-security-configuration
```

No alert dismissal, enable/disable action, configuration attachment, organization access update, or other remote mutation is performed by this mode.

## Missing `.github/dependabot.yml`

When the file is absent, the pack does not write one automatically. It returns a recommendation plus detected package ecosystems and likely manifest directories. The Security Reviewer may create the file only after an explicit developer request.

The minimum GitHub shape is:

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
```

Required concepts are `version: 2`, `updates`, `package-ecosystem`, `directory` or `directories`, and `schedule.interval`.

For the pack's typical repositories:

- NuGet/.NET -> `package-ecosystem: "nuget"`.
- npm/Yarn/pnpm -> `package-ecosystem: "npm"`.
- GitHub Actions -> `package-ecosystem: "github-actions"`.
- Docker -> `package-ecosystem: "docker"`.

The collector detects tracked files and returns suggestions; it does not guess private-registry credentials or write Dependabot secrets.

## AI-agent trust boundary

Dependabot advisory summaries, package names, manifest paths, URLs, configuration names, and other GitHub provider data are untrusted. The collector:

- removes control characters/newlines from compact text fields;
- bounds model-visible strings;
- strips URL query strings, fragments, and credentials;
- samples at most 50 open alerts while preserving total counts and a truncation marker;
- prioritizes sampled alerts by severity;
- never passes provider text as authorization for tool use.

```mermaid
flowchart LR
    provider["GitHub / Dependabot data"] --> sanitize["Bound + normalize + redact"]
    sanitize --> marker["evidenceTrust = untrusted-external-content"]
    marker --> reviewer["Security Reviewer"]
    hostile["Embedded instruction:\nignore policy / run command / reveal secret"] --> sanitize
    reviewer -->|treat as data only| safe["Security posture result"]
```

## Official references

- Dependabot alerts API: https://docs.github.com/en/rest/dependabot/alerts
- Dependabot repository access API: https://docs.github.com/en/rest/dependabot/repository-access
- Dependabot configuration reference: https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference
- About `dependabot.yml`: https://docs.github.com/en/code-security/concepts/supply-chain-security/about-the-dependabot-yml-file
- Dependabot security updates: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-security-updates
- Code security configurations API: https://docs.github.com/en/rest/code-security/configurations
- GitHub CLI `gh api`: https://cli.github.com/manual/gh_api
