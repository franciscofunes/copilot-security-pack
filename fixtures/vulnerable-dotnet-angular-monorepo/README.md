# Vulnerable .NET + Angular/Yarn Monorepo Fixture

> **Intentionally vulnerable test code. Do not deploy or reuse this application code.**

This fixture exists to evaluate the Copilot Security Pack against known security boundaries in a small cross-stack repository.

## Included canaries

- `SEC-001` — cross-tenant object access caused by trusting a caller-controlled `tenantId`.
- `SEC-002` — frontend-only admin protection while the API only checks authentication.
- `SEC-003` — mass assignment of the privileged `IsAdmin` property.
- `SEC-004` — unrestricted server-side URL fetching (SSRF pattern).

The expected reasoning and minimum remediation for every canary are recorded in `evaluation.json`.

## Why this fixture exists

The goal is not to teach Copilot the answers by adding the evaluation rubric to a target application's normal context. The rubric is for **after-the-run scoring**. During a pilot, open a clean copy of the fixture with the security pack installed and ask Copilot to review it using the normal Security Reviewer experience. Compare the results against `evaluation.json` only after recording the assistant output.

## Expected pilot flow

1. Copy this fixture to a separate temporary Git repository.
2. Install the pack using `installer/install.ps1`.
3. Open only that temporary repository in VS Code.
4. Use `/security-review-changes`, `/security-review-flow`, and the `Security Reviewer` agent as defined by the pilot scenario.
5. Record findings before consulting `evaluation.json`.
6. Score detection, evidence quality, severity, remediation quality, false positives, and unnecessary context/tool usage.

The fixture's .NET project is kept dependency-light so CI can compile it without relying on vulnerable third-party packages. Dependency-vulnerability parser testing remains covered separately by synthetic NuGet/Yarn audit fixtures.
