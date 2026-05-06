# Shared library for the on-Read hook (Windows variant). Mirrors fetch-review-issues.sh.
# Public functions:
#   Qualimetry-EmitFindingsForFile -FilePath <abs-or-relative>
#
# Required env vars: QUALIMETRY_MCP_URL, QUALIMETRY_ACCESS_TOKEN
# Optional:          QUALIMETRY_AI_APP_CACHE_DIR, QUALIMETRY_AI_APP_CACHE_TTL (seconds)

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
    $rel = $FilePath
    if ($rel.StartsWith($repoRoot)) { $rel = $rel.Substring($repoRoot.Length + 1) }
    $rel = $rel -replace '\\', '/'
    $name = Split-Path -Leaf $FilePath
    return @{ Repo = $repo; Branch = $branch; Rel = $rel; Name = $name }
}

function Qualimetry-CachePath {
    param([string]$Repo, [string]$Branch, [string]$Rel)
    $cacheDir = if ($env:QUALIMETRY_AI_APP_CACHE_DIR) { $env:QUALIMETRY_AI_APP_CACHE_DIR } else { Join-Path $env:TEMP 'qualimetry-ai-app-cache' }
    $dir = Join-Path $cacheDir $Repo
    $dir = Join-Path $dir $Branch
    $dir = Join-Path $dir (Split-Path -Parent $Rel)
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

    $cacheFile = Qualimetry-CachePath -Repo $ctx.Repo -Branch $ctx.Branch -Rel $ctx.Rel

    if (Qualimetry-CacheFresh -Path $cacheFile) {
        $issuesJson = Get-Content -Raw -Path $cacheFile
    } else {
        $params = "{`"name`":`"get_all_review_issues`",`"arguments`":{`"repositoryName`":`"$($ctx.Repo)`",`"branchName`":`"$($ctx.Branch)`",`"filePath`":`"$($ctx.Rel)`",`"fileName`":`"$($ctx.Name)`"}}"
        $issuesJson = Qualimetry-McpCall -Method 'tools/call' -Params $params
        if (-not $issuesJson) { return }
        Set-Content -Path $cacheFile -Value $issuesJson -NoNewline
    }

    # Decode the MCP envelope; bail if no issues
    try {
        $envelope = $issuesJson | ConvertFrom-Json
        $textPayload = $envelope.result.content[0].text
        $issues = $textPayload | ConvertFrom-Json
    } catch { return }
    if (-not $issues -or $issues.Count -eq 0) { return }

    # Best-effort compliant-example fetch (ignore failures)
    $exParams = "{`"name`":`"get_standards_compliant_example`",`"arguments`":{`"repositoryName`":`"$($ctx.Repo)`",`"branchName`":`"$($ctx.Branch)`",`"filePath`":`"$($ctx.Rel)`",`"fileName`":`"$($ctx.Name)`"}}"
    $exampleJson = ''
    try { $exampleJson = Qualimetry-McpCall -Method 'tools/call' -Params $exParams } catch {}

    # Build the system-reminder digest
    $byPillar = $issues | Group-Object -Property Pillar
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<system-reminder>')
    [void]$sb.AppendLine("Qualimetry findings for $($ctx.Rel)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Source: get_all_review_issues (qualimetry-ai-mcp)')
    [void]$sb.AppendLine("Repo: $($ctx.Repo)   Branch: $($ctx.Branch)")
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
    [void]$sb.AppendLine('</system-reminder>')

    # Hook stderr is forwarded into the agent's context by Claude Code
    [Console]::Error.Write($sb.ToString())
}
