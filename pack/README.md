# Canonical Pack Payload

This directory is the source of files installed into target application repositories.

- `pack/.github/**` contains VS Code GitHub Copilot customization.
- `pack/.security/**` contains deterministic security automation and default policy scaffolding.
- `installer/**` contains distribution tooling and is never copied into target repositories.
- Root `.github/**` and `.security/**` configure and test this source repository itself; they are not the installation payload.

Changes to distributable behavior should be made here first and validated through installer tests before release.
