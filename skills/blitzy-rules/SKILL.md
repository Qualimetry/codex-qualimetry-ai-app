---
name: blitzy-rules
description: >
  Generates Blitzy rules packs from the organisation's Qualimetry coding
  standards (policies, principles, language coding standards) and, on
  Qualimetry Enterprise, from the rules-based analysis rule set. Each pack is a
  single JSON object with machine-readable rules for API push and path/content
  file pairs that mirror a Blitzy rules zip a client can write to disk or a
  repository. Invoke manually as the blitzy-rules skill.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server to be configured in the AI tool.
allowed-tools: get_coding_standards_blitzy get_rules_based_analysis_rules_blitzy
metadata:
  author: qualimetry
  version: "1.1"
  homepage: https://qualimetry.com
---

# Blitzy Rules Packs

When asked to produce Blitzy rules for a project so that Blitzy generates code compliant with the organisation's standards, follow this workflow.

## Step 1: Choose the Pack

- **Coding standards pack** (both Qualimetry AI and Enterprise): policies, coding principles, and language coding standards. Use `get_coding_standards_blitzy`.
- **Analysis rules pack** (Qualimetry Enterprise only): the rules-based analysis rule set for a language. Use `get_rules_based_analysis_rules_blitzy`.

## Step 2: Fetch the Pack

**Coding standards:** Call `get_coding_standards_blitzy`. Returns policies and principles by default; pass `languageCodes` to add language coding standards. Narrow with:
- `includePolicies` (default true)
- `includePrinciples` (default true)
- `languageCodes` - comma-separated codes (e.g. `csharp,java,python`) for the project's language(s). Required to receive language coding standards; if omitted, only policies and principles are returned. Pass the project's primary language(s) so the pack carries the relevant language rules.
- `collapseLanguageFolders` (default true) - one folder per language with `{category}--{subcategory}.rule.md` filenames; set false to nest categories as folders

**Analysis rules:** Call `get_rules_based_analysis_rules_blitzy` with:
- `languageCode` (required, e.g. `csharp`)
- `qualityProfileName` (optional; blank returns every rule for the language)
- `collapseLanguageFolders` (default true) - one folder per language with `{type}--{attribute}.rule.md` filenames

## Step 3: Write the Pack

Both tools return one JSON object:
- `license` - the proprietary licence notice (coding-standards pack only). Preserve it; it is also written as `LICENSE.md` in `files`.
- `rules` - the structured rules for API-based publishing to a Blitzy endpoint.
- `files` - an array of `{ path, content }` pairs that mirror the zip tree. Write each file verbatim to disk (or to the target repository) at its `path`, preserving the directory structure.

If asked to "write the pack to disk", iterate `files` and create each file at `path` with its `content`. Do not modify the content.

## Important

- The analysis rules pack requires **Qualimetry Enterprise**; on Qualimetry AI only `get_coding_standards_blitzy` is available.
- Always fetch fresh from the MCP server; do not reuse a previously generated pack.

For full MCP tool schemas and pack structure, see [reference.md](./reference.md).
