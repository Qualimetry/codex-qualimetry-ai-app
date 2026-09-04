# Changelog - Qualimetry AI App for OpenAI Codex

## [1.3.0] - 2026-09-05

### Added

- **Security hotspots.** Codex can now see the security hotspots your analysis raises: security-sensitive code that needs a person to decide whether it is safe. They were never returned by the issue tools, so a branch reported as clear of issues could still have every hotspot outstanding. The `analysis-issues` skill now works through them after the issues, reading each one's risk description and fix recommendations, and gives you an assessment per hotspot. Recording the review decision stays with you in Qualimetry.
- **Suppression-aware dependency work.** The `dependency-check` skill reads the suppressions that cover your branch. A CVE whose suppression is still waiting for approval is reported rather than fixed, so no time goes into risk you are already accepting. An approved suppression expiring within 15 days is flagged before the finding returns. Ask and Codex will list what has been suppressed, by whom, why, how widely it applies and when it runs out. Raising and approving suppressions remains a human step in the Qualimetry dashboard.
- **Dependency findings are marked as such.** Analysis findings that came from the dependency scan are now labelled, and Codex hands them to the dependency workflow instead of fixing them from the analysis side, where the package version and upgrade path are not known.

### Changed

- Setup verification now expects 21 MCP tools on Qualimetry Enterprise; Qualimetry AI is unchanged at 12.
- Both updated skills skip their new steps with a one-line note when the Qualimetry deployment is older than the tools, so nothing breaks before your server is upgraded.

## [1.2.0] - 2026-06-11

### Fixed

- **Installation**: `codex plugin marketplace add Qualimetry/codex-qualimetry-ai-app` previously failed with `marketplace root does not contain a supported manifest`. The repository now uses Codex's marketplace layout and installation is verified end-to-end on current Codex releases. Install with `codex plugin marketplace add Qualimetry/codex-qualimetry-ai-app`, then `codex plugin add qualimetry-ai-app@qualimetry-ai` (the verb is `add`, not `install`).
- **Automatic findings on file open**: review findings now reach Codex reliably when a reviewed source file is read. The on-read hook is a standard PostToolUse hook with native commands for macOS/Linux and Windows, delivers its digest through the supported hook output channel, uses the server connection from `~/.codex/config.toml`, and also recognises source files read through shell commands.
- **Repository matching**: the hook identifies your repository as `owner/repo-name` from the `origin` remote (GitHub, GitLab, Bitbucket, and Azure DevOps URL forms), falling back to the folder name — so findings resolve without any manual mapping.
- A failed server response is no longer cached, so a temporary connection problem can't suppress findings for the rest of the cache window.

### Added

- `qualimetry-setup` skill: ask Codex to "set up qualimetry" and it collects your server URL and access token, then writes the `[mcp_servers.qualimetry]` entry to `~/.codex/config.toml` without touching the rest of the file.

### Changed

- **No extra tools to install**: the hook needs only `git` and `curl` (or `wget`) on macOS/Linux, and plain PowerShell on Windows. If `jq` is present, findings appear as a grouped per-pillar digest; without it the full findings payload is delivered as-is.

### Notes

- Codex asks you to review and trust the plugin's hook the first time it loads; approve it to enable automatic findings.

## [1.1.2] - 2026-06-11

### Changed

- Bundled skills updated for the renamed `get_coding_standards_blitzy` MCP tool (formerly `get_language_coding_standards_blitzy`). The Blitzy coding-standards pack now carries a top-level `license` notice, and language coding standards are returned only when `languageCodes` are supplied — omit them to receive policies and principles only.

## [1.1.1] - 2026-06-06

### Added

- Pull-request-scoped issue retrieval. The on-Read hook resolves the current branch's pull request using **standard git only** — `git ls-remote` against the host's PR refs (GitHub, GitLab, Bitbucket Server), no `gh`/`az` CLI required — and passes `pullRequest` to `get_all_review_issues`, so findings are scoped to the PR's new code. Resolution runs only on a cache miss. The bundled `analysis-issues` and `review-check` skills document the optional `pullRequest` parameter and the git-only resolution.

## [1.0.1] - 2026-05-06

### Changed

- Homepage URL switched from qualimetry.com to qualimetry.ai across every manifest, README, and the GitHub repo About sidebar.

### Added

- `marketplace.json` at the repo root and `.codex-plugin/plugin.json` in the canonical Codex plugin format. The repo is now installable via `codex plugin marketplace add Qualimetry/codex-qualimetry-ai-app`.

## [1.0.0] - 2026-05-05

### Added

- Initial release.
- Codex plugin `qualimetry-ai-app` bundling all four [Qualimetry AI Skills](https://github.com/Qualimetry/qualimetry-ai-skills).
- `/qualimetry-setup` slash command that writes a `[mcp_servers.qualimetry]` block to `~/.codex/config.toml`.
- `on-read` hook that surfaces `get_all_review_issues` + `get_standards_compliant_example` findings as a `<system-reminder>` when Codex reads a reviewed file.
- `config.snippet.toml` for manual install.
