#!/usr/bin/env bash
# qualimetry-ai-app PostToolUse hook for OpenAI Codex.
# Same logic as the Claude Code on-read hook (claude-plugin/.../hooks/on-read.sh):
# when the agent reads a source file, fetch get_all_review_issues +
# get_standards_compliant_example via the configured Qualimetry MCP and emit
# the findings digest as PostToolUse additionalContext JSON on stdout (the
# hookSpecificOutput shape Codex reads from hooks on exit 0).
#
# Prerequisites: git plus curl-or-wget only. jq is OPTIONAL - with it the
# digest is grouped per pillar; without it a raw findings payload is emitted.
#
# Credentials: QUALIMETRY_MCP_URL / QUALIMETRY_ACCESS_TOKEN env vars win when
# set; otherwise they are read from the [mcp_servers.qualimetry] block in
# ~/.codex/config.toml (Codex does NOT inject MCP config into hook processes).
# Self-heals silently if neither source yields a URL + token.

set -euo pipefail

# We share the same library implementation as the Claude Code plugin. In the
# packaged form, lib/fetch-review-issues.sh sits alongside this script; the
# release pipeline copies it from the Claude Code plugin so we never fork the
# behaviour.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/fetch-review-issues.sh
. "${SCRIPT_DIR}/lib/fetch-review-issues.sh"

# Extract a string field from JSON on stdin without jq. Good enough for
# harness-generated JSON; unescapes \\ and \" and \/.
qualimetry_sed_json_field() {
    # qualimetry_sed_json_field <json> <field>
    printf '%s' "$1" \
        | grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | sed -e "s/^\"$2\"[[:space:]]*:[[:space:]]*\"//" -e 's/"$//' \
              -e 's/\\\\/\\/g' -e 's/\\\//\//g'
}

INPUT_JSON="$(cat)"
if qualimetry_have_jq; then
    FILE_PATH="$(printf '%s' "$INPUT_JSON" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty' 2>/dev/null || true)"
else
    FILE_PATH="$(qualimetry_sed_json_field "$INPUT_JSON" "file_path" || true)"
    [ -z "${FILE_PATH:-}" ] && FILE_PATH="$(qualimetry_sed_json_field "$INPUT_JSON" "path" || true)"
fi

# Codex has no dedicated file-read tool: the agent reads files through its
# shell tool, so tool_input is {"command": ...}. Best-effort: pull the first
# source-file path out of the command string.
if [ -z "${FILE_PATH:-}" ]; then
  if qualimetry_have_jq; then
    COMMAND_STR="$(printf '%s' "$INPUT_JSON" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  else
    COMMAND_STR="$(qualimetry_sed_json_field "$INPUT_JSON" "command" || true)"
  fi
  if [ -n "${COMMAND_STR:-}" ]; then
    FILE_PATH="$(printf '%s' "$COMMAND_STR" \
      | grep -oE "[^\"' ]+\.(cs|ts|tsx|js|jsx|py|java|kt|swift|rs|cpp|cc|c|h|hpp|go|rb|php|scala)" \
      | head -1 || true)"
  fi
fi

[ -z "${FILE_PATH:-}" ] && exit 0
case "$FILE_PATH" in
  *.cs|*.ts|*.tsx|*.js|*.jsx|*.py|*.java|*.kt|*.swift|*.rs|*.cpp|*.cc|*.c|*.h|*.hpp|*.go|*.rb|*.php|*.scala) ;;
  *) exit 0 ;;
esac

# Resolve credentials: env vars first, then the [mcp_servers.qualimetry]
# block /qualimetry-setup wrote to ~/.codex/config.toml (sed/awk only - no
# extra tooling needed).
if [ -z "${QUALIMETRY_MCP_URL:-}" ] || [ -z "${QUALIMETRY_ACCESS_TOKEN:-}" ]; then
  CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
  if [ -f "$CODEX_CONFIG" ]; then
    # Slice out the [mcp_servers.qualimetry] table (incl. its sub-tables),
    # then read url + the qualimetry-access-token header from the slice.
    SECTION="$(awk '
      /^\[mcp_servers\.qualimetry(\]|\.)/ { in_s = 1 }
      /^\[/ && $0 !~ /^\[mcp_servers\.qualimetry(\]|\.)/ { if (in_s) exit }
      in_s { print }
    ' "$CODEX_CONFIG" 2>/dev/null || true)"
    QUALIMETRY_MCP_URL="$(printf '%s\n' "$SECTION" | sed -n 's/^[[:space:]]*url[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' | head -1)"
    QUALIMETRY_ACCESS_TOKEN="$(printf '%s\n' "$SECTION" | sed -n 's/.*"qualimetry-access-token"[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    export QUALIMETRY_MCP_URL QUALIMETRY_ACCESS_TOKEN
  fi
fi

if [ -z "${QUALIMETRY_MCP_URL:-}" ] || [ -z "${QUALIMETRY_ACCESS_TOKEN:-}" ]; then
  exit 0
fi

qualimetry_emit_findings_for_file "$FILE_PATH"
exit 0
