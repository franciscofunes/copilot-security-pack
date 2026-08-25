---
description: Run a broad security audit of the monorepo
agent: Security Reviewer
---

Run `pwsh -NoProfile -File .security/run-security.ps1 -Mode Full` yourself.

Then review deterministic findings plus authentication, authorization, data access, sensitive configuration, dependency changes, and Angular-to-.NET security boundaries. Save detailed evidence in repository output files and keep chat output compact. Never claim the repository is vulnerability-free.
