# Open Source and External Design Patterns

The Copilot Security Pack is MIT licensed. External projects are design references only unless a file explicitly says otherwise.

## Why MIT

MIT matches the permissive licensing used by several closely related open-source projects in the Copilot/agent ecosystem, including:

- GitHub Awesome Copilot — MIT
- Microsoft vscode-copilot-chat — MIT
- GitHub Spec Kit — MIT
- dotnet/skills — MIT
- obra/superpowers — MIT

MIT keeps the pack easy to evaluate, fork, adapt, and install into private or public repositories while preserving the required copyright/license notice.

## External projects we learn from

| Project | Pattern adopted here | What we do not adopt |
| --- | --- | --- |
| GitHub Awesome Copilot | Clear separation of prompts, agents, instructions, and skills; discoverable reusable customizations | Plugin marketplace or MCP dependency |
| Microsoft vscode-copilot-chat | Workspace-native customization layout; progressive disclosure with `SKILL.md`, `references/`, `scripts/`, and `assets/`; focused prompt/agent frontmatter | VS Code extension internals or product-specific implementation code |
| GitHub Spec Kit | Versioned bootstrap/install lifecycle, persistent repository artifacts, explicit release discipline | A separate CLI as the developer interaction surface |
| dotnet/skills | Domain-focused .NET skills and small reusable expertise modules | Codex/Cursor marketplace distribution |
| obra/superpowers | Verification-before-completion, composable skills, repeatable evaluation of skill behavior | Runtime dependency, telemetry, or non-VS-Code plugin installation |
| Trail of Bits security tooling patterns | Deterministic evidence first, false-positive validation, variant search, attack-path reasoning | Automatic active scanning of production systems |

## Hard compatibility boundary

This repository intentionally supports the **GitHub Copilot extension in Visual Studio Code** as the developer-facing Copilot host.

We do not require or distribute through:

- GitHub Copilot CLI
- `copilot plugin install`
- `gh skill install`
- MCP servers
- Git submodules
- another agent marketplace

Skills may follow the open Agent Skills folder model because VS Code Copilot supports project skills under `.github/skills/<name>/SKILL.md`. The fact that the same open skill format is understood by other agent systems does not change this project's supported host.

## Progressive disclosure rule

Keep the main `SKILL.md` small enough to load cheaply. Put deeper material under the skill folder only when it is useful for a specific review:

```text
.github/skills/security-dotnet/
  SKILL.md
  references/
    authorization-checklist.md
```

The same pattern applies to Angular and cross-stack review.

Use `references/` for detailed review criteria, framework-specific edge cases, and investigation guidance. Use `scripts/` only for deterministic operations that genuinely belong to the skill and do not duplicate the stable `.security/run-security.ps1` dispatcher contract. Use `assets/` only for templates or static material.

## No copy-without-review policy

External repositories are inspiration, not an automatic dependency source.

Before incorporating third-party code or text:

1. verify its license;
2. determine whether we are copying code/text or only adopting a general pattern;
3. preserve notices/attribution when the source license requires it;
4. avoid importing incompatible/copyleft code into the distributable pack without an explicit licensing decision;
5. prefer an original implementation of the underlying pattern when that is sufficient.

At present, the pack's external references are architectural/design inspiration rather than vendored runtime dependencies.

## Primary references

- https://github.com/github/awesome-copilot
- https://github.com/microsoft/vscode-copilot-chat
- https://github.com/github/spec-kit
- https://github.com/dotnet/skills
- https://github.com/obra/superpowers
- https://docs.github.com/en/copilot/concepts/agents/about-agent-skills
- https://code.visualstudio.com/docs/agent-customization/agent-skills
