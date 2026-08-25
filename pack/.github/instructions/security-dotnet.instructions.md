---
applyTo: "**/*.cs,**/*.csproj,**/*.props,**/*.targets,**/appsettings*.json,**/NuGet.config,**/nuget.config"
---

# .NET security review

When security-relevant .NET files change, check the demonstrated code path for:

- Missing authentication or authorization.
- Broken object-level authorization / IDOR.
- Tenant or organization IDs accepted from requests instead of trusted identity claims.
- Missing ownership checks in repositories or EF Core queries.
- Over-posting / mass assignment and privileged DTO fields.
- SQL injection or unsafe raw SQL.
- SSRF, path traversal, unsafe uploads, command execution, or insecure deserialization.
- JWT validation, cookies, CORS, antiforgery, redirects, and webhook verification.
- Sensitive-data logging and exception disclosure.
- Unsafe cryptography or secret handling.
- Swagger/OpenAPI exposure, rate limits, and request-size limits where relevant.
- Direct and transitive NuGet vulnerabilities.

Require evidence and an attack path before calling a code finding confirmed. For remediation, make the smallest safe patch and add a focused regression test.
