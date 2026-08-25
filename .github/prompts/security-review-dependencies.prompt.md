---
description: Review NuGet and Yarn dependencies for known vulnerabilities and risky changes
agent: Security Reviewer
---

Run `pwsh -NoProfile -File .security/run-security.ps1 -Mode Dependencies` yourself.

Then:
1. Read normalized findings.
2. Prioritize new high/critical advisories.
3. For transitive findings, determine which direct package introduces the vulnerable package.
4. Prefer the smallest compatible upgrade and existing central package-management conventions.
5. Never run forceful/bulk upgrades or add suppressions automatically.
6. Report only actionable results and uncertainty.
