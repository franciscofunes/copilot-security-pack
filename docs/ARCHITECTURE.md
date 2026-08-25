# Architecture

```text
Canonical repository
      |
      | semantic-versioned release
      v
installer/install.ps1
      |
      v
Target application repository
      |
      +-- .github/instructions
      +-- .github/prompts
      +-- .github/agents
      +-- .github/skills
      +-- .security
             |
             v
VS Code GitHub Copilot extension + deterministic security dispatcher
```

The target repository is self-contained after installation. Copilot CLI, MCP, plugin marketplaces, and Git submodules are not required.
