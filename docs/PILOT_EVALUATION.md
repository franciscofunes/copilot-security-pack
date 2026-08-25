# VS Code Copilot Security Pack Pilot Evaluation

This guide validates the pack as a developer experience, not only as PowerShell automation.

## Goal

Measure whether the VS Code GitHub Copilot extension, using the repository-native Security Reviewer, prompts, instructions, and skills, identifies the expected security boundaries in a clean application workspace without seeing the evaluation answer key.

## Prepare a blind pilot workspace

From a clone of this repository, run one command:

```powershell
$pilot = Join-Path $env:TEMP 'copilot-security-pack-pilot'
Remove-Item $pilot -Recurse -Force -ErrorAction SilentlyContinue
pwsh -NoProfile -File ./evaluations/prepare-pilot.ps1 -Destination $pilot -OpenInVSCode
```

The preparation script:

- copies only the vulnerable application fixture, never the evaluation rubric
- initializes a standalone Git repository and baseline commit
- installs the current security pack
- leaves `api/Program.cs` and `web/src/app/api.service.ts` as the current working-tree changes
- verifies the Security Reviewer, prompts, skills, and dispatcher are present
- optionally opens the prepared repository in VS Code

Do not open anything under `evaluations/` until after the Copilot responses have been recorded.

## Scenario A — ordinary changed-files review

In VS Code Copilot Chat, invoke:

```text
/security-review-changes
```

Do not add hints about the expected vulnerabilities.

Record:

- findings returned
- referenced files/lines or symbols
- severity/confidence
- terminal commands invoked
- whether raw scanner logs were pasted into chat
- obvious false positives

## Scenario B — cross-stack authorization review

Invoke:

```text
/security-review-flow
```

Ask it to review the order/admin/user flows across Angular and .NET. Do not mention the expected vulnerabilities.

A strong result should trace browser -> service -> HTTP -> API endpoint -> authentication -> authorization -> trusted tenant/object ownership -> data operation.

## Scenario C — custom agent behavior

Select the `Security Reviewer` agent and ask:

```text
Review the current changes for security issues. Do not modify code.
```

Confirm that it uses the repository dispatcher rather than asking you to run internal scanner scripts and that it keeps output compact.

## Scenario D — remediation quality

Choose one high-confidence finding from the blind review and use `/security-fix-finding` (or the Security Reviewer with an explicit remediation request). Measure whether Copilot proposes the smallest safe patch, preserves security boundaries, and verifies the original attack path after the change.

Do not accept a remediation that only adds a frontend guard for a missing API authorization control.

## Scoring

After recording the blind run, compare it with `evaluations/vulnerable-dotnet-angular-monorepo.json`.

Score each expected case:

- `0` — missed or materially wrong
- `1` — detected, but incomplete evidence/impact/remediation
- `2` — detected with correct attack path, impact, and minimum safe remediation

Additional quality dimensions, each `0–2`:

- cross-stack trace quality
- false-positive discipline
- concise output / no log flooding
- tool discipline / dispatcher usage
- remediation minimality
- verification before claiming fixed

The four canaries contribute 8 points and the six quality dimensions contribute 12 points, for a maximum of 20.

## Suggested release-candidate threshold

For the fixture pilot:

- detect all four expected canaries
- no critical false-positive claim
- at least `16/20` overall
- no claim that the repository is vulnerability-free
- no bypass of the single dispatcher contract
- no use of Copilot CLI or MCP

A miss does not automatically mean the pack architecture is wrong. First classify whether the cause is instruction discovery, skill triggering, prompt wording, insufficient evidence collection, or model reasoning. Change the smallest responsible layer and rerun the same blind scenario.

## Recording results

Copy `evaluations/RUN_TEMPLATE.md` to a dated file outside the application fixture, for example:

```text
evaluations/runs/2026-08-25-vscode-copilot.md
```

Record model selection, VS Code/Copilot extension version if visible, scenario outputs, score, misses, false positives, terminal/tool behavior, and any pack change proposed from the evidence.
