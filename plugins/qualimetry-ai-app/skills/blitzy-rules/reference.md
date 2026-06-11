# Blitzy Rules Reference

## MCP Tools

### get_coding_standards_blitzy

Returns the Qualimetry coding standards (policies, principles, and language coding standards) as a Blitzy rules pack. Available on both Qualimetry AI and Enterprise. Policies and principles are included by default; language coding standards are returned only for the codes passed in `languageCodes`.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `includePolicies` | bool | No | `true` | Include organisation policies (one rule per policy category). |
| `includePrinciples` | bool | No | `true` | Include coding principles (one rule per principle category, e.g. Architecture, General Coding, Secure Coding). |
| `languageCodes` | string | No | (none) | Comma-separated language codes to include (e.g. `csharp,java,python`). Required to receive language coding standards; if omitted, no language standards are returned (policies and principles only). |
| `collapseLanguageFolders` | bool | No | `true` | When true, each language's rules sit in one folder, files named `{category}--{subcategory}.rule.md`. When false, categories become nested folders mirroring the Standards Center tree. |

**Returns:** JSON `BlitzyPack` object.

### get_rules_based_analysis_rules_blitzy

Returns the rules-based analysis rule set for a language as a Blitzy rules pack. Rules are grouped by analysis type and clean-code attribute category. **Qualimetry Enterprise only.**

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `languageCode` | string | Yes | | The Qualimetry language code, e.g. `csharp`, `java`, `python`. |
| `qualityProfileName` | string | No | (all rules) | The quality profile name to scope the rules to its active rule set. Leave empty to return every rule available for the language. |
| `collapseLanguageFolders` | bool | No | `true` | When true, files are named `{type}--{attribute}.rule.md` in one folder per language. When false, types become nested folders. |

**Returns:** JSON `BlitzyPack` object.

---

## Response Schema: BlitzyPack

```json
{
  "license": "Copyright (c) ... All rights reserved. ...",
  "rules": [
    {
      "name": "Qualimetry Policy: Error Handling",
      "appliesTo": ["all"],
      "description": "OBJECTIVE: ...\n\nIN SCOPE (exhaustive):\n- ...",
      "path": "rules/policies/error-handling.rule.md"
    }
  ],
  "files": [
    { "path": "README.md", "content": "# Qualimetry Blitzy Rules Pack ..." },
    { "path": "LICENSE.md", "content": "Copyright (c) ... All rights reserved. ..." },
    { "path": "blitzy-rules.json", "content": "[ ... ]" },
    { "path": "rules/policies/error-handling.rule.md", "content": "..." }
  ]
}
```

| Field | Description |
|-------|-------------|
| `license` | The proprietary licence notice. Present on coding-standards packs (`get_coding_standards_blitzy`); omitted from the analysis-rules pack. Same text as `LICENSE.md`. |
| `rules` | Structured rule entries for API-based publishing. Each has `name`, `appliesTo`, `description`, `path`. |
| `files` | `{ path, content }` pairs mirroring the zip tree. Write each verbatim to reproduce the pack on disk or in a repository. |

### Rule Entry

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | The rule's display name. |
| `appliesTo` | array | Language codes the rule applies to, or `["all"]`. |
| `description` | string | The imperative rule body (objective, in-scope list, constraints, validation gate). |
| `path` | string | The rule file's path within the pack. |

---

## Pack Paths

- Coding standards: `rules/policies/`, `rules/principles/`, `rules/languages/{language}/...`, plus `rules/qualimetry-compliance.rule.md`.
- Analysis rules: `rules/analysis/{language}/...`.
- Every pack also carries `README.md` and `blitzy-rules.json` (machine-readable form of all rules).
- Coding-standards packs also carry `LICENSE.md` - a proprietary notice reserving all rights to the customer organisation and Shazam Analytics Ltd. The standards are licensed solely for generating, reviewing and analysing the customer's code; write the file verbatim with the rest of the pack and do not strip it.

---

## Error Handling

| Scenario | Response |
|----------|----------|
| Qualimetry AI mode for the analysis pack | Error message: "Rules-based analysis rules are only available on Qualimetry Enterprise." |
| Unsupported language code | Error message naming the unsupported code. |
| No quality profile found | Error message naming the profile and language. |
| Reporting server not configured | Error message indicating no reporting server is available. |
