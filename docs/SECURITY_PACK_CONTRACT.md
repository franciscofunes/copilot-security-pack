# Security Pack contract

The stable target-repository automation entry point is:

```powershell
pwsh -NoProfile -File .security/run-security.ps1 -Mode Changes
```

The installer may evolve internally, but target repositories should not require developers to know individual scanner scripts. VS Code Copilot prompts and the Security Reviewer agent invoke the dispatcher; CI may invoke the same dispatcher independently.
