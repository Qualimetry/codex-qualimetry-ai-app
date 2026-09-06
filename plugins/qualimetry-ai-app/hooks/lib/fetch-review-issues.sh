#!/usr/bin/env bash
# Shared library for the on-Read hook. Fetches review findings + a compliant
# example from the Qualimetry MCP and emits the digest as PostToolUse JSON on
# stdout: {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}}.
# Both Claude Code and Codex read that shape from stdout on exit 0 and add the
# additionalContext to the model's context. (Plain stdout/stderr on exit 0 is
# NOT surfaced to the model by either host.)
#
# Zero extra prerequisites by design: only git plus curl-or-wget are required.
# When jq is available the digest is a grouped per-pillar summary; without jq
# a size-capped raw findings payload is emitted instead (sed/awk only).
#
# Public functions:
#   qualimetry_emit_findings_for_file <abs-or-relative-file-path>
#
# Required env vars (the on-read wrapper resolves them from the host's MCP
# config when not already set):
#   QUALIMETRY_MCP_URL              e.g. https://myorg.qualimetry.io/mcp/
#   QUALIMETRY_ACCESS_TOKEN
#
# Optional:
#   QUALIMETRY_AI_APP_CACHE_DIR     defaults to $TMPDIR/qualimetry-ai-app-cache
#   QUALIMETRY_AI_APP_CACHE_TTL     seconds, defaults to 1800 (30 min)

qualimetry_have_jq() {
    command -v jq >/dev/null 2>&1
}

qualimetry_http_post() {
    # qualimetry_http_post <body>  -> response on stdout
    local body="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -sS -X POST "$QUALIMETRY_MCP_URL" \
            -H "qualimetry-access-token: $QUALIMETRY_ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -d "$body" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O - \
            --header "qualimetry-access-token: $QUALIMETRY_ACCESS_TOKEN" \
            --header "Content-Type: application/json" \
            --header "Accept: application/json, text/event-stream" \
            --post-data "$body" \
            "$QUALIMETRY_MCP_URL" 2>/dev/null
    fi
}

qualimetry_mcp_call() {
    # qualimetry_mcp_call <method> <params-json>
    local method="$1"
    local params="$2"
    local body
    body=$(printf '{"jsonrpc":"2.0","id":1,"method":"%s","params":%s}' "$method" "$params")
    qualimetry_http_post "$body" \
        | sed -n 's/^data: //p' \
        | head -1
}

qualimetry_json_escape() {
    # Escape a string for embedding in a JSON string value (awk-only; no jq).
    # Handles backslash, quote, and common control characters.
    printf '%s' "$1" | awk 'BEGIN { ORS = "" } {
        if (NR > 1) { print "\\n" }
        gsub(/\\/, "\\\\")
        gsub(/"/, "\\\"")
        gsub(/\t/, "\\t")
        gsub(/\r/, "\\r")
        print
    }'
}

qualimetry_resolve_repo_candidates() {
    # qualimetry_resolve_repo_candidates <repo-root> <basename>
    # Echoes candidate repositoryName values, best first, one per line.
    # The server's canonical format is 'owner/repo-name' (it normalises case
    # and .git suffixes) - derive it from the origin URL, then fall back to
    # the bare directory basename for installations keyed without an owner.
    local repo_root="$1"
    local base="$2"
    local origin
    origin=$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)
    if [ -n "$origin" ]; then
        local path="$origin"
        path="${path%/}"
        path="${path%.git}"
        # ssh form: git@host:owner/repo -> owner/repo
        case "$path" in
            *@*:*) path="${path#*:}" ;;
            *://*) path="${path#*://}"; path="${path#*/}" ;;
        esac
        path="${path#/}"
        local candidate=""
        case "$path" in
            */_git/*)
                # Azure DevOps: org/project/_git/repo -> project/repo
                candidate="$(printf '%s' "$path" | awk -F'/_git/' '{n=split($1,a,"/"); print a[n] "/" $2}')"
                ;;
            */*)
                # Keep the last two segments: .../owner/repo -> owner/repo
                candidate="$(printf '%s' "$path" | awk -F/ '{print $(NF-1) "/" $NF}')"
                ;;
        esac
        if [ -n "$candidate" ] && [ "$candidate" != "/" ]; then
            printf '%s\n' "$candidate"
        fi
    fi
    printf '%s\n' "$base"
}

qualimetry_resolve_repo_branch_path() {
    # qualimetry_resolve_repo_branch_path <file-path>
    # Echoes "<repo-root>|<base>|<branch>|<rel-path>|<file-name>" or fails.
    local file="$1"
    local dir
    dir=$(dirname "$file")
    local repo_root
    repo_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
    local base
    base=$(basename "$repo_root")
    local branch
    branch=$(git -C "$repo_root" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && return 1
    # On Windows (Git Bash) the hook input uses backslashes while git prints
    # the root with forward slashes - normalise before relativising.
    local file_fwd
    file_fwd=$(printf '%s' "$file" | tr '\\' '/')
    local rel
    rel="${file_fwd#$repo_root/}"
    local name
    name=$(basename "$file_fwd")
    printf '%s|%s|%s|%s|%s\n' "$repo_root" "$base" "$branch" "$rel" "$name"
}

qualimetry_resolve_pull_request() {
    # qualimetry_resolve_pull_request <dir> <branch>
    # Resolve the pull/merge-request number for the branch using ONLY standard
    # git - no SCM CLI (gh/az) required. Every major host advertises the PR as a
    # ref that `git ls-remote` returns, whose head equals the source-branch tip:
    #   GitHub  refs/pull/<n>/head   GitLab  refs/merge-requests/<n>/head
    #   Bitbucket  refs/pull-requests/<n>/from
    # Match the branch's remote head SHA against those refs and read the number.
    # Echoes the number, or empty when the host advertises no matching PR ref
    # (e.g. branch not pushed, or Bitbucket Cloud / Azure DevOps which expose no
    # head-equal PR ref over git) - the caller then queries the branch.
    local dir="$1"
    local branch="$2"
    [ -z "$branch" ] && return 0
    local sha
    sha=$(git -C "$dir" ls-remote origin "refs/heads/$branch" 2>/dev/null | awk 'NR==1{print $1}')
    [ -z "$sha" ] && return 0
    git -C "$dir" ls-remote origin \
        'refs/pull/*/head' 'refs/merge-requests/*/head' 'refs/pull-requests/*/from' 2>/dev/null \
        | awk -v s="$sha" '$1==s {print $2; exit}' \
        | grep -oE '[0-9]+' | head -1
}

qualimetry_split_rel_path() {
    # qualimetry_split_rel_path <rel-path>
    # Echoes the MCP `filePath` parameter for a repo-relative path: the
    # directory portion with a trailing slash, or "" for a root-level file
    # (the documented contract of get_all_review_issues - the full relative
    # path must NOT be passed as filePath).
    local rel="$1"
    local dir
    dir=$(dirname "$rel")
    if [ "$dir" = "." ]; then
        printf ''
    else
        printf '%s/' "$dir"
    fi
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

qualimetry_response_is_result() {
    # True when the response looks like a successful JSON-RPC result envelope.
    printf '%s' "$1" | grep -q '"result"'
}

qualimetry_response_has_issues() {
    # True when the response's text payload is a non-empty JSON array of issues.
    local issues_json="$1"
    if qualimetry_have_jq; then
        local n
        n=$(printf '%s' "$issues_json" \
            | jq -r '.result.content[0].text // empty' 2>/dev/null \
            | jq -r 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)
        [ "${n:-0}" != "0" ]
    else
        # Without jq: a hit looks like "text":"[{... ; misses are "[]" or a
        # plain "no code review found" sentence.
        printf '%s' "$issues_json" | grep -q '"text"[[:space:]]*:[[:space:]]*"\[{'
    fi
}

qualimetry_emit_findings_for_file() {
    local file="$1"
    local resolved
    resolved=$(qualimetry_resolve_repo_branch_path "$file") || return 0
    local repo_root base branch rel name
    IFS='|' read -r repo_root base branch rel name <<< "$resolved"

    local file_path_param
    file_path_param=$(qualimetry_split_rel_path "$rel")

    # Cache is keyed on the stable directory basename regardless of which
    # repositoryName candidate the server answered to.
    local cache_file
    cache_file=$(qualimetry_cache_path "$base" "$branch" "$rel")

    local issues_json="" used_repo="$base"
    if qualimetry_cache_fresh "$cache_file"; then
        issues_json=$(cat "$cache_file")
    else
        # If the branch has a pull request, scope findings to its new code.
        # Resolved here (cache-miss only) so cached reads cost no network.
        local pr pr_arg=""
        pr=$(qualimetry_resolve_pull_request "$repo_root" "$branch")
        [ -n "$pr" ] && pr_arg=$(printf ',"pullRequest":"%s"' "$pr")

        # Try owner/repo (the server's documented canonical form) first, then
        # the bare basename for installations keyed without an owner.
        local candidate response="" last_result=""
        while IFS= read -r candidate; do
            [ -n "$candidate" ] || continue
            local params
            params=$(printf '{"name":"get_all_review_issues","arguments":{"repositoryName":"%s","branchName":"%s","filePath":"%s","fileName":"%s"%s}}' \
                "$candidate" "$branch" "$file_path_param" "$name" "$pr_arg")
            response=$(qualimetry_mcp_call "tools/call" "$params") || continue
            qualimetry_response_is_result "$response" || continue
            last_result="$response"
            if qualimetry_response_has_issues "$response"; then
                issues_json="$response"
                used_repo="$candidate"
                break
            fi
        done <<EOF_CANDIDATES
$(qualimetry_resolve_repo_candidates "$repo_root" "$base")
EOF_CANDIDATES

        # Cache whichever result we ended with (hit or clean miss) so repeated
        # reads stay quiet for the TTL; never cache transport noise.
        if [ -n "$issues_json" ]; then
            printf '%s' "$issues_json" > "$cache_file"
        elif [ -n "$last_result" ]; then
            printf '%s' "$last_result" > "$cache_file"
            return 0
        else
            return 0
        fi
    fi

    qualimetry_response_has_issues "$issues_json" || return 0

    # Fetch a compliant example (best-effort; ignore failures)
    local example_json=""
    local ex_params
    ex_params=$(printf '{"name":"get_standards_compliant_example","arguments":{"repositoryName":"%s","branchName":"%s","filePath":"%s","fileName":"%s"}}' \
        "$used_repo" "$branch" "$file_path_param" "$name")
    example_json=$(qualimetry_mcp_call "tools/call" "$ex_params" 2>/dev/null || true)

    # Build the digest, then hand it to the host as PostToolUse
    # additionalContext (JSON on stdout, exit 0).
    local digest
    if qualimetry_have_jq; then
        digest=$(
            printf 'Qualimetry findings for %s\n\n' "$rel"
            printf 'Source: get_all_review_issues (qualimetry-ai-mcp)\n'
            printf 'Repo: %s   Branch: %s\n\n' "$used_repo" "$branch"
            printf '%s\n' "$issues_json" | jq -r '
                .result.content[0].text
                | fromjson
                | group_by(.Pillar // "Unknown")
                | map({pillar: .[0].Pillar, count: length, top: (.[0:3] | map("  - [" + (.Severity // "?") + "] " + (.Title // "?") + " @ line " + ((.Line // 0) | tostring)) | join("\n"))})
                | map("Pillar: " + .pillar + " (" + (.count | tostring) + " issues)\n" + .top)
                | join("\n\n")
            ' 2>/dev/null | tr -d '\r' || printf '(unable to render structured digest; raw payload cached at %s)\n' "$cache_file"
            if [ -n "$example_json" ]; then
                printf '\nA standards-compliant example for this file is available; run /compliance-fix %s to apply it.\n' "$rel"
            fi
        )
        jq -cn --arg ctx "$digest" \
            '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
    else
        # No jq: emit the raw findings payload (size-capped). It is the JSON-RPC
        # envelope whose result text holds the issues array - directly readable
        # by the model, just not grouped.
        local raw
        raw=$(printf '%s' "$issues_json" | head -c 6000)
        digest=$(
            printf 'Qualimetry findings for %s (raw payload; install jq for a grouped digest)\n' "$rel"
            printf 'Source: get_all_review_issues (qualimetry-ai-mcp)   Repo: %s   Branch: %s\n\n' "$used_repo" "$branch"
            printf '%s\n' "$raw"
            if [ -n "$example_json" ]; then
                printf '\nA standards-compliant example for this file is available; run /compliance-fix %s to apply it.\n' "$rel"
            fi
        )
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' \
            "$(qualimetry_json_escape "$digest")"
    fi
}
