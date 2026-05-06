---
name: dependency-check
description: >
  Retrieves dependency vulnerabilities for a repository branch from Qualimetry,
  then resolves them by upgrading each vulnerable dependency to its next safe
  version. Uses a per-dependency upgrade advisor to assess risk and applies
  low-risk upgrades automatically, proposes medium/high-risk upgrades for
  confirmation, and flags dependencies with no clean upgrade path for manual
  replacement. Validates all changes with a package restore and build.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server (Enterprise) and git to be configured.
allowed-tools: get_dependency_vulnerabilities get_dependency_upgrade_advice
metadata:
  author: qualimetry
  version: "1.1"
  homepage: https://qualimetry.com
---

# Dependency Vulnerability Resolution

When invoked, follow this four-phase workflow to identify and clear dependency CVE vulnerabilities for the current repository branch.

## Phase 1: Assess

Gather repository context and fetch the vulnerability report with inline upgrade advice.

1. Determine the `repositoryName` and `branchName`:

**`repositoryName`** — the repository name in `owner/repo-name` format (e.g., `organisation/my-project`). The server is case-insensitive and handles `.git` suffixes automatically.

**`analysisName`** *(optional)* — if the repository is a mono-repo with multiple analysis projects, provide the analysis project name to disambiguate. Case-insensitive. Leave empty for single-project repositories.

**`branchName`** — run this shell command:

```bash
git branch --show-current
```
This returns the `branchName`.

2. Call `get_dependency_vulnerabilities` with `repositoryName`, `branchName`, and optionally `analysisName`. The response includes inline upgrade advice for each dependency: `NextSafeVersion`, `LatestVersion`, `UpgradeRisk`, and `CurrentVersionIsDeprecated`.

3. If the result contains zero vulnerabilities, report that no dependency vulnerabilities were found and stop.

4. Present a brief summary to the user: total vulnerable dependencies, highest risk score, count by ecosystem, and how many have an available safe upgrade.

## Phase 2: Locate Manifests

Search the workspace for dependency manifest files so upgrades can be applied.

Look for these files based on the ecosystems present in the vulnerability results:

| Ecosystem | Manifest Files |
|-----------|---------------|
| npm | `package.json` |
| maven | `pom.xml` |
| nuget | `*.csproj`, `Directory.Packages.props`, `packages.config` |
| pypi | `requirements.txt`, `pyproject.toml`, `setup.py`, `setup.cfg` |
| cargo | `Cargo.toml` |
| go | `go.mod` |
| rubygems | `Gemfile`, `*.gemspec` |

Map each vulnerable dependency to its manifest file using the `Ecosystem` and `PackageName` from the vulnerability data.

## Phase 3: Resolve

Process each vulnerable dependency in descending risk-score order. The inline upgrade advice from Phase 1 provides the information needed to resolve most dependencies without additional tool calls.

For each dependency:

1. Check the inline fields: `NextSafeVersion`, `UpgradeRisk`, `CurrentVersionIsDeprecated`.

2. Apply the following decision tree:

**`NextSafeVersion` exists and `UpgradeRisk` is Low:**
- Edit the manifest file directly, updating the dependency version to `NextSafeVersion`.
- Log the change.

**`NextSafeVersion` exists and `UpgradeRisk` is Medium or High:**
- Present the upgrade to the user with the following details:
  - Current version and `NextSafeVersion` (with `NextSafeVersionPublishedAt`)
  - `UpgradeRisk` level
  - `LatestVersion` and `LatestVersionPublishedAt` for context
- Optionally call `get_dependency_upgrade_advice` for deeper detail (e.g. `HasPotentialBreakingChanges`, `NextCleanMessage`).
- Wait for user confirmation before applying the edit.

**`NextSafeVersion` is null:**
- Flag the dependency for manual replacement.
- Optionally call `get_dependency_upgrade_advice` for an `ErrorMessage` with failure detail.
- Suggest the user search for an alternative package.

**`CurrentVersionIsDeprecated` is true:**
- Inform the user the current version is deprecated and recommend upgrading regardless of risk level.

Always upgrade to `NextSafeVersion` (the nearest version with no known CVEs). Do not skip to `LatestVersion` as that maximises breaking-change risk for no additional security benefit.

## Phase 4: Validate

After all upgrades have been applied:

1. Run the ecosystem-appropriate restore command:

| Ecosystem | Restore Command |
|-----------|----------------|
| npm | `npm install` |
| maven | `mvn install -DskipTests` |
| nuget | `dotnet restore` |
| pypi | `pip install -r requirements.txt` |
| cargo | `cargo build` |
| go | `go mod tidy` |
| rubygems | `bundle install` |

2. Run the build to verify no regressions were introduced.

3. Report the results to the user:
   - Number of dependencies upgraded
   - Number flagged for manual replacement
   - Whether the build succeeded or failed
   - Any dependencies that could not be resolved

## Important

- Always use `git branch --show-current` to get the branch name. Do not guess or assume branch names.
- Always upgrade to `NextSafeVersion`, never to `LatestVersion`.
- Process dependencies in descending risk-score order to address the highest-impact vulnerabilities first.
- Use the inline upgrade fields from `get_dependency_vulnerabilities` first. Only call `get_dependency_upgrade_advice` when you need deeper detail (breaking changes, error messages, advisory flags).
- If a Qualimetry MCP tool is not available, inform the user that the Qualimetry MCP server (Enterprise) may not be configured.

For full MCP tool schemas, response formats, and the decision tree reference, see [reference.md](./reference.md).
