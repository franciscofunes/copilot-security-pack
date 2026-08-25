# VS Code Copilot Security Pack Pilot Evaluation

This guide validates the pack as a developer experience, not only as PowerShell automation.

## Goal

Measure whether the VS Code GitHub Copilot extension, using the repository-native Security Reviewer, prompts, instructions, and skills, identifies the expected security boundaries in a clean application workspace without seeing the evaluation answer key.

## Prepare a blind pilot workspace

From a clone of this repository:

```powershell
$pilot = Join-Path $env:TEMP 'copilot-security-pack-pilot'
Remove-Item $pilot -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item ./fixtures/vulnerable-dotnet-angular-monorepo $pilot -Recurse
git -C $pilot init
pwsh -NoProfile -File ./installer/install.ps1 -TargetRepo $pilot
code $pilot
```

Do not copy `evaluations/` into the pilot repository. Do not open the evaluation rubric until after the Copilot response has been recorded.

## Scenario A — ordinary changed-files review

In VS Code Copilot Chat, use the Security Reviewer agent or invoke:

```text
/security-review-changes
```

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

## Scenario C — remediation quality

Choose one high-confidence finding from A or B and use the fix workflow. Measure whether Copilot proposes the smallest safe patch, preserves security boundaries, and verifies the original attack path after the change.

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

Create a dated file outside the application fixture, for example:

```text
evaluations/runs/2026-08-25-vscode-copilot.md
```

Record model selection, VS Code/Copilot extension version if visible, scenario, response summary, score, misses, false positives, and any pack change proposed from the evidence.
