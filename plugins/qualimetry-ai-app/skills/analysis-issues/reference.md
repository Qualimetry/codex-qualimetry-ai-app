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
| `pullRequest` | string | No | The pull-request number/id. Scopes the summary to the pull request's new code instead of the branch. Resolve it with **standard git only** — `git ls-remote origin "refs/pull/*/head" "refs/merge-requests/*/head" "refs/pull-requests/*/from"` and take the ref whose SHA equals the branch's remote head (GitHub / GitLab / Bitbucket Server). Mutually exclusive with `branchName`. |

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
| `pullRequest` | string | No | | The pull-request number/id. Returns the pull request's new-code issues instead of the branch issues. Resolve it with **standard git only** — `git ls-remote origin "refs/pull/*/head" "refs/merge-requests/*/head" "refs/pull-requests/*/from"` and take the number from the ref whose SHA equals the branch's remote head (GitHub / GitLab / Bitbucket Server). Mutually exclusive with `branchName`. |

**Returns:** JSON `AnalysisIssuesResult` object.

### get_rules_based_analysis_security_hotspots

Retrieves the security hotspots raised on a repository branch. Security hotspots are security-sensitive code awaiting a human review decision; they are a separate resource from issues and are never returned by `get_rules_based_analysis_issues`.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `repositoryName` | string | Yes | | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | Yes | | The active Git branch name. Run `git branch --show-current` to obtain the correct value. |
| `status` | string | No | `TO_REVIEW` | Review status filter: `TO_REVIEW` for hotspots still awaiting a decision, `REVIEWED` for those already settled. |
| `vulnerabilityProbability` | string | No | (all) | Filter by review priority: `HIGH`, `MEDIUM`, or `LOW`. |
| `securityCategory` | string | No | (all) | Filter by security category, e.g. `sql-injection`. |
| `filePath` | string | No | (all files) | The full relative file path within the repository, using forward slashes (`/`), including the filename and extension. |
| `page` | int | No | `1` | Page number for paginated results. |
| `pageSize` | int | No | `50` | Number of hotspots per page. Maximum: `500`. |
| `analysisName` | string | No | | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |
| `pullRequest` | string | No | | The pull-request number/id. Returns the pull request's new-code hotspots instead of the branch hotspots. Mutually exclusive with `branchName`. |

**Returns:** JSON `AnalysisSecurityHotspotsResult` object.

### get_rules_based_analysis_security_hotspot

Retrieves a single security hotspot together with the review guidance from the rule that raised it: what the risk is, how it can be exploited, and what a safe implementation looks like.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `repositoryName` | string | Yes | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `hotspotKey` | string | Yes | The `Key` of the hotspot, taken from a `get_rules_based_analysis_security_hotspots` result. |
| `analysisName` | string | No | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |

**Returns:** JSON `AnalysisSecurityHotspotDetail` object.

### get_rules_based_analysis_rules

Retrieves the rules-based analysis rules (rule definitions, not issues) for a language. Returns the same shape as `get_language_coding_standards` but using the analysis engine's own categories.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `languageCode` | string | Yes | | The Qualimetry language code, e.g. `csharp`, `java`, `python`. |
| `qualityProfileName` | string | No | (all rules) | The quality profile name to scope the rules to its active rule set. Leave empty to return every rule available for the language. |

**Returns:** JSON array of `AnalysisRule` objects.

#### Response Schema: AnalysisRule

| Field | Type | Description |
|-------|------|-------------|
| `Key` | string | The analysis-engine rule key, e.g. `csharpsquid:S1234`. |
| `Type` | string | Rule type: `Bug`, `Vulnerability`, `Code Smell`, `Security Hotspot`. |
| `CleanCodeAttributeCategory` | string | `Adaptable`, `Consistent`, `Intentional`, or `Responsible`. Empty when unclassified. |
| `SoftwareQualities` | string | Impacted software qualities, comma-separated. |
| `Tags` | string | Rule tags, comma-separated. |
| `Title` | string | Rule name. |
| `Description` | string | Rich description of what the rule checks and why it matters. |
| `Severity` | string | `High`, `Medium`, or `Low` (profile override applied when a profile is supplied). |

---

## Response Schema: AnalysisIssuesSummary

```json
{
  "Total": 142,
  "Bugs": 23,
  "Vulnerabilities": 8,
  "CodeSmells": 111,
  "BySeverity": {
    "BLOCKER": 2,
    "CRITICAL": 5,
    "MAJOR": 48,
    "MINOR": 61,
    "INFO": 26
  },
  "SecurityHotspots": 14,
  "SecurityHotspotsToReview": 11,
  "SecurityHotspotsReviewed": 3
}
```

| Field | Description |
|-------|-------------|
| `Total` | Total number of issues across all types. Security hotspots are not issues and are not counted here. |
| `Bugs` | Number of issues with type `BUG` |
| `Vulnerabilities` | Number of issues with type `VULNERABILITY` |
| `CodeSmells` | Number of issues with type `CODE_SMELL` |
| `BySeverity` | Breakdown of issue counts by severity level |
| `SecurityHotspots` | Total number of security hotspots on the branch |
| `SecurityHotspotsToReview` | Hotspots still awaiting a human review decision |
| `SecurityHotspotsReviewed` | Hotspots that have already been reviewed |

---

## Response Schema: AnalysisIssuesResult

```json
{
  "Total": 142,
  "Page": 1,
  "PageSize": 50,
  "PageCount": 3,
  "Issues": [
    {
      "Rule": "csharpsquid:S1481",
      "Severity": "MINOR",
      "Type": "CODE_SMELL",
      "Source": "Analysis",
      "FilePath": "src/Services/MyService.cs",
      "StartLine": 42,
      "EndLine": 42,
      "Message": "Remove the unused local variable 'temp'."
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `Total` | Total number of issues matching the filters |
| `Page` | Current page number |
| `PageSize` | Number of issues per page |
| `PageCount` | Total number of pages |
| `Issues` | Array of `AnalysisIssue` objects |

## Response Schema: AnalysisIssue

| Field | Type | Description |
|-------|------|-------------|
| `Rule` | string | Identifies the exact rule violated (e.g., `csharpsquid:S1481`) |
| `Severity` | string | Severity level: `BLOCKER`, `CRITICAL`, `MAJOR`, `MINOR`, or `INFO` |
| `Type` | string | Issue type: `BUG`, `VULNERABILITY`, or `CODE_SMELL` |
| `Source` | string | `Analysis` for a finding raised against the project's own code, `Dependencies` for a known vulnerability in a third-party package. See [Finding Sources](#finding-sources). |
| `FilePath` | string | Relative file path within the repository |
| `StartLine` | int | Line number where the issue starts |
| `EndLine` | int | Line number where the issue ends |
| `Message` | string | Human-readable explanation of the problem |

---

## Response Schema: AnalysisSecurityHotspotsResult

```json
{
  "Total": 14,
  "Page": 1,
  "PageSize": 50,
  "PageCount": 1,
  "Hotspots": [
    {
      "Key": "AY8f2c1bQpR3xK0lVn7a",
      "Rule": "csharpsquid:S2077",
      "Source": "Analysis",
      "SecurityCategory": "sql-injection",
      "VulnerabilityProbability": "HIGH",
      "Status": "TO_REVIEW",
      "Resolution": "",
      "FilePath": "src/Services/MyService.cs",
      "Line": 88,
      "Message": "Make sure using a dynamically formatted SQL query is safe here."
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `Total` | Total number of hotspots matching the filters |
| `Page` | Current page number |
| `PageSize` | Number of hotspots per page |
| `PageCount` | Total number of pages |
| `Hotspots` | Array of `AnalysisSecurityHotspot` objects |

## Response Schema: AnalysisSecurityHotspot

| Field | Type | Description |
|-------|------|-------------|
| `Key` | string | The hotspot's identifier. Pass it as `hotspotKey` to `get_rules_based_analysis_security_hotspot`. |
| `Rule` | string | The rule that raised the hotspot |
| `Source` | string | `Analysis` or `Dependencies`. See [Finding Sources](#finding-sources). |
| `SecurityCategory` | string | The security category, e.g. `sql-injection`. See [Security Categories](#security-categories). |
| `VulnerabilityProbability` | string | Review priority: `HIGH`, `MEDIUM`, or `LOW` |
| `Status` | string | `TO_REVIEW` or `REVIEWED` |
| `Resolution` | string | Set when `Status` is `REVIEWED`: `SAFE`, `FIXED`, or `ACKNOWLEDGED`. Empty while the hotspot is still to review. |
| `FilePath` | string | Relative file path within the repository |
| `Line` | int | Line number of the security-sensitive code |
| `Message` | string | What the reviewer is being asked to confirm |

## Response Schema: AnalysisSecurityHotspotDetail

Everything on `AnalysisSecurityHotspot`, plus the review guidance from the rule:

| Field | Type | Description |
|-------|------|-------------|
| `RuleName` | string | The rule's title |
| `RiskDescription` | string | What can go wrong if the code is not safe |
| `VulnerabilityDescription` | string | How the weakness is exploited |
| `FixRecommendations` | string | What a safe implementation looks like |

---

## Security Hotspots

Security hotspots are security-sensitive pieces of code that need a person to decide whether they are safe in context. They are a separate resource from issues:

- They are never returned by `get_rules_based_analysis_issues`, and they are not counted in the summary's `Total`.
- An agent can read the code, apply the rule's guidance and give an assessment. It cannot mark a hotspot reviewed. Recording the decision is a human action in Qualimetry.

### Hotspot Status

| Value | Description |
|-------|-------------|
| `TO_REVIEW` | No review decision has been recorded yet. This is the default filter. |
| `REVIEWED` | A decision has been recorded; `Resolution` says which. |

### Vulnerability Probability

| Value | Description |
|-------|-------------|
| `HIGH` | Review first; the surrounding code is very likely to be exploitable if it is wrong |
| `MEDIUM` | Review after the high-probability hotspots |
| `LOW` | Review when convenient |

### Security Categories

The category names come from the analysis engine. Common values include `sql-injection`, `command-injection`, `path-traversal-injection`, `ldap-injection`, `xpath-injection`, `insecure-conf`, `auth`, `encryption-of-sensitive-data`, `weak-cryptography`, `dos`, `log-injection`, `ssrf`, `xxe`, `object-injection`, `file-manipulation`, `permission`, `others`. Pass one value at a time to `securityCategory`.

---

## Finding Sources

Both issues and security hotspots carry a `Source`.

| Value | Meaning |
|-------|---------|
| `Analysis` | Raised by the analysis rules against the project's own code. Fix it through this skill. |
| `Dependencies` | A known vulnerability in a third-party package, surfaced through the analysis engine. Report it and hand it to `get_dependency_vulnerabilities`, which knows the package version, the next safe version and whether a suppression already covers it. |

Dependency vulnerabilities can arrive as issues or as security hotspots depending on how the deployment is configured, which is why both carry the field. They are marked, not hidden, because they still count towards the project's quality gate.

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
| Security hotspot tools missing from the server's tool list | The deployment is older than the hotspot tools. Say so in one line, skip the hotspot step, and carry on with the issue workflow. |
| Missing required parameters | `McpException` with parameter name |
| Reporting server not configured | Error message indicating no reporting server is available |
| Git commands fail | Inform the user that git is required and must be initialised in the project |
