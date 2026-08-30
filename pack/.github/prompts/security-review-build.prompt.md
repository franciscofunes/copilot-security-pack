---
description: Correlate the current branch/worktree with GitHub Actions, Azure DevOps, and JFrog build security evidence.
agent: Security Reviewer
---

Review build and CI security evidence related to the developer's current Git state.

1. Run `pwsh -NoProfile -File .security/run-security.ps1 -Mode BuildContext` through the VS Code terminal.
2. Read `.security/output/build-context.json`; do not paste raw CLI output into chat.
3. State the correlation level for every conclusion: `exact-head`, `branch`, or `none`.
4. If `git.worktreeDirty` is true, explicitly say remote builds represent committed HEAD only and do not include the listed uncommitted changes.
5. Summarize failing or pending GitHub Actions/Azure pipeline evidence relevant to the current work. Pending GitHub PR checks are evidence, not command failure.
6. If JFrog build identity is explicitly resolved, report its `scanStatus`. `policy-violation` means Xray completed and found policy-failing evidence; it is not a scanner execution error.
7. Read `.security/output/jfrog-build-scan.json` only when JFrog evidence needs deeper inspection; keep the default response compact.
8. Never guess a JFrog build identity. Never interpret `unavailable`, `not-authenticated`, `extension-unavailable`, `not-configured`, `no-branch`, `not-resolved`, or `query-failed` as a clean scan.
9. Do not queue, rerun, cancel, upload, publish, promote, delete, install provider tooling, log in interactively, or otherwise mutate local/remote provider state.
10. Return: Git state, correlated builds/checks, security-relevant failures, JFrog evidence if resolved, confidence/correlation limitations, and the next useful developer action.
