# Qualimetry AI App for OpenAI Codex

Catches policy violations *before* code review, not during. The Qualimetry AI App keeps every line of code Codex writes — and every reviewed file you touch — aligned with your organisation's coding standards, principles, and policies, automatically.

## What it does

- **Surfaces review findings the moment you open a reviewed file.** Whenever Codex reads a source file in your repo, you immediately see which standards, principles, and policy violations have been raised against it, plus a standards-compliant example of how to resolve them. No command, no manual lookup.
- **Keeps Codex's own code compliant from the first line.** When Codex writes or modifies code, it silently fetches your organisation's coding standards, general coding principles, secure coding principles, and policies for the file's language, and applies them as it types. High-severity violations are corrected before the code reaches you.
- **Triages rules-based analysis findings.** Existing bugs, security vulnerabilities, and code smells from your static analysis (Sonar-style severities: BLOCKER / CRITICAL / MAJOR / MINOR / INFO) are accessible from chat. Codex walks them in priority order: security first, reliability second, quality last. *(Qualimetry Enterprise.)*
- **Resolves dependency CVEs by upgrading to the next safe version.** Codex pulls the CVE list for your current branch, locates the manifest files, and proposes upgrades to the `NextSafeVersion` for each vulnerable package — auto-applying low-risk upgrades and asking before medium/high-risk ones, then re-validating with a build. *(Qualimetry Enterprise.)*

## Benefits

- Catch policy + standards violations *during authoring* and *before review*, not after.
- AI-written code is compliant by construction — no separate "lint pass" needed.
- One install, one setup, no further configuration per repo.
- Review feedback appears at the moment of context (when you open the file), not buried in a code-review tool you have to switch to.
- Standards live on your Qualimetry server; updating a policy there flows through to every developer's next edit, with no app release.

## Quick Start

This repo is a Codex *custom marketplace* — OpenAI's official Plugin Directory is *coming soon*, so for now Codex installs the plugin straight from the marketplace's git URL.

1. Open the Codex CLI in your terminal — type `codex` and press Enter.

2. At the prompt, type the following exactly and press Enter to register the marketplace:

       codex plugin marketplace add Qualimetry/codex-qualimetry-ai-app

3. Type the following exactly and press Enter to install the plugin:

       codex plugin install qualimetry-ai-app@qualimetry-ai

4. After install, type the following exactly and press Enter:

       /qualimetry-setup

5. Codex will ask for your Qualimetry server URL. Type it — for example `https://myorg.qualimetry.io/mcp/` — and press Enter. (Press Enter without typing anything to accept the default.)

6. Codex will ask for your access token. Paste it and press Enter.

7. Codex will write the entry to `~/.codex/config.toml` and tell you to **restart Codex**. Type `exit`, then run `codex` again.

8. After restart, type `/mcp` and confirm `qualimetry` is listed and connected.

That's it. From the next time Codex reads a source file in any of your repos, you'll see Qualimetry findings appear automatically. Re-run `/qualimetry-setup` any time to switch URL or rotate the token.

## Manual install (if your Codex version doesn't yet support marketplace add)

1. Copy the four skill directories from this repo's `skills/` into `~/.codex/skills/` (or `~/.agents/skills/`).
2. Open `config.snippet.toml` from this repo, copy its `[mcp_servers.qualimetry]` block, and paste it into `~/.codex/config.toml`.
3. Replace `REPLACE_WITH_YOUR_QUALIMETRY_ACCESS_TOKEN` with your actual token, and update the URL if needed.
4. Run `codex` and verify with `/mcp`.

## Where credentials live

The Qualimetry server URL and access token are stored in `~/.codex/config.toml` under `[mcp_servers.qualimetry]` — the same file Codex uses for every MCP server you have registered.

## License

Apache 2.0. See [LICENSE](LICENSE).

---

*Built on the [Qualimetry AI Skills](https://github.com/Qualimetry/qualimetry-ai-skills) workflow library.*
