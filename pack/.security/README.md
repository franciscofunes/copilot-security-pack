# Security Pack

Use `.security/run-security.ps1` as the single local/CI entry point. Detailed scanner outputs belong under `.security/output` and should not be pasted into Copilot Chat unless a focused investigation requires them.

## Modes

- `Changes`: default developer review; scopes work to changed/security-adjacent files.
- `Dependencies`: NuGet + Yarn dependency vulnerability review.
- `Full`: broader deterministic scan/build/test workflow.
- `Finding`: focused lookup/investigation of one normalized finding.

## Developer experience

Use the prompt files from Copilot Chat. The agent runs the dispatcher; developers should not run individual internal scripts.

## Baselines

Existing vulnerabilities may be recorded in `dependency-baseline.json` to support incremental adoption. A baseline is not a suppression or approval. New high/critical findings are intended to fail policy evaluation.

## MCP

MCP is disabled by default. Add an MCP integration only for a reviewed external system that cannot be handled through repository-native tooling.
