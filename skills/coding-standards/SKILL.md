---
name: coding-standards
description: >
  Automatically loads and enforces the organisation's coding standards, general
  coding principles, secure coding principles, and policies for the programming
  language of the file being developed. Retrieves all applicable standards from
  the Qualimetry MCP server and applies them when writing, modifying, or
  reviewing source code. Activated whenever source code is being created or
  edited, or invoked manually as the coding-standards skill with an optional
  language code argument.
license: Apache-2.0
compatibility: Requires the Qualimetry MCP server to be configured in the AI tool.
allowed-tools: get_language_coding_standards get_general_principles get_secure_principles get_policies
metadata:
  author: qualimetry
  version: "1.0"
  homepage: https://qualimetry.com
---

# Coding Standards Enforcement

When writing, modifying, or reviewing source code, follow this workflow to ensure all code complies with the organisation's coding standards.

## Step 1: Detect the Language

Determine the language code from the file extension of the file being worked on. Use the conventional lowercase language name (e.g., `java`, `python`, `typescript`, `csharp`, `cpp`). For C#, use `csharp`. For C++, use `cpp`.

If invoked with an argument (e.g. `coding-standards python`), use that as the language code directly.

## Step 2: Fetch All Applicable Standards

Call the following Qualimetry MCP tools to retrieve the full set of standards for this language. Make all calls in parallel where possible.

1. **Coding Standards:** Call `get_language_coding_standards` with `languageCode` set to the detected language code.
2. **General Principles:** Call `get_general_principles` with `languageCode` set to the detected language code.
3. **Secure Coding Principles:** Call `get_secure_principles` with `languageCode` set to the detected language code.
4. **Organisation Policies:** Call `get_policies` (no parameters required).

Each tool returns a JSON array of standards/principles. Each item has:
- `MajorCategory` - top-level category (e.g., Naming, Security, Maintainability)
- `MinorCategory` - sub-category (e.g., Variable Naming, Exception Handling)
- `Title` - short name of the standard
- `Description` - detailed explanation
- `Severity` - High, Medium, or Low

## Step 3: Apply Standards to Code

Apply all retrieved standards to the code being written or modified:

- **High severity:** Must be followed without exception. Violations must be corrected before presenting code.
- **Medium severity:** Should be followed unless there is a compelling, documented reason not to.
- **Low severity:** Recommended best practice. Apply where practical.

When correcting code or making suggestions, reference the specific standard by its **Title** so the developer knows which standard applies.

## Important

- Do NOT output the full list of standards to the user. Apply them silently to the code you produce.
- Always use the latest standards from the MCP server. Do not rely on previously cached standards.
- If a Qualimetry MCP tool is not available (e.g., the server is not configured), skip that tool and proceed with whatever standards were successfully retrieved.
- If no standards could be retrieved at all, inform the user that the Qualimetry MCP server may not be configured and proceed without standards enforcement.
- On Qualimetry Enterprise, you can also use `get_rules_based_analysis_issues`
  with `issueType=CODE_SMELL` and a `filePath` to check for existing code
  smells in the file being worked on.

For full MCP tool schemas, response formats, and error handling details, see [reference.md](./reference.md).
