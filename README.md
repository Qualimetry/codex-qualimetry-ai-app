# Qualimetry AI App for OpenAI Codex

Catches policy violations *before* code review, not during. The Qualimetry AI App keeps every line of code Codex writes — and every reviewed file you touch — aligned with your organisation's coding standards, principles, and policies, automatically.

## What it does

- **Surfaces review findings the moment a reviewed file is opened.** When Codex reads a source file in your repo, the bundled hook fetches which standards, principles, and policy violations have been raised against it, plus a standards-compliant example of how to resolve them, and feeds them straight into Codex's context. When the current branch has an open pull request, the findings are automatically scoped to the issues raised on the pull request's new code. *(No extra installs — the hook uses only `git` and `curl`/`wget` on macOS/Linux, and plain PowerShell on Windows. Codex asks you to review and trust the hook on first load — approve it to enable this.)*
- **Keeps Codex's own code compliant from the first line.** When Codex writes or modifies code, the bundled skills silently fetch your organisation's coding standards, general coding principles, secure coding principles, and policies for the file's language, and apply them as it types. High-severity violations are corrected before the code reaches you.
- **Triages rules-based analysis findings.** Existing bugs, security vulnerabilities, and code smells from your static analysis (Sonar-style severities: BLOCKER / CRITICAL / MAJOR / MINOR / INFO) are accessible from chat. Codex walks them in priority order: security first, reliability second, quality last. Supply a pull-request number to target the issues raised on the pull request's new code instead of the whole branch. *(Qualimetry Enterprise.)*
- **Resolves dependency CVEs by upgrading to the next safe version.** Codex pulls the CVE list for your current branch, locates the manifest files, and proposes upgrades to the `NextSafeVersion` for each vulnerable package — auto-applying low-risk upgrades and asking before medium/high-risk ones, then re-validating with a build. *(Qualimetry Enterprise.)*

## Benefits

- Catch policy + standards violations *during authoring* and *before review*, not after.
- AI-written code is compliant by construction — no separate "lint pass" needed.
- One install, one setup, no further configuration per repo.
- Standards live on your Qualimetry server; updating a policy there flows through to every developer's next edit, with no app release.

## Quick Start

This repo is a Codex *custom marketplace* — OpenAI's official Plugin Directory is *coming soon*, so for now Codex installs the plugin straight from this repo.

1. In your **terminal** (not inside Codex), run these two commands — note the verb is `add`, not `install`:

       codex plugin marketplace add Qualimetry/codex-qualimetry-ai-app
       codex plugin add qualimetry-ai-app@qualimetry-ai

2. Start Codex by typing `codex` and pressing Enter.

3. When Codex asks you to **review and trust the plugin's on-read hook**, approve it. (Hooks never run before you trust them; the hook is what surfaces findings automatically when files are opened.)

4. Ask Codex to **"set up qualimetry"**. The bundled `qualimetry-setup` skill asks for your Qualimetry server URL — for example `https://myorg.qualimetry.io/mcp/` — and your access token, then writes them to `~/.codex/config.toml`.

5. **Restart Codex** so the new MCP entry is picked up: type `exit`, then run `codex` again.

6. Type `/mcp` and confirm `qualimetry` is listed and connected.

That's it. From the next time Codex reads a source file in any of your repos, Qualimetry findings flow into its context automatically. Re-run the `qualimetry-setup` skill any time to switch URL or rotate the token.

## Manual install (without the plugin marketplace)

1. Copy the skill directories from this repo's `plugins/qualimetry-ai-app/skills/` into `~/.codex/skills/` (or `~/.agents/skills/`).
2. Open `config.snippet.toml` from this repo, copy its `[mcp_servers.qualimetry]` block, and paste it into `~/.codex/config.toml`.
3. Replace `REPLACE_WITH_YOUR_QUALIMETRY_ACCESS_TOKEN` with your actual token, and update the URL if needed.
4. Run `codex` and verify with `/mcp`. (The automatic on-read hook is only available via the plugin install.)

## Where credentials live

The Qualimetry server URL and access token are stored in `~/.codex/config.toml` under `[mcp_servers.qualimetry]` — the same file Codex uses for every MCP server you have registered. The on-read hook reads the same entry; nothing is duplicated elsewhere.

## Troubleshooting

**`marketplace add` fails with "does not contain a supported manifest"** — your Codex version predates repo marketplaces. Update Codex (`codex update`) and retry.

**Findings do not appear when files are opened** — in order of likelihood: (1) you haven't trusted the plugin's hook yet — Codex prompts on first load; (2) the file hasn't been reviewed on the Qualimetry server yet. The skills (ask for a "compliance check") work independently of the hook. (If `jq` is installed the findings arrive as a grouped digest; without it, as a raw payload — both work.)

**`/mcp` doesn't list qualimetry** — restart Codex; the MCP entry is read at launch.

## License

Apache 2.0. See [LICENSE](LICENSE).

---

*Built on the [Qualimetry AI Skills](https://github.com/Qualimetry/qualimetry-ai-skills) workflow library.*
