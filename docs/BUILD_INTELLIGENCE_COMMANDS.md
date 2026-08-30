# Build Intelligence CLI contracts

The pack invokes only read-oriented commands in v0.5.

## GitHub CLI

- `gh auth status`
- `gh run list --commit <HEAD> --json ...`
- fallback: `gh run list --branch <branch> --json ...`
- `gh pr view <branch> --json ...`
- `gh pr checks <branch> --json ...`

The agent never calls rerun/cancel/delete commands in BuildContext mode.

## Azure CLI + Azure DevOps extension

- `az pipelines runs list --branch <branch> --top 10 --output json`

Optional organization/project/pipeline IDs come from `.security/build-intelligence.json`; otherwise repository auto-detection is used. BuildContext never queues pipelines or uploads artifacts.

## JFrog CLI

- `jf build-scan <build-name> <build-number> --format=json`

Build name/number must be explicitly resolvable from repository configuration. Supported `buildNumberFrom` values are:

- `githubRunNumber`
- `githubRunId`
- `azureBuildId`
- `azureBuildNumber`

An explicit static `buildNumber` is also supported for controlled fixtures, but branch-linked CI mapping is preferred.

BuildContext never publishes/promotes/discards build-info or uploads artifacts.
