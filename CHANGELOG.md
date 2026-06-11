# Changelog - Qualimetry AI App for OpenAI Codex

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
