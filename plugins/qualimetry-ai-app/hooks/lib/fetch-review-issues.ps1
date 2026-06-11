# Shared library for the on-Read hook (Windows variant). Mirrors fetch-review-issues.sh.
# Emits the digest as PostToolUse JSON on stdout:
#   {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}}
# Both Claude Code and Codex read that shape from stdout on exit 0 and add the
# additionalContext to the model's context. (Plain stdout/stderr on exit 0 is
# NOT surfaced to the model by either host.)
#
# Public functions:
#   Qualimetry-EmitFindingsForFile -FilePath <abs-or-relative>
#
# Required env vars (the on-read wrapper resolves them from the host's MCP
# config when not already set): QUALIMETRY_MCP_URL, QUALIMETRY_ACCESS_TOKEN
# Optional: QUALIMETRY_AI_APP_CACHE_DIR, QUALIMETRY_AI_APP_CACHE_TTL (seconds)

function Qualimetry-McpCall {
    param([string]$Method, [string]$Params)
    $body = @{ jsonrpc = "2.0"; id = 1; method = $Method } | ConvertTo-Json -Compress
    # Splice in the params JSON (already compact)
    $body = $body -replace '\}$', (",`"params`":$Params}")
    try {
        $response = Invoke-WebRequest -Method Post -Uri $env:QUALIMETRY_MCP_URL `
            -Headers @{
                'qualimetry-access-token' = $env:QUALIMETRY_ACCESS_TOKEN
                'Content-Type' = 'application/json'
                'Accept' = 'application/json, text/event-stream'
            } `
            -Body $body -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    } catch { return '' }

    $content = $response.Content
    # SSE: lines like "event: message\r\ndata: {...}". Pick the first data line.
    $line = ($content -split "`n" | Where-Object { $_ -match '^data:\s' } | Select-Object -First 1)
    if ($line) { return ($line -replace '^data:\s', '').Trim() }
    return $content.Trim()
}

function Qualimetry-ResolveRepoBranchPath {
    param([string]$FilePath)
    $dir = Split-Path -Parent $FilePath
    if (-not $dir) { $dir = '.' }
    $repoRoot = & git -C $dir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $repoRoot) { return $null }
    $repo = Split-Path -Leaf $repoRoot
    $branch = & git -C $repoRoot branch --show-current 2>$null
    if (-not $branch) { return $null }
    # git prints the root with forward slashes; the hook's file_path usually has
    # backslashes. Normalise both before relativising or the prefix never matches.
    $rel = $FilePath -replace '\\', '/'
    $rootFwd = ($repoRoot -replace '\\', '/').TrimEnd('/')
    if ($rel.StartsWith($rootFwd, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $rel.Substring($rootFwd.Length).TrimStart('/')
    }
    $name = Split-Path -Leaf $FilePath
    return @{ RepoRoot = $repoRoot; Repo = $repo; Branch = $branch; Rel = $rel; Name = $name }
}

function Qualimetry-ResolveRepoCandidates {
    # Candidate repositoryName values, best first. The server's canonical
    # format is 'owner/repo-name' - derive it from the origin URL, then fall
    # back to the bare directory basename for installations keyed without an
    # owner.
    param([string]$RepoRoot, [string]$BaseName)
    $candidates = New-Object System.Collections.Generic.List[string]
    $origin = & git -C $RepoRoot remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $origin) {
        $path = $origin.Trim().TrimEnd('/')
        if ($path.EndsWith('.git')) { $path = $path.Substring(0, $path.Length - 4) }
        if ($path -match '^[^@/]+@[^:]+:(.+)$') {
            $path = $Matches[1]                       # ssh: git@host:owner/repo
        } elseif ($path -match '^[a-z+]+://[^/]+/(.+)$') {
            $path = $Matches[1]                       # url: scheme://host/...
        }
        $path = $path.TrimStart('/')
        $candidate = ''
        if ($path -match '(?:^|/)([^/]+)/_git/([^/]+)$') {
            $candidate = "$($Matches[1])/$($Matches[2])"   # Azure: project/_git/repo
        } elseif ($path -match '([^/]+)/([^/]+)$') {
            $candidate = "$($Matches[1])/$($Matches[2])"   # last two segments
        }
        if ($candidate) { $candidates.Add($candidate) }
    }
    $candidates.Add($BaseName)
    return $candidates
}

function Qualimetry-ResponseHasIssues {
    param([string]$IssuesJson)
    try {
        $envelope = $IssuesJson | ConvertFrom-Json
        $issues = $envelope.result.content[0].text | ConvertFrom-Json
        return ($issues -and $issues.Count -gt 0)
    } catch { return $false }
}

function Qualimetry-SplitRelPath {
    # The MCP `filePath` parameter: directory portion with a trailing slash,
    # or "" for a root-level file (the documented contract of
    # get_all_review_issues - the full relative path must NOT be passed).
    param([string]$Rel)
    $dir = Split-Path -Parent $Rel
    if (-not $dir) { return '' }
    return (($dir -replace '\\', '/') + '/')
}

function Qualimetry-CachePath {
    param([string]$Repo, [string]$Branch, [string]$Rel)
    $cacheDir = if ($env:QUALIMETRY_AI_APP_CACHE_DIR) { $env:QUALIMETRY_AI_APP_CACHE_DIR } else { Join-Path $env:TEMP 'qualimetry-ai-app-cache' }
    $dir = Join-Path $cacheDir $Repo
    $dir = Join-Path $dir $Branch
    $relParent = Split-Path -Parent $Rel
    if ($relParent) { $dir = Join-Path $dir $relParent }
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return Join-Path $dir ((Split-Path -Leaf $Rel) + '.json')
}

function Qualimetry-CacheFresh {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $ttl = if ($env:QUALIMETRY_AI_APP_CACHE_TTL) { [int]$env:QUALIMETRY_AI_APP_CACHE_TTL } else { 1800 }
    $age = ((Get-Date) - (Get-Item $Path).LastWriteTime).TotalSeconds
    return $age -lt $ttl
}

function Qualimetry-EmitFindingsForFile {
    param([string]$FilePath)
    $ctx = Qualimetry-ResolveRepoBranchPath -FilePath $FilePath
    if (-not $ctx) { return }

    $filePathParam = Qualimetry-SplitRelPath -Rel $ctx.Rel
    # Cache is keyed on the stable directory basename regardless of which
    # repositoryName candidate the server answered to.
    $cacheFile = Qualimetry-CachePath -Repo $ctx.Repo -Branch $ctx.Branch -Rel $ctx.Rel

    $issuesJson = $null
    $usedRepo = $ctx.Repo
    if (Qualimetry-CacheFresh -Path $cacheFile) {
        $issuesJson = Get-Content -Raw -Path $cacheFile
    } else {
        # Try owner/repo (the server's documented canonical form) first, then
        # the bare basename for installations keyed without an owner.
        $lastResult = $null
        foreach ($candidate in (Qualimetry-ResolveRepoCandidates -RepoRoot $ctx.RepoRoot -BaseName $ctx.Repo)) {
            if (-not $candidate) { continue }
            $params = "{`"name`":`"get_all_review_issues`",`"arguments`":{`"repositoryName`":`"$candidate`",`"branchName`":`"$($ctx.Branch)`",`"filePath`":`"$filePathParam`",`"fileName`":`"$($ctx.Name)`"}}"
            $response = Qualimetry-McpCall -Method 'tools/call' -Params $params
            if (-not $response) { continue }
            try {
                $probe = $response | ConvertFrom-Json
                if ($null -eq $probe.result) { continue }
            } catch { continue }
            $lastResult = $response
            if (Qualimetry-ResponseHasIssues -IssuesJson $response) {
                $issuesJson = $response
                $usedRepo = $candidate
                break
            }
        }
        # Cache whichever result we ended with (hit or clean miss) so repeated
        # reads stay quiet for the TTL; never cache transport noise.
        if ($issuesJson) {
            Set-Content -Path $cacheFile -Value $issuesJson -NoNewline -Encoding UTF8
        } elseif ($lastResult) {
            Set-Content -Path $cacheFile -Value $lastResult -NoNewline -Encoding UTF8
            return
        } else {
            return
        }
    }

    # Decode the MCP envelope; bail if no issues
    try {
        $envelope = $issuesJson | ConvertFrom-Json
        $textPayload = $envelope.result.content[0].text
        $issues = $textPayload | ConvertFrom-Json
    } catch { return }
    if (-not $issues -or $issues.Count -eq 0) { return }

    # Best-effort compliant-example fetch (ignore failures)
    $exParams = "{`"name`":`"get_standards_compliant_example`",`"arguments`":{`"repositoryName`":`"$usedRepo`",`"branchName`":`"$($ctx.Branch)`",`"filePath`":`"$filePathParam`",`"fileName`":`"$($ctx.Name)`"}}"
    $exampleJson = ''
    try { $exampleJson = Qualimetry-McpCall -Method 'tools/call' -Params $exParams } catch {}

    # Build the digest
    $byPillar = $issues | Group-Object -Property Pillar
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Qualimetry findings for $($ctx.Rel)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Source: get_all_review_issues (qualimetry-ai-mcp)')
    [void]$sb.AppendLine("Repo: $usedRepo   Branch: $($ctx.Branch)")
    [void]$sb.AppendLine('')
    foreach ($p in $byPillar) {
        [void]$sb.AppendLine("Pillar: $($p.Name) ($($p.Count) issues)")
        $top = $p.Group | Select-Object -First 3
        foreach ($i in $top) {
            [void]$sb.AppendLine("  - [$($i.Severity)] $($i.Title) @ line $($i.Line)")
        }
        [void]$sb.AppendLine('')
    }
    if ($exampleJson) {
        [void]$sb.AppendLine("A standards-compliant example is available; run /compliance-fix $($ctx.Rel) to apply it.")
    }

    # PostToolUse additionalContext: JSON on stdout, exit 0. This is the only
    # channel the host forwards into the model's context.
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'PostToolUse'
            additionalContext = $sb.ToString()
        }
    } | ConvertTo-Json -Depth 4 -Compress
    [Console]::Out.Write($payload)
}
