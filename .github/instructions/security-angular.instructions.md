---
applyTo: "**/*.ts,**/*.html,**/*.scss,**/*.css,**/angular.json,**/package.json,**/yarn.lock,**/.yarnrc,**/.yarnrc.yml"
---

# Angular/Yarn security review

When security-relevant UI files change, check for:

- `innerHTML`, unsafe DOM APIs, or `bypassSecurityTrust*` usage.
- Unsafe URL/resource construction, redirects, or `postMessage` handling.
- Tokens or secrets stored in browser-accessible locations without a justified threat model.
- Client-side-only authorization assumptions.
- Route guards that are not backed by server-side authorization.
- Sensitive values bundled into production configuration.
- Unsafe HTTP interceptor behavior and credential forwarding.
- CSP incompatibilities and dynamic script/resource loading.
- Dependency or lockfile changes, package aliases/resolutions, Yarn patches, or registry changes.
- Direct and transitive Yarn dependency vulnerabilities.

Never treat Angular route guards, hidden controls, or UI role checks as security boundaries. Confirm the matching .NET API authorization whenever the UI triggers a privileged operation.
