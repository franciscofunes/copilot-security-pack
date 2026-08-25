# Development workflow

Stable releases are tagged from `main`. New work starts from the latest released `main` state on a feature branch and is reviewed through a pull request.

Current development line:

```text
v0.1.0-alpha.1
      |
      v
feat/v0.2.0-installer
      |
      v
installer + upgrade + tests
```

Do not merge installer changes until the installer smoke workflow passes and the target-file ownership rules are reviewed.
