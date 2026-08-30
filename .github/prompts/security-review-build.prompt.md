---
description: Correlate the current branch/worktree with GitHub Actions, Azure DevOps, and JFrog build security evidence.
agent: Security Reviewer
---

Review build and CI security evidence related to the developer's current Git branch/worktree.

1. Run `pwsh -NoProfile -File .security/run-security.ps1 -Mode BuildContext` through the VS Code terminal.
2. Read `.security/output/build-context.json`; do not paste raw CLI output into chat.
3. Correlate evidence to the exact HEAD SHA first and the current branch second.
4. Summarize failing/pending GitHub Actions or Azure pipeline runs that are relevant to the current work.
5. If JFrog build identity is explicitly resolved, include Xray build-scan evidence. Never guess a build name or build number.
6. Distinguish `unavailable`, `not-authenticated`, `not-configured`, and `not-resolved` providers from clean results.
7. Do not queue, rerun, cancel, publish, promote, delete, or otherwise mutate remote build state.
8. Return a compact result: correlated build(s), security-relevant failures, artifact/build-scan evidence, and the next useful developer action.
