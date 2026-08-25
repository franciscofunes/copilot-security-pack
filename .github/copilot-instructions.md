# Repository-wide Copilot security rules

- Follow existing architecture, naming, testing, and dependency-management conventions.
- Preserve authentication, authorization, validation, logging, data-isolation, and tenant boundaries.
- Never reveal secrets, tokens, credentials, connection strings, or private feed credentials.
- Prefer existing repository functionality and native .NET, Angular, Yarn, and browser capabilities before adding dependencies.
- Make the smallest change that closes the demonstrated security issue; avoid unrelated refactoring.
- Do not suppress analyzers, package advisories, or security warnings merely to make builds pass.
- Do not automatically perform major dependency upgrades.
- Use `.security/run-security.ps1` as the security automation entry point. Do not ask developers to run internal scanner scripts.
- Default to changed-file security review; full audits must be explicit or CI-scheduled.
- Use deterministic scanners before AI reasoning. Read normalized findings instead of pasting full logs into chat.
- Never run active scans against production.
- Never claim the repository is vulnerability-free. State evidence and uncertainty.
- Keep security responses compact: at most five findings by default, each with file/area, evidence, impact, confidence, and minimum remediation.
- For monorepos, verify security across the Angular-to-.NET boundary; UI route guards never replace API authorization.
