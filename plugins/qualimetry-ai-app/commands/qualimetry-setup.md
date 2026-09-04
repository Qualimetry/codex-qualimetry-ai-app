---
description: Configure the Qualimetry MCP server URL and access token in ~/.codex/config.toml.
---

# Qualimetry: Setup (Codex)

Walk the user through configuring the Qualimetry MCP server entry in `~/.codex/config.toml`. Procedure:

1. Ask: **"What is your Qualimetry server URL? (default: `https://myorg.qualimetry.io/mcp/`)"**.
2. Ask: **"Paste your Qualimetry access token. The text will be visible in the chat — clear it after if you'd like."**
3. Validate the URL ends in `/mcp/` (or `/mcp`); append `/mcp/` if missing.
4. Read `~/.codex/config.toml` (create the file if it does not exist). Replace any existing `[mcp_servers.qualimetry]` block, or append a new one with:

   ```toml
   [mcp_servers.qualimetry]
   url = "<URL>"
   http_headers = { "qualimetry-access-token" = "<TOKEN>" }
   ```

5. Tell the user to **restart Codex** so the new MCP entry is picked up: type `exit`, then run `codex` again.
6. After restart, run `codex mcp list` (or use the `/mcp` command inside Codex) and confirm `qualimetry` is listed and connected.
7. Smoke-test by invoking the MCP tool `get_policies`.

End with the verbatim message:

> ✓ Qualimetry configured. You can now `/compliance-check`, or just open a reviewed file and Codex will surface findings automatically.

Never echo the token back in any subsequent message.
