#!/usr/bin/env bash
# qualimetry-ai-app on-read hook for OpenAI Codex.
# Same logic as the Claude Code on-read hook (claude-plugin/.../hooks/on-read.sh):
# when the agent reads a source file, fetch get_all_review_issues +
# get_standards_compliant_example via the configured Qualimetry MCP and emit
# a <system-reminder> with the findings.
#
# Codex injects QUALIMETRY_MCP_URL and QUALIMETRY_ACCESS_TOKEN as env vars
# from the [mcp_servers.qualimetry] block in ~/.codex/config.toml when the
# plugin is loaded. If either is missing, this hook stays silent.

set -euo pipefail

# We share the same library implementation as the Claude Code plugin. In the
# packaged form, lib/fetch-review-issues.sh sits alongside this script; the
# release pipeline copies it from the Claude Code plugin so we never fork the
# behaviour.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/fetch-review-issues.sh
. "${SCRIPT_DIR}/lib/fetch-review-issues.sh"

INPUT_JSON="$(cat)"
FILE_PATH="$(printf '%s' "$INPUT_JSON" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null || true)"

[ -z "${FILE_PATH:-}" ] && exit 0
case "$FILE_PATH" in
  *.cs|*.ts|*.tsx|*.js|*.jsx|*.py|*.java|*.kt|*.swift|*.rs|*.cpp|*.cc|*.c|*.h|*.hpp|*.go|*.rb|*.php|*.scala) ;;
  *) exit 0 ;;
esac

if [ -z "${QUALIMETRY_MCP_URL:-}" ] || [ -z "${QUALIMETRY_ACCESS_TOKEN:-}" ]; then
  exit 0
fi

qualimetry_emit_findings_for_file "$FILE_PATH"
exit 0
