# Coding Standards Reference

## MCP Tools

### get_language_coding_standards

Retrieves language-specific coding standards.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `languageCode` | string | Yes | Conventional lowercase language name derived from the file extension (e.g., `java`, `csharp`, `typescript`, `python`, `cpp`). Use `csharp` for C# and `cpp` for C++. |

**Returns:** JSON array of `CodingStandard` objects.

### get_general_principles

Retrieves general coding principles for a language.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `languageCode` | string | Yes | Same convention as above |

**Returns:** JSON array of `CodingStandard` objects.

### get_secure_principles

Retrieves secure coding principles for a language.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `languageCode` | string | Yes | Same convention as above |

**Returns:** JSON array of `CodingStandard` objects.

### get_policies

Retrieves all organisation-wide coding policies.

**Parameters:** None.

**Returns:** JSON array of `CodingStandard` objects.

---

## Response Schema: CodingStandard

All four tools return JSON arrays of objects with this structure:

```json
{
  "MajorCategory": "string",
  "MinorCategory": "string",
  "Title": "string",
  "Description": "string",
  "Severity": "High | Medium | Low"
}
```

| Field | Description |
|-------|-------------|
| `MajorCategory` | Top-level classification (e.g., Naming, Maintainability, Security, Performance) |
| `MinorCategory` | Specific rule or subcategory (e.g., Variable Naming, Exception Handling) |
| `Title` | Short name of the standard (e.g., "Avoid magic numbers") |
| `Description` | Detailed explanation including intent and rationale |
| `Severity` | `High`, `Medium`, or `Low` |

---

## Severity Enforcement Rules

| Severity | Enforcement |
|----------|-------------|
| **High** | Must be followed without exception. Violations must be corrected before presenting code to the user. |
| **Medium** | Should be followed unless there is a compelling, documented reason not to. |
| **Low** | Recommended best practice. Apply where practical without over-engineering. |

When correcting code, reference the standard by its **Title** so the developer can look it up.

---

## Error Handling

| Scenario | Action |
|----------|--------|
| MCP tool returns an error | Skip that standard type; proceed with whatever was successfully retrieved |
| MCP server not configured | Inform the user that the Qualimetry MCP server is not available |
| Unknown file extension | If invoked manually with a language code argument, use that; otherwise inform the user the language is not supported |
| Empty standards array returned | Proceed normally; no standards to enforce for that type |
