# Changelog - Qualimetry AI App for OpenAI Codex

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
