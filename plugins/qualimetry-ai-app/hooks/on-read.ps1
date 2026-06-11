# qualimetry-ai-app PostToolUse hook for OpenAI Codex (Windows / PowerShell variant).
# Mirrors on-read.sh: calls get_all_review_issues + get_standards_compliant_example
# via the configured Qualimetry MCP server and emits the findings digest as
# PostToolUse additionalContext JSON on stdout (the hookSpecificOutput shape
# Codex reads from hooks on exit 0).
#
# Codex runs hook commands through cmd.exe on Windows, where ${PLUGIN_ROOT}
# does not expand and `bash` resolves to WSL - hence this PowerShell twin,
# selected by the polyglot command in hooks.json.
#
# Credentials: $env:QUALIMETRY_MCP_URL / $env:QUALIMETRY_ACCESS_TOKEN win when
# set; otherwise they are read from the [mcp_servers.qualimetry] block in
# ~/.codex/config.toml (Codex does NOT inject MCP config into hook processes).
# Self-heals silently if neither source yields a URL + token.

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'lib/fetch-review-issues.ps1')

# Hook input is a JSON object on stdin; Codex sends tool_name/tool_input
$InputJson = [Console]::In.ReadToEnd()
if (-not $InputJson) { exit 0 }

try {
    $Parsed = $InputJson | ConvertFrom-Json
    $FilePath = $Parsed.tool_input.file_path
    if (-not $FilePath) { $FilePath = $Parsed.tool_input.path }
    if (-not $FilePath) { $FilePath = $Parsed.file_path }
    # Codex has no dedicated file-read tool: the agent reads files through its
    # shell tool, so tool_input is {"command": ...}. Best-effort: pull the
    # first source-file path out of the command string.
    if (-not $FilePath -and $Parsed.tool_input.command) {
        $m = [regex]::Match([string]$Parsed.tool_input.command,
            "[^`"' ]+\.(cs|ts|tsx|js|jsx|py|java|kt|swift|rs|cpp|cc|c|h|hpp|go|rb|php|scala)\b")
        if ($m.Success) { $FilePath = $m.Value }
    }
} catch {
    exit 0
}

if (-not $FilePath) { exit 0 }

# Bail silently for non-source files
$Ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
$Sources = @('.cs','.ts','.tsx','.js','.jsx','.py','.java','.kt','.swift','.rs','.cpp','.cc','.c','.h','.hpp','.go','.rb','.php','.scala')
if ($Sources -notcontains $Ext) { exit 0 }

# Resolve credentials: env vars first, then ~/.codex/config.toml
if (-not $env:QUALIMETRY_MCP_URL -or -not $env:QUALIMETRY_ACCESS_TOKEN) {
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $configToml = Join-Path $codexHome 'config.toml'
    if (Test-Path $configToml) {
        # Slice out the [mcp_servers.qualimetry] table (incl. sub-tables) and
        # read url + the qualimetry-access-token header from the slice.
        $lines = Get-Content $configToml
        $section = New-Object System.Collections.Generic.List[string]
        $inSection = $false
        foreach ($line in $lines) {
            if ($line -match '^\[mcp_servers\.qualimetry(\]|\.)') { $inSection = $true; continue }
            if ($line -match '^\[') { if ($inSection) { break } else { continue } }
            if ($inSection) { $section.Add($line) }
        }
        foreach ($line in $section) {
            if (-not $env:QUALIMETRY_MCP_URL -and $line -match '^\s*url\s*=\s*"([^"]*)"') {
                $env:QUALIMETRY_MCP_URL = $Matches[1]
            }
            if (-not $env:QUALIMETRY_ACCESS_TOKEN -and $line -match '"qualimetry-access-token"\s*=\s*"([^"]*)"') {
                $env:QUALIMETRY_ACCESS_TOKEN = $Matches[1]
            }
        }
    }
}

if (-not $env:QUALIMETRY_MCP_URL -or -not $env:QUALIMETRY_ACCESS_TOKEN) { exit 0 }

Qualimetry-EmitFindingsForFile -FilePath $FilePath
exit 0
