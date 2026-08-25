---
name: security-cross-stack
description: Use for end-to-end security review of Angular UI actions that call .NET APIs, especially authentication, authorization, tenant isolation, ownership checks, privileged operations, and response exposure.
---

# Cross-stack authorization review

Trace the real security path instead of reviewing UI and API independently:

1. Identify the Angular component or route initiating the operation.
2. Follow the Angular service/interceptor to the HTTP request.
3. Identify the matching .NET endpoint.
4. Determine how authentication is established and which claims are trusted.
5. Verify endpoint-level authorization policy/role requirements.
6. Verify object/tenant ownership enforcement in service/repository/data-access code.
7. Confirm request IDs such as user, tenant, organization, account, or resource IDs are not trusted merely because the UI supplied them.
8. Verify the database query applies the required tenant/ownership boundary.
9. Verify the response DTO does not expose fields the caller is not authorized to see.
10. Search for sibling endpoints/variants with the same pattern after confirming a vulnerability.

Classify findings as Confirmed, Probable, Needs Investigation, or False Positive. A client-side route guard or hidden UI element is never sufficient evidence of authorization.

For a structured evidence rubric, high-value cross-stack questions, variant search, and remediation/verification criteria, load [trace-rubric.md](./references/trace-rubric.md) only when the review spans both browser and API layers.
