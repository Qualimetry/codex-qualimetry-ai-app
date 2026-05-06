---
name: review-check
description: >
  Checks for all types of code review issues found by the Qualimetry HITL code
  reviewer on a source file, including coding standards violations, design and
  best practice issues, general coding principle violations, secure coding
  principle violations, and policy violations. Retrieves a compliant code
  example showing how to resolve the issues. Invoked as the review-check skill,
  optionally with a file path argument, to check a previously reviewed file.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server and git to be configured.
allowed-tools: get_all_review_issues get_coding_standards_review_issues get_design_best_practice_review_issues get_general_principles_review_issues get_secure_principles_review_issues get_policies_review_issues get_standards_compliant_example
metadata:
  author: qualimetry
  version: "1.1"
  homepage: https://qualimetry.com
---

# Review Issues Check

When working with a source file that may have been previously reviewed by Qualimetry, follow this workflow to retrieve and present any review issues found.

## Step 1: Determine the Target File

Identify the file to check:
- If invoked with an argument (e.g. `review-check src/MyService.cs`), use that file path.
- Otherwise, use the file currently being discussed or edited in the conversation.

## Step 2: Gather Repository Information

Determine the `repositoryName` and `branchName`:

**`repositoryName`** — the repository name in `owner/repo-name` format (e.g., `organisation/my-project`). The server is case-insensitive and handles `.git` suffixes automatically.

**`analysisName`** *(optional, Qualimetry Enterprise only)* — if the repository is a mono-repo with multiple analysis projects, provide the analysis project name to disambiguate. Case-insensitive. Leave empty for single-project repositories. If omitted and multiple projects are found, the server returns an error listing the available analysis names.

**`branchName`** — run this shell command:

```bash
git branch --show-current
```
This returns the branch name (e.g., `main`, `develop`, `feature/login-page`).

## Step 3: Split the File Path

Split the file's path relative to the repository root into two parts:

- **`filePath`**: The directory portion, using forward slashes (`/`), with a trailing slash. Example: `src/main/java/com/example/`
- **`fileName`**: Just the filename with extension. Example: `Main.java`

Rules:
- Convert backslashes to forward slashes.
- The path must be relative to the repository root, not an absolute path.
- If the file is at the repository root, `filePath` should be an empty string.

Examples:
| Full relative path | `filePath` | `fileName` |
|-------------------|------------|------------|
| `src/Services/MyService.cs` | `src/Services/` | `MyService.cs` |
| `Program.cs` | `` | `Program.cs` |
| `tests/unit/TestHelper.java` | `tests/unit/` | `TestHelper.java` |

## Step 4: Retrieve Review Issues

Call the Qualimetry MCP tool `get_all_review_issues` with these parameters:
- `repositoryName` - from Step 2
- `branchName` - from Step 2
- `filePath` - from Step 3
- `fileName` - from Step 3

This single call returns all review issue types (coding standards, design best practices, general principles, secure principles, and policy violations).

**Fallback:** If `get_all_review_issues` is not available, call each tool individually and merge the results:
1. `get_coding_standards_review_issues`
2. `get_design_best_practice_review_issues`
3. `get_general_principles_review_issues`
4. `get_secure_principles_review_issues`
5. `get_policies_review_issues`

All tools take the same four parameters.

## Step 5: Present the Issues

If issues were found, present them to the user:

1. **Group by review type** (e.g., Coding Standards, Design Best Practices, General Principles, Secure Principles, Policies).
2. **Within each group, order by severity** (High first, then Medium, then Low).
3. **For each issue, show:**
   - Severity (High / Medium / Low)
   - Major Category and Minor Category
   - Explanation of the issue
   - Suggested Remedy

## Step 6: Retrieve Compliant Code Example

If issues were found, also call `get_standards_compliant_example` with the same four parameters (`repositoryName`, `branchName`, `filePath`, `fileName`).

This tool requires an organisation administrator to enable it in the AI Settings page. If the tool returns a message indicating the feature is not enabled, present the review issues without the example and relay the message to the user.

Present the compliant code example as a reference showing how the issues could be resolved. Note that this example should be carefully reviewed - it is a suggestion, not necessarily the final solution.

## Step 7: Handle No Results

- If no review was found for the file, inform the user: "No Qualimetry code review found for this file on this branch. The file may not have been reviewed yet."
- If a Qualimetry MCP tool is not available, inform the user that the Qualimetry MCP server may not be configured.

## Important

- Always use `git branch --show-current` to get the branch name. Do not assume `main` or `master`.
- File paths must use forward slashes, even on Windows.
- The `filePath` parameter must include a trailing slash if non-empty.

## Related: Rules-Based Analysis Issues (Qualimetry Enterprise)

On Qualimetry Enterprise, additional tools are available for retrieving live
rules-based analysis issues (bugs, vulnerabilities, code smells) for a
repository branch. These are distinct from the HITL code review issues
retrieved by this skill:

- `get_rules_based_analysis_issues_summary` -- total counts by type and severity
- `get_rules_based_analysis_issues` -- paginated issues with filtering

See the `analysis-issues` skill for the full workflow.

For full MCP tool schemas, response formats, file path splitting rules, and presentation templates, see [reference.md](./reference.md).
