---
name: qualimetry-setup
description: >
  Configures the Qualimetry MCP server for OpenAI Codex by writing the
  [mcp_servers.qualimetry] entry (server URL + access token) to
  ~/.codex/config.toml. Invoke as the qualimetry-setup skill when the user
  wants to set up, reconfigure, or rotate the token for Qualimetry, or when
  any Qualimetry tool reports that the MCP server is not configured.
license: Apache-2.0
compatibility: OpenAI Codex. Writes ~/.codex/config.toml; requires a restart of Codex afterwards.
metadata:
  author: qualimetry
  version: "1.2"
---

# Qualimetry: Setup (Codex)

Walk the user through configuring the Qualimetry MCP server entry in `~/.codex/config.toml`. Follow this exact procedure:

1. Ask: **"What is your Qualimetry server URL? (default: `https://myorg.qualimetry.io/mcp/`)"**. If the reply is empty or "default", use `https://myorg.qualimetry.io/mcp/`.

2. Ask: **"Paste your Qualimetry access token. The text will be visible in the chat — clear it after if you'd like."**

3. Validate the URL ends in `/mcp/` (or `/mcp`); append `/mcp/` if missing and tell the user what you adjusted.

4. Read `~/.codex/config.toml` (create the file if it does not exist). Replace any existing `[mcp_servers.qualimetry]` block, or append a new one:

   ```toml
   [mcp_servers.qualimetry]
   url = "<URL>"
   http_headers = { "qualimetry-access-token" = "<TOKEN>" }
   ```

   Preserve every other section of the file exactly as it was.

5. Tell the user to **restart Codex** so the new MCP entry is picked up: type `exit`, then run `codex` again.

6. After restart, the user can confirm with the `/mcp` command inside Codex (or `codex mcp list` in the shell): `qualimetry` should be listed and connected.

7. Smoke-test by invoking the MCP tool `get_policies` (no arguments). A JSON array of policies means setup is complete; an authentication error means the token is wrong — ask the user to re-run setup with the correct token.

End with the verbatim message:

> ✓ Qualimetry configured. You can now ask for a compliance check on any file, or just open a reviewed file and Codex will surface findings automatically.

## Notes

- Never echo the token back in any subsequent message. Quote it as `****` if you must refer to it.
- If the user re-runs this skill, treat it as a re-config: replace the existing block with the new values.
