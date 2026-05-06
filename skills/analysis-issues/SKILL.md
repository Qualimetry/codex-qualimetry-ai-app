---
name: analysis-issues
description: >
  Retrieves and helps clear rules-based analysis issues (bugs, vulnerabilities,
  code smells) for a repository branch. Prioritises by severity and type, works
  file-by-file or in batch mode. Requires Qualimetry Enterprise.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server (Qualimetry Enterprise) and git to be configured.
allowed-tools: get_rules_based_analysis_issues_summary get_rules_based_analysis_issues
metadata:
  author: qualimetry
  version: "1.1"
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

## Step 2: Triage

Call `get_rules_based_analysis_issues_summary` with:
- `repositoryName` - from Step 1
- `branchName` - from Step 1

This returns total counts broken down by issue type (bugs, vulnerabilities, code smells) and by severity (BLOCKER, CRITICAL, MAJOR, MINOR, INFO).

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

## Important

- Always use `git branch --show-current` to get the branch name. Do not assume `main` or `master`.
- File paths must use forward slashes, even on Windows.
- This skill requires **Qualimetry Enterprise**. The analysis tools are not available on Qualimetry AI.

For full MCP tool schemas, response formats, and error handling details, see [reference.md](./reference.md).
