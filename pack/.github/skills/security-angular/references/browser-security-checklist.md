# Angular and browser security checklist

Load this reference when reviewing Angular UI code, browser security boundaries, client-side authorization assumptions, or Yarn-backed frontend changes.

## Authorization boundary

- Treat route guards, hidden elements, disabled controls, and client-side role checks as UX only.
- Identify the API operation behind each privileged UI action and verify server-side authorization there.
- Watch for caller-controlled tenant/user/account IDs forwarded to the API without a trusted server-side ownership check.

## DOM and content handling

- Review direct DOM APIs and HTML injection paths.
- Investigate sanitizer bypass APIs and trust-boundary escapes.
- Verify user-controlled URLs, styles, resource URLs, and iframe/embed sources are constrained appropriately.

## Tokens and browser state

- Review storage of access tokens and sensitive state in localStorage/sessionStorage where relevant.
- Check whether browser-controlled flags such as `isAdmin`, tenant, or role are treated as security authority.
- Review interceptors for credential leakage or unintended cross-origin behavior.

## Navigation and messaging

- Validate redirect/returnUrl destinations before navigation.
- Review `postMessage` origin/source validation.
- Check external links and dynamically constructed destinations where attacker-controlled data is involved.

## Configuration and secrets

- Distinguish public frontend configuration from server secrets.
- Do not treat build-time environment substitution as secret storage.
- Review source maps and debug configuration when they may expose sensitive implementation details.

## Yarn/dependencies

- Preserve the lockfile during scanning.
- For modern Yarn prefer the repository-declared version/Corepack path; do not rely on a stale global Yarn binary.
- Explain whether a vulnerable package is direct or transitive and identify the deterministic dependency path when available.
- Avoid blanket/force upgrades.

## Remediation discipline

- Fix the smallest confirmed browser-side issue while preserving the API security boundary.
- Never remediate missing server authorization only by adding another UI guard.
- Run focused frontend tests/build verification and rerun the relevant dispatcher mode before claiming the issue fixed.
