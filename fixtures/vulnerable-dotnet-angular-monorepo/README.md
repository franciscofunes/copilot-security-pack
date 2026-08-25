# Vulnerable .NET + Angular/Yarn Monorepo Fixture

> **Intentionally vulnerable test code. Do not deploy or reuse this application code.**

This fixture exists to evaluate the Copilot Security Pack against known security boundaries in a small cross-stack repository.

## Included canaries

- `SEC-001` — cross-tenant object access caused by trusting a caller-controlled `tenantId`.
- `SEC-002` — frontend-only admin protection while the API only checks authentication.
- `SEC-003` — mass assignment of the privileged `IsAdmin` property.
- `SEC-004` — unrestricted server-side URL fetching (SSRF pattern).

The answer key is intentionally **not stored in this fixture directory**. It lives outside the pilot workspace under `evaluations/vulnerable-dotnet-angular-monorepo.json` in the pack repository.

## Why the answer key is separate

VS Code Copilot can search workspace files even when they are not open. Keeping expected findings inside the application fixture would contaminate the evaluation. A pilot copy must contain only the application code and the installed security pack.

## Expected pilot flow

1. Copy this fixture to a separate temporary Git repository.
2. Install the pack using `installer/install.ps1`.
3. Open only that temporary repository in VS Code.
4. Use the defined pilot scenario and record the assistant response.
5. Close or leave the pilot workspace before consulting the external evaluation rubric.
6. Score detection, evidence quality, severity, remediation quality, false positives, and context/tool discipline.

The fixture's .NET project is dependency-light so CI can compile it without relying on intentionally vulnerable third-party packages. Dependency-vulnerability parser testing remains covered separately by synthetic NuGet/Yarn audit fixtures.
