# Review Check Reference

## MCP Tools

### get_all_review_issues (preferred)

Retrieves all review issue types for a file in a single call.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `repositoryName` | string | Yes | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | Yes | Current branch (from `git branch --show-current`) |
| `filePath` | string | Yes | Relative directory path with forward slashes and trailing `/`. Empty string for root files. |
| `fileName` | string | Yes | Filename with extension |
| `analysisName` | string | No | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. **Qualimetry Enterprise only.** |

**Returns:** JSON array of `CodeReviewIssue` objects with `ReviewType` populated.

### Individual Review Tools (fallback)

If `get_all_review_issues` is unavailable, call each tool individually with the same parameters:

| Tool | Review Type | Description |
|------|-------------|-------------|
| `get_coding_standards_review_issues` | CodingStandards | Language-specific coding standard violations |
| `get_design_best_practice_review_issues` | DesignBestPractices | Design pattern and best practice issues |
| `get_general_principles_review_issues` | GeneralPrinciples | General coding principle violations |
| `get_secure_principles_review_issues` | SecurePrinciples | Secure coding principle violations |
| `get_policies_review_issues` | Policies | Organisation policy violations |

### get_standards_compliant_example

Retrieves a compliant code example showing how to resolve the issues found. This tool must be enabled by an organisation administrator in the AI Settings page. If it has not been enabled, the tool returns a message stating so.

**Parameters:** Same parameters as above (`repositoryName`, `branchName`, `filePath`, `fileName`, and optional `analysisName`).

**Returns:** A string containing the compliant code example, or a message indicating the feature is not enabled.

---

## Response Schema: CodeReviewIssue

```json
{
  "CreatedDateTime": "2026-03-10T14:30:00Z",
  "MajorCategory": "string",
  "MinorCategory": "string",
  "Explanation": "string",
  "SuggestedRemedy": "string",
  "IsPullRequestIssue": true,
  "Severity": "High | Medium | Low",
  "ReviewType": "string"
}
```

| Field | Description |
|-------|-------------|
| `CreatedDateTime` | UTC timestamp when the issue was created |
| `MajorCategory` | Top-level classification (e.g., Security, Maintainability, Performance) |
| `MinorCategory` | Specific rule or subcategory |
| `Explanation` | Detailed description of the violation |
| `SuggestedRemedy` | Suggested fix or improvement |
| `IsPullRequestIssue` | `true` if found on a line altered in the most recent pull request review |
| `Severity` | `High`, `Medium`, or `Low` |
| `ReviewType` | Review category: `CodingStandards`, `DesignBestPractices`, `GeneralPrinciples`, `SecurePrinciples`, or `Policies`. Only populated by `get_all_review_issues`. |

---

## File Path Splitting Rules

The `filePath` and `fileName` parameters must follow these conventions:

1. Paths are **relative to the repository root**, not absolute
2. Use **forward slashes** (`/`), even on Windows
3. `filePath` is the **directory portion only**, with a **trailing slash**
4. `fileName` is just the **filename with extension**
5. For files at the repository root, `filePath` is an **empty string**

### Examples

| Full Relative Path | `filePath` | `fileName` |
|-------------------|------------|------------|
| `src/Services/MyService.cs` | `src/Services/` | `MyService.cs` |
| `Program.cs` | `` (empty) | `Program.cs` |
| `tests/unit/TestHelper.java` | `tests/unit/` | `TestHelper.java` |
| `src/main/java/com/example/App.java` | `src/main/java/com/example/` | `App.java` |
| `Controllers/Api/UserController.cs` | `Controllers/Api/` | `UserController.cs` |

---

## Presentation Format

Present issues to the user using this structure:

```
## Review Issues for `<fileName>`

### Coding Standards (N issues)

**[High]** MajorCategory > MinorCategory
Explanation text here.
**Remedy:** Suggested remedy text.

**[Medium]** MajorCategory > MinorCategory
...

### Design Best Practices (N issues)
...

### General Principles (N issues)
...

### Secure Principles (N issues)
...

### Policies (N issues)
...

## Compliant Code Example
<compliant code example here>
```

- Group by **ReviewType** in the order shown above
- Within each group, order by **severity**: High first, then Medium, then Low
- Only show groups that have issues
- Always call `get_standards_compliant_example` if any issues were found. If the tool returns a message that the feature is not enabled, present the issues without the example and relay the message to the user.

---

## Review Types

| Review Type | What It Checks |
|-------------|----------------|
| **CodingStandards** | Violations of language-specific coding standards (naming, formatting, structure) |
| **DesignBestPractices** | Design pattern issues, architectural anti-patterns, industry best practices |
| **GeneralPrinciples** | General coding principles (DRY, SOLID, clean code, readability) |
| **SecurePrinciples** | Security vulnerabilities and secure coding practice violations (OWASP, input validation) |
| **Policies** | Organisation-specific policy violations (custom rules, compliance requirements) |

---

## Error Handling

| Scenario | Action |
|----------|--------|
| No review found for the file | Inform the user: "No Qualimetry code review found for this file on this branch. The file may not have been reviewed yet." |
| MCP tool unavailable | Inform the user that the Qualimetry MCP server may not be configured |
| Git commands fail | Inform the user that git is required and must be initialised in the project |
| `get_all_review_issues` unavailable | Fall back to calling the five individual review tools |
| Compliant example unavailable | Present the issues without the example; note that no compliant example is available |
| Compliant example not enabled | The tool returns a message that the feature must be enabled by an organisation administrator. Relay this message to the user. |
