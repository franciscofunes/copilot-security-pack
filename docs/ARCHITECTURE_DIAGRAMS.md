# Architecture Diagrams

These diagrams explain the repository-native Copilot Security Pack without requiring Copilot CLI, MCP, a marketplace, or a submodule.

## 1. Distribution architecture

```mermaid
flowchart LR
    source["copilot-security-pack<br/>canonical repository"]
    release["versioned release<br/>v0.x / v1.x"]
    installer["install.ps1 / upgrade.ps1"]
    target["application repository"]
    vscode["VS Code<br/>GitHub Copilot extension"]

    source --> release --> installer --> target --> vscode

    subgraph payload["Installed repository-native payload"]
      instructions[".github/instructions"]
      prompts[".github/prompts"]
      agents[".github/agents"]
      skills[".github/skills"]
      security[".security/"]
    end

    target --> payload
```

The target repository is self-contained after installation. The canonical repository is only needed again when installing or upgrading.

## 2. Developer review flow

```mermaid
flowchart TB
    dev["Developer in VS Code"] --> chat["GitHub Copilot Chat"]
    chat --> command{"How was review started?"}

    command -->|slash prompt| prompt["security-review-*.prompt.md"]
    command -->|agent picker| reviewer["Security Reviewer"]

    prompt --> reviewer
    reviewer --> skill{"Which expertise is needed?"}
    skill --> dotnet["security-dotnet skill"]
    skill --> angular["security-angular skill"]
    skill --> cross["security-cross-stack skill"]

    dotnet --> dispatcher
    angular --> dispatcher
    cross --> dispatcher

    dispatcher[".security/run-security.ps1"] --> evidence["deterministic evidence"]
    evidence --> normalize["normalized findings + fingerprints"]
    normalize --> reasoning["Copilot triage + attack-path reasoning"]
    reasoning --> result["compact findings / minimal remediation / verification"]
```

## 3. Deterministic evidence boundary

```mermaid
flowchart LR
    changed["changed files"] --> dispatcher["single dispatcher"]
    manifests["package manifests"] --> dispatcher

    dispatcher --> nuget["NuGet vulnerability evidence"]
    dispatcher --> yarn["Yarn Classic / modern audit evidence"]
    dispatcher --> repo["repository profile"]

    nuget --> normalized["findings-summary.json"]
    yarn --> normalized
    repo --> normalized

    normalized --> policy["CI policy gate"]
    normalized --> copilot["Copilot reasoning"]

    policy -->|new high / critical| fail["fail CI"]
    policy -->|scanner failure| fail
    policy -->|allowed legacy debt| pass["pass with evidence"]
```

Deterministic tools produce evidence. Copilot is responsible for contextual security reasoning, not for inventing scanner results.

## 4. Cross-stack authorization trace

```mermaid
flowchart LR
    component["Angular component / route"] --> service["Angular service"]
    service --> request["HTTP request"]
    request --> endpoint["ASP.NET endpoint"]
    endpoint --> authentication["authentication"]
    authentication --> authorization["authorization policy / role"]
    authorization --> ownership["tenant / object ownership"]
    ownership --> query["repository / DB query"]
    query --> dto["response DTO"]

    guard["UI guard"] -. "navigation UX only" .-> component
    guard -. "never substitutes for" .-> authorization
```

The review follows the real data and authorization path. A browser-side route guard or hidden button is never considered an API security boundary.

## 5. Dependency baseline lifecycle

```mermaid
stateDiagram-v2
    [*] --> FirstAdoption
    FirstAdoption --> ScannerRun: InitializeBaseline requested
    ScannerRun --> Rejected: scanner error
    ScannerRun --> Review: complete evidence
    Review --> BaselineCreated: explicit approval
    BaselineCreated --> NormalOperation

    NormalOperation --> Existing: fingerprint already baselined
    NormalOperation --> NewFinding: fingerprint not baselined
    NewFinding --> Blocked: high / critical
    NewFinding --> ReviewRequired: moderate / policy dependent

    BaselineCreated --> Rejected: attempt to replace non-empty baseline
```

A baseline classifies pre-existing debt. It is not a suppression mechanism and is not evidence that a vulnerability is acceptable.

## 6. Upgrade ownership model

```mermaid
flowchart TB
    upgrade["upgrade.ps1"] --> inspect["compare installed SHA-256 state"]
    inspect --> same{"managed file changed locally?"}
    same -->|no| replace["reconcile to new pack version"]
    same -->|yes| stop["stop and report conflict"]
    stop --> review["human review"]
    review -->|explicit override| force["-ForceManagedOverwrite"]

    owned["repo-owned policy / baseline / exceptions / existing Copilot instructions"] --> preserve["preserve"]
```

## 7. Blind VS Code pilot

```mermaid
flowchart LR
    fixture["intentionally vulnerable fixture"] --> prep["prepare-pilot.ps1"]
    prep --> workspace["clean standalone Git repo"]
    workspace --> install["install current pack"]
    install --> vscode["open only pilot repo in VS Code"]
    vscode --> review["run normal Security Reviewer flows"]
    review --> record["record output first"]
    record --> rubric["score against external rubric"]
    rubric --> improve["change smallest responsible layer"]
    improve --> rerun["repeat same blind scenario"]
```

The evaluation answer key remains outside the application workspace so Copilot cannot discover the expected findings during the blind run.
