---
name: dependency-check
description: >
  Retrieves dependency vulnerabilities for a repository branch from Qualimetry,
  then resolves them by upgrading each vulnerable dependency to its next safe
  version. Uses a per-dependency upgrade advisor to assess risk and applies
  low-risk upgrades automatically, proposes medium/high-risk upgrades for
  confirmation, and flags dependencies with no clean upgrade path for manual
  replacement. Reads the approved and pending suppressions that cover the
  branch so already-accepted risk is not reworked. Validates all changes with a
  package restore and build.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server (Enterprise) and git to be configured.
allowed-tools: get_dependency_vulnerabilities get_dependency_upgrade_advice get_dependency_suppressions
metadata:
  author: qualimetry
  version: "1.2"
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

   Two optional filters are available:
   - `cve` - narrow the whole response to a single CVE (e.g. `CVE-2020-28500`) across every dependency. Use it when the user asks about one advisory.
   - `includeSuppressed` - default `false`. Set it to `true` to also list, per dependency, the CVEs an approved suppression has already removed, each with its scope, requester, reason and expiry. Use it when the user asks what has been accepted, or when a CVE they expected to see is missing.

3. Check the suppression flags before planning any work. See [Suppressions](#suppressions) below.
   - A CVE with `SuppressionPending` is waiting for someone to approve a suppression for it. Report it, do not spend effort fixing it, and move on.
   - A dependency with `SuppressionExpiringSoon` has an approved suppression that runs out within 15 days. The findings it hides today will reappear when it does, so raise it with the user now.

4. If the result contains zero vulnerabilities, report that no dependency vulnerabilities were found and stop. Check first whether suppressions are hiding any, so a clean report is not mistaken for a clean scan.

5. Present a brief summary to the user: total vulnerable dependencies, highest risk score, count by ecosystem, how many have an available safe upgrade, how many are waiting on a suppression decision, and any suppression about to expire.

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

1. Check the inline fields: `NextSafeVersion`, `UpgradeRisk`, `CurrentVersionIsDeprecated`, and the suppression flags on the dependency and its CVEs.

2. Apply the following decision tree:

**Every CVE on the dependency has `SuppressionPending`:**
- Do not upgrade. Someone has already asked for the risk to be accepted and the request is in the approval queue.
- Tell the user the dependency is waiting on a suppression decision, and move to the next one.

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
   - Any CVE left alone because a suppression is pending, and any suppression expiring soon

## Suppressions

A suppression is a recorded decision to accept a dependency CVE: a false positive, a risk the organisation has agreed to carry, or a finding that cannot be acted on yet. Approved suppressions are applied by the scanner, so the suppressed CVEs are stripped out before the report is written. That means the vulnerability list you get is what is left after suppression, and by default it says nothing about what was taken out.

What the flags mean:

| Flag | Where | Meaning |
|---|---|---|
| `SuppressionPending` | On a CVE | Somebody has requested a suppression for this CVE and nobody has approved it yet. Pending requests are not applied, so the CVE is still in the list, but it is not work to do. Report it and leave it. |
| `SuppressionExpiringSoon` | On a dependency | An approved suppression covering this dependency expires within 15 days. The findings it hides will reappear, so flag it now rather than letting it surprise the team. |

To see the full picture, call `get_dependency_suppressions` with `repositoryName` and optionally `branchName`. It returns the suppressions that apply to the branch, grouped by dependency and then by identifier, each with its `State`, `Scope` and `ScopeName` (how widely it applies), `RequesterName`, `RequestedDateTime`, `ExpiresAt`, `IsFalsePositive` and `Reason`. Add `state` to filter to `REQUESTED`, `APPROVED`, `REJECTED` or `EXPIRED`, and `includeExpired` to include suppressions that have already run out.

Use it to answer "why is this CVE not showing?", "what has this project already accepted?" and "what is about to come back?".

**Raising, approving and rejecting a suppression are human actions in the Qualimetry dashboard.** They need an approver, a written reason and an expiry date, and there is no tool here that can do any of it. When a CVE looks suppressible, say so and give the reason you would put on the request, and leave the request to the user.

If `get_dependency_suppressions` is not among the tools available to you, this Qualimetry deployment is older than the suppression tools. Say so in one line and carry on with the upgrade workflow.

## Important

- Always use `git branch --show-current` to get the branch name. Do not guess or assume branch names.
- Always upgrade to `NextSafeVersion`, never to `LatestVersion`.
- Process dependencies in descending risk-score order to address the highest-impact vulnerabilities first.
- Never upgrade a dependency whose CVEs are all marked `SuppressionPending`. The risk is already on its way to being accepted.
- The vulnerability list is what survived suppression at scan time. Use `includeSuppressed` when the user needs to know what was taken out and why.
- Use the inline upgrade fields from `get_dependency_vulnerabilities` first. Only call `get_dependency_upgrade_advice` when you need deeper detail (breaking changes, error messages, advisory flags).
- If a Qualimetry MCP tool is not available, inform the user that the Qualimetry MCP server (Enterprise) may not be configured.

For full MCP tool schemas, response formats, and the decision tree reference, see [reference.md](./reference.md).
