---
description: Scan current changes for security vulnerabilities and regressions
agent: Security Reviewer
---

Run `pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes` yourself.

Then:
1. Read `.security/output/findings-summary.json`.
2. Review only changed and security-adjacent code unless evidence requires expansion.
3. Validate new high-risk findings rather than repeating scanner output.
4. If Angular code invokes a privileged API, verify the corresponding .NET authorization and ownership boundary.
5. Return at most five actionable findings with file/area, evidence, impact, confidence, and minimum remediation.
6. Do not edit code.
