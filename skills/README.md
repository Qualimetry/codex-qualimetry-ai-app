# Qualimetry AI Skills

Agent Skills that integrate with the [Qualimetry.com](https://www.qualimetry.com) or [Qualimetry.ai](https://www.qualimetry.ai) Review Services to automatically enforce Enterprise Coding Policies, 
General Coding Principles, Secure Coding Principles and Language Coding Standards for all major languages.  Agent Skills also pull code review policy, principles and language issues into your favourite Agentic Engineering coding tools.

Built on the open [Agent Skills](https://agentskills.io) standard. Works with Claude Code, Cursor, VS Code / GitHub Copilot, OpenAI Codex, Windsurf, and any tool that supports the Agent Skills specification.

## Skills Included

### `coding-standards`

Automatically loads and enforces your organisation's coding standards when writing or modifying source code. Retrieves four types of standards from the Qualimetry MCP server:

- **Coding Standards** - language-specific coding standards
- **General Principles** - general coding principles
- **Secure Principles** - secure coding principles
- **Policies** - organisation-wide policies

The agent applies these standards silently to all code it produces. Supports all major coding languages including TypeScript, Python, C#, Java, JavaScript, Swift, Kotlin, Rust and C/C++.

**Usage:** Automatically activated when writing code, or invoke manually with `/coding-standards` or `/coding-standards <language-code>`.

### `review-check`

Checks for code review issues found by the Qualimetry HITL Code Reviewer on a source file. Retrieves all issue types:

- Coding standards violations
- Design and best practice issues
- General coding principle violations
- Secure coding principle violations
- Policy violations

Presents issues grouped by type and severity, and retrieves a compliant code example showing how to resolve them. The compliant code example tool must be enabled by an organisation administrator in the AI Settings page.

**Usage:** Invoke with `/review-check` (uses current file) or `/review-check <file-path>`.

### `analysis-issues`

Retrieves and helps clear rules-based analysis issues (bugs, vulnerabilities, code smells) for a repository branch. Prioritises by severity and type, works file-by-file or in batch mode.

*Requires Qualimetry Enterprise.*

**Usage:** Invoke with `/analysis-issues` to triage and clear analysis issues on the current branch.

### `dependency-check`

Retrieves dependency vulnerabilities for a repository branch and resolves them by upgrading each vulnerable dependency to its next safe version. Each vulnerability is returned with inline upgrade advice (next safe version, latest version, upgrade risk, deprecation status), eliminating the need for a separate lookup per dependency in most cases. Works through four phases:

1. **Assess** - fetches all dependency CVE vulnerabilities with inline upgrade advice from the latest analysis
2. **Locate Manifests** - finds the relevant dependency manifest files in the workspace
3. **Resolve** - processes each vulnerability by risk score using the inline upgrade data, auto-upgrading low-risk and proposing medium/high-risk upgrades
4. **Validate** - runs package restore and build to verify no regressions

*Requires Qualimetry Enterprise.*

**Usage:** Invoke with `/dependency-check` to assess and clear dependency vulnerabilities on the current branch.

## Product Availability

The `coding-standards` and `review-check` skills work with both **Qualimetry AI** and **Qualimetry Enterprise**. The `analysis-issues` and `dependency-check` skills and their MCP tools require **Qualimetry Enterprise**.

### Mono-repo Support (Qualimetry Enterprise)

On Qualimetry Enterprise, if a repository has multiple analysis projects (mono-repo), all tools that accept `repositoryName` also accept an optional `analysisName` parameter. This is the analysis project name (case-insensitive) used to disambiguate which project's data to return. If omitted and multiple projects exist, the server returns an error prompting the client to provide the analysis name. On Qualimetry AI, this parameter is not available.

## Prerequisites

1. **Qualimetry Review Service** - access to a running instance with MCP enabled
2. **Access Token** - a valid Qualimetry MCP access token
3. **MCP Server Configured** - the Qualimetry MCP server must be registered in your AI tool (see setup below)
4. **Git** - the `review-check`, `analysis-issues`, and `dependency-check` skills require git to determine the current branch name
5. **Qualimetry Enterprise** (for `analysis-issues` and `dependency-check`) - the analysis and dependency tools require a Qualimetry Enterprise deployment with MCP enabled

## Installation

### Global Installation (All Repos)

Copy the skill directories to your user-level skills folder. This makes the skills available in every project.

```bash
git clone https://github.com/<org>/qualimetry-ai-skills.git /tmp/qualimetry-ai-skills
mkdir -p ~/.agents/skills
cp -r /tmp/qualimetry-ai-skills/coding-standards ~/.agents/skills/
cp -r /tmp/qualimetry-ai-skills/review-check ~/.agents/skills/
cp -r /tmp/qualimetry-ai-skills/analysis-issues ~/.agents/skills/
cp -r /tmp/qualimetry-ai-skills/dependency-check ~/.agents/skills/
```

The `~/.agents/skills/` path is the universal location, discovered by all tools. Tool-specific alternatives:

| Tool | Alternative Path |
|------|-----------------|
| Claude Code | `~/.claude/skills/` |
| Cursor | `~/.cursor/skills/` |
| OpenAI Codex | `~/.codex/skills/` |

### Per-Repo Installation (Shared via Git)

Copy the skills into your repository so all team members get them automatically.

```bash
git clone https://github.com/<org>/qualimetry-ai-skills.git /tmp/qualimetry-ai-skills
mkdir -p .agents/skills
cp -r /tmp/qualimetry-ai-skills/coding-standards .agents/skills/
cp -r /tmp/qualimetry-ai-skills/review-check .agents/skills/
cp -r /tmp/qualimetry-ai-skills/analysis-issues .agents/skills/
cp -r /tmp/qualimetry-ai-skills/dependency-check .agents/skills/
git add .agents/skills
git commit -m "Add Qualimetry coding standards skills"
```

## MCP Server Setup

The skills communicate with the Qualimetry Review Service through MCP. You must configure the MCP server in your AI tool.

### Claude Code

```bash
claude mcp add Qualimetry \
  --transport http \
  --url https://<your-qualimetry-server>/mcp \
  --header "qualimetry-access-token: <your-token>"
```

### Cursor

1. Open **Settings** > **MCP Servers**
2. Add a new server:
   - **Name:** `Qualimetry`
   - **URL:** `https://<your-qualimetry-server>/mcp`
   - **Headers:** `qualimetry-access-token: <your-token>`

### VS Code / GitHub Copilot

Add to your VS Code settings or workspace `.vscode/settings.json`:

```json
{
  "mcp": {
    "servers": {
      "Qualimetry": {
        "url": "https://<your-qualimetry-server>/mcp",
        "headers": {
          "qualimetry-access-token": "<your-token>"
        }
      }
    }
  }
}
```

### OpenAI Codex

Add to your Codex MCP configuration:

```json
{
  "mcpServers": {
    "Qualimetry": {
      "url": "https://<your-qualimetry-server>/mcp",
      "headers": {
        "qualimetry-access-token": "<your-token>"
      }
    }
  }
}
```

## Verifying Installation

1. **Check skills are discovered:** Start your AI tool and look for `coding-standards` and `review-check` in the available skills/commands.

2. **Test coding-standards:** Ask the agent to write a simple function in any supported language. It should automatically fetch and apply coding standards.

3. **Test review-check:** Run `/review-check <path-to-reviewed-file>` on a file that has been reviewed by Qualimetry. You should see issues grouped by type and severity.

4. **Test MCP connection:** If skills report that the Qualimetry MCP server is not available, verify your MCP server configuration and access token.

5. **Test analysis-issues:** Run `/analysis-issues` in a repository that has been analysed on Qualimetry Enterprise. You should see a summary of issues by type and severity.

6. **Test dependency-check:** Run `/dependency-check` in a repository that has been analysed on Qualimetry Enterprise. You should see a list of vulnerable dependencies with CVE details and upgrade advice.

## MCP Tools Used

These skills use the following Qualimetry MCP tools:

| Tool | Used By | Purpose | Availability |
|------|---------|---------|--------------|
| `get_language_coding_standards` | coding-standards | Fetch coding standards for a language | Qualimetry AI & Enterprise |
| `get_general_principles` | coding-standards | Fetch general coding principles for a language | Qualimetry AI & Enterprise |
| `get_secure_principles` | coding-standards | Fetch secure coding principles for a language | Qualimetry AI & Enterprise |
| `get_policies` | coding-standards | Fetch organisation-wide policies | Qualimetry AI & Enterprise |
| `get_all_review_issues` | review-check | Fetch all review issues for a file | Qualimetry AI & Enterprise |
| `get_coding_standards_review_issues` | review-check (fallback) | Fetch coding standards issues | Qualimetry AI & Enterprise |
| `get_design_best_practice_review_issues` | review-check (fallback) | Fetch design best practice issues | Qualimetry AI & Enterprise |
| `get_general_principles_review_issues` | review-check (fallback) | Fetch general principles issues | Qualimetry AI & Enterprise |
| `get_secure_principles_review_issues` | review-check (fallback) | Fetch secure principles issues | Qualimetry AI & Enterprise |
| `get_policies_review_issues` | review-check (fallback) | Fetch policy violation issues | Qualimetry AI & Enterprise |
| `get_standards_compliant_example` | review-check | Fetch compliant code example (requires organisation administrator to enable) | Qualimetry AI & Enterprise |
| `get_rules_based_analysis_issues_summary` | analysis-issues | Fetch issue counts by type and severity for a repo/branch | Qualimetry Enterprise |
| `get_rules_based_analysis_issues` | analysis-issues | Fetch paginated analysis issues with type/severity/file filtering | Qualimetry Enterprise |
| `get_dependency_vulnerabilities` | dependency-check | Fetch all dependency CVE vulnerabilities with inline upgrade advice (next safe version, latest version, upgrade risk) for a repo/branch | Qualimetry Enterprise |
| `get_dependency_upgrade_advice` | dependency-check | Live lookup for deeper upgrade detail (breaking changes, advisory flags, error messages) for a single dependency | Qualimetry Enterprise |

## License

Apache 2.0. See [LICENSE](LICENSE) for full terms.
