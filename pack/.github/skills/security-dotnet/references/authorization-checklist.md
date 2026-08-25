# .NET authorization and API security checklist

Load this reference when reviewing authentication, authorization, tenant isolation, privileged operations, or API data access.

## Authentication and identity

- Identify the authentication scheme actually used by the endpoint.
- Verify JWT issuer, audience, signature, lifetime, and trusted claim handling where relevant.
- Distinguish authentication from authorization; an authenticated endpoint may still be vulnerable.
- Do not trust user, tenant, organization, account, or role identifiers from request data when a trusted claim/security context should provide them.

## Authorization

- Verify endpoint-level policy/role requirements.
- Follow service-layer or resource-level authorization when access depends on object ownership.
- Look for BOLA/IDOR patterns where a caller-controlled ID selects another user's or tenant's object.
- Verify admin/role-changing operations require privileged server-side authorization.
- Treat Angular guards and hidden buttons as UX only.

## Data access and tenant isolation

- Trace the trusted tenant/object identity into the repository/query layer.
- Confirm tenant/ownership predicates are applied to the actual database query, not only checked earlier in UI code.
- Check sibling queries/endpoints for the same missing predicate after confirming one issue.

## Input and binding

- Prefer purpose-specific request DTOs.
- Look for over-posting/mass assignment of role, admin, ownership, tenant, status, approval, price, or other privileged fields.
- Review raw SQL, interpolated SQL, command execution, path construction, file uploads, unsafe deserialization, and server-side URL fetching.

## Output and observability

- Verify response DTOs do not expose fields the caller is not authorized to read.
- Check exception responses and logs for secrets, tokens, credentials, personal data, internal connection details, or sensitive business data.

## Remediation discipline

- Fix the demonstrated attack path with the smallest safe change.
- Preserve existing security boundaries.
- Add a focused regression test proving the unauthorized path is denied.
- Rerun the relevant dispatcher mode before claiming the finding fixed.
