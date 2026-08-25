---
name: security-dotnet
description: Use for focused .NET security review, NuGet vulnerability investigation, authentication/authorization analysis, and secure remediation.
---

# .NET security workflow

- Run `.security/run-security.ps1` rather than individual scripts.
- Use Changes mode for ordinary review and Dependencies mode for package-only review.
- Treat deterministic scanner output as candidate evidence, not proof of exploitability.
- For vulnerable transitive packages, identify the direct parent before proposing remediation.
- Prefer central package management when `Directory.Packages.props` is present.
- Never suppress NU190x warnings automatically.
- For code findings, establish source, security boundary, attacker-controlled input, authorization decision, and sensitive sink/data access.
- After a confirmed vulnerability, search for variants of the same pattern.
- Fix one finding at a time with the smallest safe patch and focused regression test.

For authentication/authorization, tenant isolation, BOLA/IDOR, over-posting, API input/output, and server-side sink review, load [authorization-checklist.md](./references/authorization-checklist.md) only when that deeper checklist is relevant.
