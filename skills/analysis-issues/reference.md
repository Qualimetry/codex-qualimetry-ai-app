# Analysis Issues Reference

## MCP Tools

### get_rules_based_analysis_issues_summary

Retrieves a summary of all rules-based analysis issues for a repository branch, returning total counts broken down by issue type (bugs, vulnerabilities, code smells) and by severity.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `repositoryName` | string | Yes | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | Yes | The active Git branch name. Run `git branch --show-current` to obtain the correct value. |
| `analysisName` | string | No | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |

**Returns:** JSON `AnalysisIssuesSummary` object.

### get_rules_based_analysis_issues

Retrieves rules-based analysis issues (bugs, vulnerabilities, code smells) for a repository branch, with optional filtering by issue type, severity, and file path. Returns paginated results with the detail needed to locate and fix each issue.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `repositoryName` | string | Yes | | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | Yes | | The active Git branch name. Run `git branch --show-current` to obtain the correct value. |
| `issueType` | string | No | `ALL` | Filter by issue type. Accepted values: `ALL`, `BUG`, `VULNERABILITY`, `CODE_SMELL`, or comma-separated combination (e.g., `BUG,VULNERABILITY`). |
| `severities` | string | No | (all) | Comma-separated severity filter, e.g., `BLOCKER,CRITICAL`. |
| `filePath` | string | No | (all files) | The full relative file path within the repository, using forward slashes (`/`), including the filename and extension. Example: `src/Services/MyService.cs`. This is a single complete path, not just the directory. Leave empty to return issues across all files. |
| `page` | int | No | `1` | Page number for paginated results. |
| `pageSize` | int | No | `50` | Number of issues per page. Maximum: `500`. |
| `analysisName` | string | No | | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |

**Returns:** JSON `AnalysisIssuesResult` object.

---

## Response Schema: AnalysisIssuesSummary

```json
{
  "total": 142,
  "bugs": 23,
  "vulnerabilities": 8,
  "codeSmells": 111,
  "bySeverity": {
    "BLOCKER": 2,
    "CRITICAL": 5,
    "MAJOR": 48,
    "MINOR": 61,
    "INFO": 26
  }
}
```

| Field | Description |
|-------|-------------|
| `total` | Total number of issues across all types |
| `bugs` | Number of issues with type `BUG` |
| `vulnerabilities` | Number of issues with type `VULNERABILITY` |
| `codeSmells` | Number of issues with type `CODE_SMELL` |
| `bySeverity` | Breakdown of issue counts by severity level |

---

## Response Schema: AnalysisIssuesResult

```json
{
  "total": 142,
  "page": 1,
  "pageSize": 50,
  "pageCount": 3,
  "issues": [
    {
      "rule": "csharpsquid:S1481",
      "severity": "MINOR",
      "type": "CODE_SMELL",
      "filePath": "src/Services/MyService.cs",
      "startLine": 42,
      "endLine": 42,
      "message": "Remove the unused local variable 'temp'."
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `total` | Total number of issues matching the filters |
| `page` | Current page number |
| `pageSize` | Number of issues per page |
| `pageCount` | Total number of pages |
| `issues` | Array of `AnalysisIssue` objects |

## Response Schema: AnalysisIssue

| Field | Type | Description |
|-------|------|-------------|
| `rule` | string | Identifies the exact rule violated (e.g., `csharpsquid:S1481`) |
| `severity` | string | Severity level: `BLOCKER`, `CRITICAL`, `MAJOR`, `MINOR`, or `INFO` |
| `type` | string | Issue type: `BUG`, `VULNERABILITY`, or `CODE_SMELL` |
| `filePath` | string | Relative file path within the repository |
| `startLine` | int | Line number where the issue starts |
| `endLine` | int | Line number where the issue ends |
| `message` | string | Human-readable explanation of the problem |

---

## Issue Types

| Value | Description |
|-------|-------------|
| `BUG` | A coding error that will likely result in incorrect behaviour at runtime |
| `VULNERABILITY` | A security weakness that could be exploited |
| `CODE_SMELL` | A maintainability issue that makes the code harder to understand or change |

## Severity Levels

| Value | Priority | Description |
|-------|----------|-------------|
| `BLOCKER` | 1 (highest) | Must be fixed immediately; blocks production readiness |
| `CRITICAL` | 2 | Serious issue that should be fixed before release |
| `MAJOR` | 3 | Significant issue that should be addressed |
| `MINOR` | 4 | Minor issue worth fixing when convenient |
| `INFO` | 5 (lowest) | Informational finding, fix at your discretion |

---

## Pagination

- Default page size is 50 issues, maximum is 500.
- The response includes `total`, `page`, `pageSize`, and `pageCount` to support pagination.
- Increment `page` to retrieve subsequent pages.
- At 50 issues per page with a slim DTO (~300 bytes each), each response is approximately 15 KB.

---

## Error Handling

| Scenario | Response |
|----------|----------|
| No analysis project found | Error message: "No analysis project found for this repository and branch." |
| Multiple analysis projects (mono-repo) | Error message prompting the client to provide the `analysisName` parameter to disambiguate. |
| Qualimetry AI mode (not Enterprise) | Error message: "Rules-based analysis issues are only available on Qualimetry Enterprise." |
| Missing required parameters | `McpException` with parameter name |
| Reporting server not configured | Error message indicating no reporting server is available |
| Git commands fail | Inform the user that git is required and must be initialised in the project |
