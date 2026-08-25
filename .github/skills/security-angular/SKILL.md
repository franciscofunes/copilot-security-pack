---
name: security-angular
description: Use for focused Angular/Yarn security review, dependency analysis, browser security, and secure UI remediation.
---

# Angular security workflow

- Detect Yarn generation from `packageManager`, `.yarnrc.yml`, `.yarnrc`, and `yarn --version`.
- Use immutable/frozen installs; never mutate the lockfile during scanning.
- Review direct and transitive dependency advisories and explain the dependency path before remediation.
- Never run blind or forceful package upgrades.
- Treat client-side authorization only as UX; verify the matching .NET API boundary.
- Investigate unsafe DOM APIs, sanitizer bypasses, browser token handling, redirects, postMessage, interceptors, dynamic resources, and sensitive build-time configuration.
- Fix one confirmed finding at a time and run focused tests/build verification.
