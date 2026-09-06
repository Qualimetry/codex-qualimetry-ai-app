---
name: analysis-issues
description: >
  Retrieves and helps clear rules-based analysis issues (bugs, vulnerabilities,
  code smells) for a repository branch. Prioritises by severity and type, works
  file-by-file or in batch mode, and assesses the security hotspots that are
  waiting on a human review decision. Requires Qualimetry Enterprise.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server (Qualimetry Enterprise) and git to be configured.
allowed-tools: get_rules_based_analysis_issues_summary get_rules_based_analysis_issues get_rules_based_analysis_rules get_rules_based_analysis_security_hotspots get_rules_based_analysis_security_hotspot
metadata:
  author: qualimetry
  version: "1.2"
  homepage: https://qualimetry.com
---

# Rules-Based Analysis Issues

When tasked with triaging or clearing rules-based analysis issues (bugs, vulnerabilities, code smells) for a repository, follow this workflow.

## Step 1: Gather Repository Information

Determine the `repositoryName` and `branchName`:

**`repositoryName`** — the repository name in `owner/repo-name` format (e.g., `organisation/my-project`). The server is case-insensitive and handles `.git` suffixes automatically.

**`analysisName`** *(optional)* — if the repository is a mono-repo with multiple analysis projects, provide the analysis project name to disambiguate. Case-insensitive. Leave empty for single-project repositories. If omitted and multiple projects are found, the server returns an error listing the available analysis names.

**`branchName`** — run this shell command:

```bash
git branch --show-current
```
This returns the `branchName` (e.g., `main`, `develop`, `feature/login-page`).

**`pullRequest`** *(optional)* — to retrieve the issues raised on a pull request's new code instead of the whole branch, supply the PR number. Resolve it for the current branch using **standard git only** — no GitHub/Azure/Bitbucket CLI required. Every major host advertises the PR as a ref whose head equals the source-branch tip, so match the branch's remote head SHA against those refs:

```bash
BRANCH=$(git branch --show-current)
SHA=$(git ls-remote origin "refs/heads/$BRANCH" | cut -f1)
git ls-remote origin "refs/pull/*/head" "refs/merge-requests/*/head" "refs/pull-requests/*/from" \
  | awk -v s="$SHA" '$1==s{print $2; exit}' | grep -oE '[0-9]+' | head -1
```

This covers GitHub (`refs/pull/<n>/head`), GitLab (`refs/merge-requests/<n>/head`) and Bitbucket Server (`refs/pull-requests/<n>/from`). If it prints nothing — the branch is not pushed, or the host does not expose PR refs over git (e.g. Bitbucket Cloud, Azure DevOps) — omit `pullRequest` and query the branch.

`branchName` and `pullRequest` are mutually exclusive — when `pullRequest` is set the branch filter is ignored and only the pull-request's new-code issues are returned.

## Step 2: Triage

Call `get_rules_based_analysis_issues_summary` with:
- `repositoryName` - from Step 1
- `branchName` - from Step 1
- `pullRequest` (optional) - from Step 1, to scope the summary to a pull request

This returns total counts broken down by issue type (bugs, vulnerabilities, code smells) and by severity (BLOCKER, CRITICAL, MAJOR, MINOR, INFO).

The summary also reports `SecurityHotspots`, `SecurityHotspotsToReview` and `SecurityHotspotsReviewed`. Security hotspots are security-sensitive code awaiting a human review decision, not issues, so they are counted separately and are not part of `Total`. They are worked in Step 7.

Present the summary to the user so they can see the scope of work.

## Step 3: Prioritize

Fix issues in this order:
1. **BLOCKER/CRITICAL vulnerabilities** -- security issues that must be fixed first
2. **BLOCKER/CRITICAL bugs** -- reliability issues
3. **MAJOR vulnerabilities and bugs**
4. **Code smells** by severity (BLOCKER > CRITICAL > MAJOR > MINOR > INFO)

## Step 4: Retrieve Issues

Choose one of two approaches:

**File-by-file (recommended):** Call `get_rules_based_analysis_issues` with a `filePath` to get all issues for a single file, fix them all at once, then move to the next file.

**Batch by type/severity:** Call `get_rules_based_analysis_issues` with `issueType` and `severities` filters to target the most critical issues across the project. For example, `issueType=VULNERABILITY` and `severities=BLOCKER,CRITICAL`.

Parameters:
- `repositoryName` - from Step 1
- `branchName` - from Step 1
- `issueType` (optional) - `ALL`, `BUG`, `VULNERABILITY`, `CODE_SMELL`, or comma-separated combination
- `severities` (optional) - e.g., `BLOCKER,CRITICAL`
- `filePath` (optional) - full relative file path including filename, using forward slashes (e.g., `src/Services/MyService.cs`). Leave empty for all files.
- `page` (optional, default 1)
- `pageSize` (optional, default 50, max 500)
- `pullRequest` (optional) - from Step 1; returns the pull request's new-code issues instead of the branch issues

Every issue carries a `Source`:

- `Analysis` - raised by the analysis rules against the project's own code. Fix it here.
- `Dependencies` - a known vulnerability in a third-party package, surfaced through the analysis engine. Do not try to fix it from here. This copy of the finding does not know the package version, the next safe version or whether a suppression is already in place. Report it and hand it to the dependency workflow, which uses `get_dependency_vulnerabilities`.

## Step 5: Fix

For each file with issues:
1. Read the source file
2. Apply fixes for all issues in that file
3. Write the corrected code

When fixing issues, reference the `Rule` and `Message` from each issue to understand the exact violation.

## Step 6: Iterate

- If there are more pages of results, increment `page` and retrieve the next batch.
- Move to the next file or the next type/severity combination.
- Repeat until all targeted issues are resolved.

## Step 7: Review Security Hotspots

Security hotspots are security-sensitive pieces of code that need a person to decide whether they are safe in context. They are not issues, so none of them appear in the results from Step 4. A branch with every issue cleared can still have hotspots waiting on a decision, so do not report the branch as clean until this step is done.

If `get_rules_based_analysis_security_hotspots` is not among the tools available to you, this Qualimetry deployment is older than the hotspot tools. Say so in one line, skip this step, and finish the issue workflow as normal.

1. Call `get_rules_based_analysis_security_hotspots` with `repositoryName` and `branchName`. Leave `status` at its default of `TO_REVIEW` to get the hotspots still awaiting a decision, or pass `REVIEWED` to see the ones already settled. Narrow a long list with `vulnerabilityProbability` (`HIGH`, `MEDIUM`, `LOW`), `securityCategory` (e.g. `sql-injection`) or `filePath`, and page through the results with `page` and `pageSize`. Pass `pullRequest` from Step 1 in place of the branch to scope the hotspots to a pull request's new code.

2. Work through them highest `VulnerabilityProbability` first. For each one, call `get_rules_based_analysis_security_hotspot` with its `Key` to get the rule's `RiskDescription`, `VulnerabilityDescription` and `FixRecommendations`.

3. Read the code at `FilePath` and `Line` and decide whether it is safe as written. Where it is not, propose the change, or apply it if the user has asked you to fix as you go.

4. Report your assessment for each hotspot, with the reasoning. **You cannot mark a hotspot as reviewed.** Recording the review decision is a person's action in Qualimetry, so the user needs your assessment to act on.

Hotspots carry the same `Source` field as issues. Some deployments raise dependency CVEs as vulnerabilities and others raise them as security hotspots, so a hotspot with `Source` of `Dependencies` is a package upgrade, not a code review. Hand it to the dependency workflow like any other dependency finding.

## Optional: Look Up Rule Definitions

To understand which automated rules govern a language (independent of any repository), call `get_rules_based_analysis_rules` with a `languageCode` (e.g. `csharp`). Supply an optional `qualityProfileName` to scope to a profile's active rule set; leave it blank for every rule available for the language. Each rule returns its type, clean-code attribute category, software qualities, tags, title, description, and severity. Use this to explain a violated rule's intent or to pre-empt issues before analysis runs.

## Important

- Always use `git branch --show-current` to get the branch name. Do not assume `main` or `master`.
- To review a pull request, resolve its number with standard git (`git ls-remote origin` against the host's PR refs — see Step 1) and pass it as `pullRequest`; this returns only the issues on the PR's new code. Do not also rely on the branch filter — the two are mutually exclusive.
- File paths must use forward slashes, even on Windows.
- Security hotspots are never returned by the issue tools. Do not tell the user a branch is clear of security findings until Step 7 has been done.
- You can assess a security hotspot but you cannot mark it reviewed. Report the assessment and let the user record the decision in Qualimetry.
- A finding whose `Source` is `Dependencies` belongs to the dependency workflow. Report it, do not fix it from here.
- This skill requires **Qualimetry Enterprise**. The analysis tools are not available on Qualimetry AI.

For full MCP tool schemas, response formats, and error handling details, see [reference.md](./reference.md).
