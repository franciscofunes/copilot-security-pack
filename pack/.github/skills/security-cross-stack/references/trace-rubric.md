# Cross-stack security trace rubric

Load this reference when a finding spans Angular and .NET or when authorization/business logic cannot be assessed correctly from one layer alone.

## Required trace

Follow the operation in this order:

1. UI component/route initiating the action.
2. Angular service/interceptor forming the request.
3. HTTP method, path, body, query, and caller-controlled identifiers.
4. ASP.NET endpoint receiving the request.
5. Authentication scheme and trusted claims.
6. Endpoint policy/role authorization.
7. Resource-level ownership/tenant enforcement.
8. Repository/database query predicate.
9. Mutation or sensitive sink.
10. Response DTO and fields returned to the caller.

## High-value questions

- Which identifiers are controlled by the browser?
- Which identity/tenant values come from trusted claims or server context?
- Can a caller substitute another object/tenant/account identifier?
- Does the API merely require authentication, or does it enforce the required privilege?
- Does the database query itself preserve tenant/ownership isolation?
- Is a privileged request field such as role/admin/status/owner accepted from an unprivileged caller?
- Does the response expose more data than the caller needs or is authorized to read?

## Evidence classification

Use one of:

- **Confirmed** — complete attack path and missing/incorrect control are visible.
- **Probable** — strong evidence, but one important boundary remains unresolved.
- **Needs Investigation** — insufficient context to establish exploitability.
- **False Positive** — the suspected path is blocked by a verified control.

Do not inflate severity when the attack preconditions are unknown. Do not downgrade a server-side authorization flaw because the UI normally hides the action.

## Variant search

After confirming one cross-stack authorization flaw, search sibling endpoints/services for the same trust mistake, especially:

- repeated tenantId/userId/accountId parameters;
- endpoints using `RequireAuthorization()` without a resource policy;
- admin UI guards paired with generally authenticated API endpoints;
- DTOs reused for both normal profile updates and privileged role changes.

## Remediation and verification

Prefer server-side enforcement at the narrowest correct boundary. Add focused tests that attempt the unauthorized variant, then rerun the dispatcher and re-trace the original attack path before claiming the issue fixed.
