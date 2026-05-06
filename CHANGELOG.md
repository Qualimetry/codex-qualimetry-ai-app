# Changelog - Qualimetry AI App for OpenAI Codex

## [1.0.0] - 2026-05-05

### Added

- Initial release.
- Codex plugin `qualimetry-ai-app` bundling all four [Qualimetry AI Skills](https://github.com/Qualimetry/qualimetry-ai-skills).
- `/qualimetry-setup` slash command that writes a `[mcp_servers.qualimetry]` block to `~/.codex/config.toml`.
- `on-read` hook that surfaces `get_all_review_issues` + `get_standards_compliant_example` findings as a `<system-reminder>` when Codex reads a reviewed file.
- `config.snippet.toml` for manual install.
