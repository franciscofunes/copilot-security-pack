---
description: Trace a privileged UI-to-API flow across Angular and .NET
agent: Security Reviewer
---

Trace the requested operation end-to-end:
Angular component/route -> Angular service/interceptor -> HTTP request -> .NET endpoint -> authentication -> authorization -> tenant/ownership checks -> database query -> response DTO.

Do not assume UI guards enforce security. Confirm server-side authorization and data filtering. Classify each issue as Confirmed, Probable, Needs Investigation, or False Positive. Keep the result compact and evidence-based.
