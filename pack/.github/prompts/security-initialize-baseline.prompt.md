---
description: Initialize the first-adoption dependency vulnerability baseline after explicit review
agent: Security Reviewer
---

Use this workflow only for the first adoption of the security pack in a repository with an empty dependency baseline.

1. Run `pwsh -NoProfile -File .security/run-security.ps1 -Mode Dependencies` yourself.
2. Read `.security/output/findings-summary.json` and summarize exactly which dependency findings would become legacy baseline entries. Do not hide scanner errors.
3. If any scanner error exists, stop and resolve it before baselining.
4. Ask the developer for explicit approval to initialize the baseline with the listed findings.
5. Only after approval, run `pwsh -NoProfile -File .security/run-security.ps1 -Mode InitializeBaseline -ConfirmBaseline` yourself.
6. Verify that the baseline was created and that those fingerprints now normalize as `existing`.

Never replace a non-empty baseline, never use baseline initialization as a generic suppression mechanism, and never baseline scanner errors. New vulnerabilities discovered after the initial baseline remain new and are subject to policy gating.
