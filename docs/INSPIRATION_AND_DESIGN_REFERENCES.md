# Inspiration and Design References

This project intentionally borrows proven structural patterns from mature public agent/Copilot customization repositories while keeping the runtime restricted to GitHub Copilot Chat in Visual Studio Code.

## GitHub / VS Code customization layout

VS Code and GitHub document project-level customization as separate primitives:

```text
.github/
  copilot-instructions.md
  instructions/*.instructions.md
  prompts/*.prompt.md
  agents/*.agent.md
  skills/<name>/SKILL.md
```

This separation is important for context efficiency:

- repository instructions stay small and broadly applicable;
- path instructions load for relevant files;
- prompts represent explicit user workflows;
- custom agents define specialized behavior/tool usage;
- skills hold detailed procedures and resources that are loaded when relevant.

The Security Pack follows this model directly.

## github/awesome-copilot

Useful patterns:

- Treat agents, prompts, instructions, and skills as different primitives rather than one giant system prompt.
- Keep skills focused on repeatable tasks.
- Bundle scripts/references with a skill when useful.
- Use progressive disclosure so specialized context is loaded only when needed.

Applied here:

- `security-dotnet`, `security-angular`, and `security-cross-stack` are separate skills.
- Repository-wide instructions remain intentionally short.
- Security commands live in prompt files rather than permanent instructions.

## microsoft/vscode and vscode-copilot-chat

Useful patterns:

- Project skills use `.github/skills/<skill-name>/SKILL.md`.
- Skills may contain `references/`, `scripts/`, examples, and other supporting assets.
- Custom agents live separately under `.github/agents`.
- Prompt files and path-specific instructions remain independent customization layers.

Applied here:

```text
.github/skills/security-dotnet/
  SKILL.md
  references/   # add as the skill grows
  scripts/      # add only when the script logically belongs to the skill
```

The repository-level `.security` dispatcher remains the deterministic runtime contract because multiple skills and CI use it.

## dotnet/skills

The .NET team's public skills repository is a strong example of domain decomposition.

Useful patterns:

- Split broad platform expertise into focused domains instead of one enormous skill.
- Treat NuGet/package-management knowledge separately from general language/runtime guidance where complexity justifies it.
- Evaluate skill accuracy and efficiency, not only whether the prompt sounds comprehensive.

Applied here:

The current v1 begins with three broad security skills. If the pilot shows excessive context or weak triggering, split them further, for example:

```text
security-dotnet-authz
security-dotnet-nuget
security-dotnet-api
security-angular-browser
security-yarn-supply-chain
security-cross-stack-authz
```

Do not split skills merely for architectural neatness; split only when evaluation shows better recall, precision, or context efficiency.

## Trail of Bits security skills

Useful patterns:

- Deterministic scanners produce candidate evidence.
- AI validates exploitability rather than blindly repeating scanner output.
- Explicit false-positive analysis reduces noise.
- Once a vulnerability is confirmed, search for variants of the same pattern.
- Scope reviews to relevant changes and attack surfaces before expanding outward.

Applied here:

```text
scanner finding
    -> normalize
    -> validate evidence
    -> classify
    -> find variants
    -> minimal remediation
    -> regression test
    -> verification
```

The pack should never equate a scanner advisory with demonstrated exploitability of application code.

## obra/superpowers

Useful patterns:

- Systematic workflows instead of ad-hoc agent improvisation.
- Explicit verification gates.
- Evidence before claiming completion.
- Small composable skills and procedures.
- Stop and report blockers instead of guessing through failed verification.

Applied here:

The Security Reviewer must not report a finding as fixed merely because it changed code. It must rerun the relevant deterministic check and focused tests first.

Recommended invariant:

```text
NO SECURITY FIX CLAIM WITHOUT FRESH VERIFICATION EVIDENCE
```

## Caveman-inspired communication

Useful principle:

- Compress agent output without removing exact technical evidence.

Applied here:

- no generic security tutorials in routine review;
- maximum five findings by default;
- preserve exact file paths, commands, package names, vulnerability IDs, and errors;
- detailed machine output stays in `.security/output` rather than chat.

## Ponytail-inspired implementation

Useful principle:

- Prefer the smallest implementation and existing/native functionality before adding abstractions or packages.

Applied here:

Before adding a package or helper, check:

1. Is it necessary?
2. Does the repository already have the capability?
3. Does .NET, ASP.NET Core, Angular, Yarn, or the browser provide it?
4. Does an already-installed dependency provide it?
5. Only then add the smallest safe new implementation.

Never simplify away authentication, authorization, validation, audit logging, or other security boundaries in the name of minimalism.

## Design rules derived from the comparison

1. Keep always-loaded instructions small.
2. Prefer focused skills over a universal security encyclopedia.
3. Give skills supporting references/scripts only when they improve execution.
4. Keep deterministic scanners outside the LLM whenever possible.
5. Normalize tool output before sending it to Copilot.
6. Default to changed-file review.
7. Require evidence before declaring a vulnerability confirmed or fixed.
8. Search for variants after confirming a vulnerability.
9. Keep developer interaction to one Copilot command/agent action.
10. Measure false-positive rate, runtime, and context/token usage during pilot evaluation.

## External dependency policy

Public repositories are inspiration, not runtime dependencies.

Do not automatically install third-party skills, scripts, plugins, hooks, or MCP servers into application repositories. Review and internalize useful patterns into this pack instead.
