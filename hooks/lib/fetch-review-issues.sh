#!/usr/bin/env bash
# Shared library for the on-Read hook. Fetches review findings + a compliant
# example from the Qualimetry MCP, emits a compact <system-reminder> block on
# stderr (Claude Code surfaces hook stderr into the agent's context).
#
# Public functions:
#   qualimetry_emit_findings_for_file <abs-or-relative-file-path>
#
# Required env vars:
#   QUALIMETRY_MCP_URL              e.g. https://myorg.qualimetry.io/mcp/
#   QUALIMETRY_ACCESS_TOKEN
#
# Optional:
#   QUALIMETRY_AI_APP_CACHE_DIR     defaults to $TMPDIR/qualimetry-ai-app-cache
#   QUALIMETRY_AI_APP_CACHE_TTL     seconds, defaults to 1800 (30 min)

qualimetry_mcp_call() {
    # qualimetry_mcp_call <method> <params-json>
    local method="$1"
    local params="$2"
    local body
    body=$(printf '{"jsonrpc":"2.0","id":1,"method":"%s","params":%s}' "$method" "$params")
    curl -sS -X POST "$QUALIMETRY_MCP_URL" \
        -H "qualimetry-access-token: $QUALIMETRY_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d "$body" 2>/dev/null \
        | sed -n 's/^data: //p' \
        | head -1
}

qualimetry_resolve_repo_branch_path() {
    # qualimetry_resolve_repo_branch_path <file-path>
    # Echoes "<repo>|<branch>|<rel-path>|<file-name>" or empty if not in git.
    local file="$1"
    local dir
    dir=$(dirname "$file")
    local repo_root
    repo_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
    local repo
    repo=$(basename "$repo_root")
    local branch
    branch=$(git -C "$repo_root" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && return 1
    local rel
    rel="${file#$repo_root/}"
    local name
    name=$(basename "$file")
    printf '%s|%s|%s|%s\n' "$repo" "$branch" "$rel" "$name"
}

qualimetry_cache_path() {
    # qualimetry_cache_path <repo> <branch> <rel-path>
    local cache_dir="${QUALIMETRY_AI_APP_CACHE_DIR:-${TMPDIR:-/tmp}/qualimetry-ai-app-cache}"
    mkdir -p "$cache_dir/$1/$2/$(dirname "$3")" 2>/dev/null
    printf '%s/%s/%s/%s.json\n' "$cache_dir" "$1" "$2" "$3"
}

qualimetry_cache_fresh() {
    # qualimetry_cache_fresh <cache-file>
    local f="$1"
    [ -f "$f" ] || return 1
    local ttl="${QUALIMETRY_AI_APP_CACHE_TTL:-1800}"
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
    [ -z "$mtime" ] && return 1
    age=$((now - mtime))
    [ "$age" -lt "$ttl" ]
}

qualimetry_emit_findings_for_file() {
    local file="$1"
    local triple
    triple=$(qualimetry_resolve_repo_branch_path "$file") || return 0
    IFS='|' read -r repo branch rel name <<< "$triple"

    local cache_file
    cache_file=$(qualimetry_cache_path "$repo" "$branch" "$rel")

    local issues_json
    if qualimetry_cache_fresh "$cache_file"; then
        issues_json=$(cat "$cache_file")
    else
        local params
        params=$(printf '{"name":"get_all_review_issues","arguments":{"repositoryName":"%s","branchName":"%s","filePath":"%s","fileName":"%s"}}' \
            "$repo" "$branch" "$rel" "$name")
        issues_json=$(qualimetry_mcp_call "tools/call" "$params") || return 0
        printf '%s' "$issues_json" > "$cache_file"
    fi

    # If the response has no issues, stay silent
    local has_issues
    has_issues=$(printf '%s' "$issues_json" \
        | jq -r '.result.content[0].text // empty' 2>/dev/null \
        | jq -r '. | length' 2>/dev/null || echo "0")
    [ "${has_issues:-0}" = "0" ] && return 0

    # Fetch a compliant example (best-effort; ignore failures)
    local example_json=""
    local ex_params
    ex_params=$(printf '{"name":"get_standards_compliant_example","arguments":{"repositoryName":"%s","branchName":"%s","filePath":"%s","fileName":"%s"}}' \
        "$repo" "$branch" "$rel" "$name")
    example_json=$(qualimetry_mcp_call "tools/call" "$ex_params" 2>/dev/null || true)

    # Build a compact system-reminder. The agent picks this up via stderr.
    {
        printf '<system-reminder>\n'
        printf 'Qualimetry findings for %s\n\n' "$rel"
        printf 'Source: get_all_review_issues (qualimetry-ai-mcp)\n'
        printf 'Repo: %s   Branch: %s\n\n' "$repo" "$branch"
        printf '%s\n' "$issues_json" | jq -r '
            .result.content[0].text
            | fromjson
            | group_by(.Pillar // "Unknown")
            | map({pillar: .[0].Pillar, count: length, top: (.[0:3] | map("  - [" + (.Severity // "?") + "] " + (.Title // "?") + " @ line " + ((.Line // 0) | tostring)) | join("\n"))})
            | map("Pillar: " + .pillar + " (" + (.count | tostring) + " issues)\n" + .top)
            | join("\n\n")
        ' 2>/dev/null || printf '(unable to render structured digest; raw payload cached at %s)\n' "$cache_file"
        if [ -n "$example_json" ]; then
            printf '\nA standards-compliant example for this file is available; run /compliance-fix %s to apply it.\n' "$rel"
        fi
        printf '</system-reminder>\n'
    } 1>&2
}
