# AI Tool Integration Research (Supermaven, claudecode.nvim, codex-cli)

This report researches whether/how to add an OpenAI `codex-cli` integration to the
existing Neovim setup (`nvim/lua/user/plugins/`), and how it would interact with the
two AI tools already wired in: `supermaven-nvim` (inline ghost-text completion) and
`coder/claudecode.nvim` (Claude Code driver via `folke/snacks.nvim`). It also checks
whether any of these three tools actually consume LSP data, and flags WSL/Windows
parity concerns. Findings are based on live web research (GitHub repos/issues, the
CodeCompanion.nvim docs site, and vendor blog posts), not memory alone, per the task
brief.

**Important status flag found during research:** Supermaven itself was sunset by its
acquirer (Cursor/Anysphere) on **Nov 21, 2025** — see §4. The repo's existing
`supermaven-nvim` integration should be re-evaluated independent of the codex-cli
question.

---

## 1. codex-cli integration options for Neovim

There is no single "obviously canonical" codex-cli plugin the way `claudecode.nvim`
is the de facto standard for Claude Code, but there are several real, live options,
in three shapes: (a) dedicated small terminal-driven plugins, (b) a general
multi-backend AI plugin with a maintained ACP adapter for Codex, and (c) plain
terminal/tmux fallback.

### (a) Dedicated `codex.nvim`-style plugins (claudecode.nvim-style, terminal-driven)

Two distinct, unrelated projects share the name `codex.nvim`:

- **`nwiizo/codex.nvim`** (https://github.com/nwiizo/codex.nvim) — the closer analog
  to `claudecode.nvim`. Its own README states it is explicitly modeled on
  `coder/claudecode.nvim`'s "command surface and side-panel workflow," is
  dependency-free pure Lua, targets Neovim 0.12+, and wraps the Codex CLI's
  "public CLI and app-server interfaces." Features include an interactive Codex
  terminal that survives window hiding, smart focus, resume/continue/fork/review/
  image/interrupt workflows, selection and file-tree context sending (nvim-tree,
  neo-tree, Oil, mini.files, netrw, Snacks picker), and an optional app-server
  backend with streamed Markdown, approval prompts, plans, and native diff buffers.
  It explicitly states **"macOS or Linux"** as a requirement (no Windows). It is
  young (first commit Aug 1, 2026; latest commit Aug 25, 2026 per repo history at
  time of research) and has only ~7 stars/2 forks — i.e. essentially unproven,
  low-adoption, single-maintainer. It self-describes as "a community project...not
  maintained or endorsed by OpenAI."
  (https://github.com/nwiizo/codex.nvim)

- **`johnseth97/codex.nvim`** (also referenced under a fork as `kkrampis/codex.nvim`
  in its own README lazy.nvim snippet) — an older, more established project (first
  commits ~Apr 2025, most recent Nov 20, 2025), 258 stars / 28 forks, notably more
  adopted than the nwiizo project. It wraps `@openai/codex` (installed via
  `npm install -g @openai/codex`) in a toggleable floating window / side panel
  (`:CodexToggle`), with a statusline helper and `-m` model flag passthrough. It
  predates OpenAI's later "codex-acp"/ACP work, so it is a plain terminal-toggle
  plugin, not an ACP client. No explicit Windows-support statement was found in the
  scraped README section, and its lazy.nvim example still needs verification for
  current CLI flag compatibility given code changes upstream since Nov 2025.
  (https://github.com/johnseth97/codex.nvim)

Neither of these two projects has anywhere near the star count (~3k) or apparent
maintenance cadence of `coder/claudecode.nvim`, so neither should be treated as an
established/maintained equivalent — both are community, low-adoption efforts.

### (b) ACP-based multi-backend plugins with maintained Codex support

This is the more promising path. The **Agent Client Protocol (ACP)** — created by
Zed, described as "the LSP moment for AI coding agents" — standardizes how editors
talk to agent CLIs. OpenAI ships an ACP bridge for Codex called **`codex-acp`**
(https://github.com/agentclientprotocol/codex-acp), and at least one popular,
actively maintained multi-backend Neovim AI plugin has a documented, first-class
adapter for it:

- **`olimorris/codecompanion.nvim`** — its official docs
  (https://codecompanion.olimorris.dev/configuration/adapters-acp) document a
  built-in `codex` ACP adapter, alongside adapters for `claude_code`, `gemini_cli`,
  `cursor_cli`, `copilot_cli`, `goose`, `kilocode`, `kimi_cli`, `kiro-cli`,
  `mistral_vibe`, `opencode`, `cline_cli`, and `cagent`. Setup for Codex specifically:
  install `codex-acp` (https://github.com/agentclientprotocol/codex-acp), then either
  rely on an `OPENAI_API_KEY` env var or set `auth_method = "chat-gpt"` for
  subscription-style ChatGPT auth — mirroring the subscription-vs-API-key choice this
  repo already made for Claude Code. Config example:
  ```lua
  require("codecompanion").setup({
    adapters = {
      acp = {
        codex = function()
          return require("codecompanion.adapters").extend("codex", {
            defaults = { auth_method = "api-key" }, -- or "chat-gpt"
            env = { OPENAI_API_KEY = "my-api-key" },
          })
        end,
      },
    },
  })
  ```
  CodeCompanion also documents a `claude_code` ACP adapter with the same
  subscription-token flow this repo's `claudecode.nvim` uses (`claude setup-token` →
  paste OAuth token, or an API key) — meaning CodeCompanion could, in principle,
  *replace* both `claudecode.nvim` and a dedicated codex plugin with one plugin and
  one keymap surface, at the cost of losing claudecode.nvim's diff-buffer/`snacks.nvim`
  UX polish and its narrower, well-tested feature set. This is a real architectural
  fork in the road worth flagging to the user even though it wasn't explicitly
  asked: keep two single-purpose plugins (current pattern) vs. consolidate onto one
  ACP-capable plugin. `codecompanion.nvim` itself is well-established (was found
  independently in multiple unrelated searches, has an active docs site, GitHub
  discussions specifically for adapter contributions, and 6.8k+ "AI Agents" listing
  per a third-party skills index) — clearly the most mature option surfaced in this
  research for a codex-cli integration that isn't a narrow single-purpose plugin.

- **`carlos-algms/agentic.nvim`** — surfaced via a Reddit post claiming "now supports
  ALL ACP providers: Copilot, Cursor..." This looks newer/less established than
  codecompanion.nvim; not independently verified against its repo in depth here,
  but worth a follow-up look if the user wants a lighter-weight ACP-only client
  instead of CodeCompanion's larger surface area.
  (https://github.com/carlos-algms/agentic.nvim,
  https://www.reddit.com/r/neovim/comments/1rz3347/)

- **`avante.nvim`** — has an open GitHub discussion, "codex OAuth support #2839"
  (https://github.com/yetone/avante.nvim/discussions/2839), and a Reddit post about
  "Avante Zen Mode" via ACP, suggesting avante.nvim is adding/has partial ACP
  support, but Codex-specific OAuth support looked like an open discussion rather
  than a shipped, documented feature at time of research — treat as unconfirmed,
  not a recommendation.

### (c) Plain terminal / tmux fallback

If no dedicated plugin is wanted, `codex` (the CLI, `npm install -g @openai/codex`)
runs identically well from a plain terminal split or tmux pane next to Neovim —
exactly like `claude` does — since neither plugin ecosystem is required for the CLI
itself to function; the plugins only add in-editor ergonomics (sending buffer/
selection content, toggling a window, diff application). This is a legitimate
minimal-integration option, consistent with how `claudecode.nvim`'s own README frames
its value-add as convenience on top of an already-standalone CLI tool.

### Recommendation shape (not a decision — flagging trade-offs)

- Lowest risk / smallest footprint: `nwiizo/codex.nvim` today is too new/low-adoption
  to trust as "established." `johnseth97/codex.nvim` is more adopted but is a plain
  terminal-toggle, predating the ACP ecosystem, and last touched ~10 months ago
  relative to today's date (Sep 2026) — maintenance cadence should be re-checked
  before adopting.
- Most future-proof / protocol-aligned: `codecompanion.nvim`'s `codex` ACP adapter,
  since it rides on OpenAI's own `codex-acp` bridge and the same plugin can also
  absorb Claude Code and other agents under one config surface — but that implies
  potentially replacing `claudecode.nvim` rather than adding a third plugin
  alongside it, which is a bigger decision than "just add codex."
- Zero-plugin fallback: a terminal/tmux pane running `codex` works today with no
  Neovim-side risk.

---

## 2. Does LSP choice affect AI tool context quality?

**Short answer: only `claudecode.nvim`'s Claude-Code MCP bridge is wired to the LSP
layer at all, and even there the connection is far thinner than it looks — the
model can only see `diagnostics`, not hover/references/symbols, and diagnostics
content is naturally more detailed under a fuller-fidelity server like Roslyn than
under `csharp_ls`, but that's the only path through which LSP choice could matter.**

Details, tool by tool:

- **`claudecode.nvim`**: This is the one place where LSP and AI tooling are
  genuinely connected, but the connection is narrower than the plugin's own README
  implies. `claudecode.nvim` runs a WebSocket "IDE" MCP server that Claude Code (the
  CLI) connects to via `/ide`. That server implements 10 MCP tools, including
  `getDiagnostics`, `getOpenEditors`, `getCurrentSelection`, `openFile`,
  `getWorkspaceFolders`, etc. **However**, per a triaged GitHub issue
  (https://github.com/coder/claudecode.nvim/issues/182, confirmed against Claude
  Code CLI `2.1.168` by decompiling the CLI binary), the Claude Code CLI itself
  hardcodes a client-side allowlist that keeps only two of those ten tools reachable
  by the model: `mcp__ide__getDiagnostics` and `mcp__ide__executeCode` (the latter
  Jupyter-specific, unusable from Neovim). Every other IDE tool — including
  "what file is open," "what's selected," "what's the workspace root" — is silently
  filtered out **by the Claude Code CLI, not by the plugin**, and the same
  restriction applies to Anthropic's own official VS Code extension (so
  claudecode.nvim is "at parity," not behind). Practical upshot: `getDiagnostics` is
  the *only* LSP-sourced signal Claude Code can pull passively through the IDE
  integration; `vim.diagnostic.get()` is what that tool surfaces, and that data
  originates from whatever LSP server publishes diagnostics — so **yes, in this one
  specific channel, LSP server choice (csharp_ls vs. a Roslyn-based server) would
  change what Claude Code can see**, because a more complete/faster/more accurate
  C# analyzer would produce richer diagnostics (e.g. more analyzer rules, faster
  refresh, better severity/location fidelity) for that one tool call. Everything
  else — "what does this file do," full buffer content, multi-file context — requires
  the user to explicitly `:ClaudeCodeAdd`/`:ClaudeCodeSend`/`@`-mention a file, which
  sends raw buffer/file text directly and has nothing to do with the LSP layer at
  all.
- **A codex-cli integration** (any of the options in §1): No evidence was found of
  any codex.nvim variant or the CodeCompanion `codex` ACP adapter reading Neovim's
  LSP client state (diagnostics, hover, references) at all. The ACP protocol as
  implemented for `codex-acp` is about the editor and the agent process exchanging
  session/file-content/permission messages, not routing LSP data. These integrations
  send buffer/file/selection text directly (same mechanism as claudecode.nvim's
  manual-send path) — LSP and the AI agent run fully in parallel, unconnected.
- **`supermaven-nvim`**: Confirmed independent of LSP entirely. It registers as an
  `nvim-cmp`/`blink.cmp` completion *source* purely for menu-integration purposes
  (so it can render an icon via `lspkind`, and appear alongside LSP-derived
  completion items in the same popup) — that's cosmetic UI plumbing, not data
  sharing. Its actual completions come from sending buffer text to its own backend
  agent process; a GitHub issue titled "supermaven-nvim sends the entire buffer to
  the server even when..." (https://github.com/supermaven-inc/supermaven-nvim/issues/85)
  corroborates that its context model is "send buffer text to remote inference,"
  not "consult the LSP client." LSP diagnostics/hover are never referenced in its
  README's configuration surface.

**Conclusion for the LSP-choice question**: Switching from `csharp_ls` to a
Roslyn-based server (e.g. `roslyn.nvim`) would only affect AI-tool context quality
through the single `getDiagnostics` MCP tool inside `claudecode.nvim`'s Claude Code
integration — everything else (both codex-cli options and Supermaven, plus most of
what claudecode.nvim actually does day-to-day) reads buffer/file text directly and
is completely LSP-agnostic. This is a real but narrow benefit, not a broad "AI tools
get smarter with a better LSP" story.

---

## 3. Conflicts between Supermaven and a codex-cli integration

The existing Supermaven-vs-blink.cmp conflict in this repo is about **inline ghost
text vs. a popup completion menu both wanting `<Tab>`-family keys** — Supermaven's
own default keymaps (`<Tab>` accept, `<C-]>` clear) collide with blink.cmp's
`<Tab>`-driven menu navigation, which is why this repo's `supermaven.lua` remaps to
`<C-y>`/`<C-]>`/`<C-j>` specifically to dodge that clash (see the file's own comment,
"Disable its own Tab/Enter keymaps so it doesn't fight blink.cmp").

None of the codex-cli integration options researched in §1 are inline-completion
providers — they are all terminal/side-panel/chat-style tools (a floating terminal,
a side panel, or a chat buffer), the same shape as `claudecode.nvim`. That means:

- **No completion-popup collision is expected.** A codex.nvim-style plugin or a
  CodeCompanion `codex` adapter does not register as a `blink.cmp`/`nvim-cmp` source
  the way Supermaven does, so there's no analog to the Tab-key fight.
- **Keymap-surface collision is the real risk**, same category as claudecode.nvim's
  own `<leader>a*` namespace choice in this repo. If a codex integration is added
  under, say, `<leader>a*` too (natural choice — "AI"), it will collide with the
  existing Claude Code bindings (`<leader>ac`, `<leader>af`, `<leader>ar`, etc., see
  `nvim/lua/user/plugins/claudecode.lua`) unless given a distinct leader prefix
  (e.g. `<leader>x*` or `<leader>o*` for "cOdex/OpenAI", or nesting under
  `<leader>ax*`). No documented convention for this was found in the researched
  material — it's a decision the user/maintainer has to make locally, not something
  resolved upstream by any plugin.
- **Terminal-mode key collisions inside the floating/side-panel window** are the
  other category worth checking case by case: `johnseth97/codex.nvim` changed its
  own toggle key from `<Esc>` to `<q>` specifically to avoid clashing with "the
  Codex CLI's newer interrupt sequence (`<Esc><Esc>`)" per its commit history — this
  is the same kind of terminal-mode key-stealing problem `claudecode.nvim` and
  Supermaven don't have to deal with (Supermaven isn't a terminal at all; Claude
  Code's own interrupt/escape handling inside its floating terminal is a similar
  concern users have filed issues about, e.g.
  https://github.com/coder/claudecode.nvim/issues/53, "Can't switch panes using C-*
  if in Claude input mode").
- No third-party config was found that documents resolving a *Supermaven-vs-codex*
  collision specifically (searches turned up the Supermaven-vs-blink.cmp pattern
  only in the context of this repo's own established practice, and codex-vs-
  Claude-Code terminal escape conflicts within their own single plugins) — so there
  is no existing community precedent to cite for a three-way Supermaven +
  claudecode.nvim + codex-integration keymap layout; this repo would be charting
  new territory there, but the risk is low because the collision surface is just
  leader-prefix namespacing, not core functionality.

---

## 4. Platform parity: WSL-ubuntu/bash vs. Windows/PowerShell

| Tool | Native Windows | WSL (Ubuntu/bash) | Notes |
|---|---|---|---|
| `claude` CLI (Claude Code) | Supported. Install via `irm https://claude.ai/install.ps1 \| iex` in PowerShell. Runs commands via the PowerShell tool by default (or Git Bash's Bash tool if Git for Windows is present). **Sandboxing is not supported on native Windows.** | Supported, treated as a first-class option by Anthropic's own docs (install via the same `curl \| bash` installer used on macOS/Linux). **Sandboxing IS supported under WSL 2** (not WSL 1). | Per official docs (https://code.claude.com/docs/en/setup): native Windows and WSL are separate installs with separate binaries and, implicitly, separate credential/config state — you install and authenticate independently in each shell. WSL setups "do not need Git for Windows." If sandboxed command execution matters, WSL 2 is the only option that supports it. |
| `codex` CLI (OpenAI Codex) | Supported natively — `npm install -g @openai/codex` from PowerShell, no WSL required. Sign-in is a browser-based OAuth flow. | Also supported, same `npm install -g @openai/codex` inside the WSL shell. One documented quirk: "the browser-based sign-in sometimes shows you a code instead of redirecting back automatically" under WSL — user must paste the code manually. | Source: https://www.codeagentswarm.com/en/guides/codex-cli-on-windows. Like Claude Code, this is two independent npm-global installs (Windows npm vs. WSL npm) with separate credential stores — signing in on one side does not carry over to the other. Recommendation from that source: keep project files on the Linux filesystem within WSL for performance if using WSL. |
| Supermaven (`supermaven-nvim`) | **Status change supersedes the WSL/Windows question**: Supermaven was sunset by Cursor/Anysphere on **Nov 21, 2025** (https://supermaven.com/blog/sunsetting-supermaven). Cursor stated it would continue free autocomplete inference "for existing customers" on Neovim and JetBrains specifically, but will no longer support "agent conversations," and pushes new/VS Code users toward Cursor's own Tab completion instead. No Windows-vs-WSL-specific bug reports were found for `supermaven-nvim` itself (its own README and issue tracker don't call out platform-specific auth/binary problems), but the plugin downloads its own per-OS backend agent binary and manages auth via its own separate flow — following the same "one login per install" pattern as Claude Code and Codex CLI, so native-Windows Neovim and WSL Neovim would each need their own Supermaven login state if kept as two separate deployments. Given the sunsetting announcement, this integration's long-term viability (not just its WSL/Windows parity) is now the more important question to flag to the user. |

**General platform-parity theme across all three tools**: none of them share
credentials/config between a native-Windows install and a WSL install automatically
— each is a fully separate binary + auth handshake per shell, which matches this
repo's existing "deployed identically to WSL-ubuntu/bash and native Windows/
PowerShell" model but means **the user has to log into each AI tool twice** (once
per OS-side install) if they use both environments, for all three tools. No
WSL-specific clipboard integration issues were found in this research for any of
the three tools specifically (clipboard interop between WSL and Windows Neovim
instances is a broader, tool-independent WSL/Neovim topic not covered by the
sources found here) — flagging this as **unverified** rather than claiming there is
no issue.

---

## Sources

- https://github.com/nwiizo/codex.nvim
- https://github.com/johnseth97/codex.nvim
- https://codecompanion.olimorris.dev/configuration/adapters-acp
- https://github.com/olimorris/codecompanion.nvim
- https://github.com/agentclientprotocol/codex-acp (referenced from CodeCompanion docs)
- https://github.com/carlos-algms/agentic.nvim (surfaced, not deeply verified)
- https://www.reddit.com/r/neovim/comments/1rz3347/agenticnvim_now_supports_all_acp_providers/
- https://github.com/yetone/avante.nvim/discussions/2839
- https://github.com/coder/claudecode.nvim
- https://github.com/coder/claudecode.nvim/issues/182 (getDiagnostics allowlist root-cause analysis)
- https://github.com/coder/claudecode.nvim/issues/53
- https://github.com/supermaven-inc/supermaven-nvim
- https://github.com/supermaven-inc/supermaven-nvim/issues/85
- https://supermaven.com/blog/sunsetting-supermaven
- https://supermaven.com/blog/cursor-announcement
- https://cursor.com/blog/supermaven
- https://code.claude.com/docs/en/setup
- https://claudefolio.com/guides/claude-code-on-windows-powershell
- https://www.codeagentswarm.com/en/guides/codex-cli-on-windows
- Local repo files read for context: `nvim/lua/user/plugins/supermaven.lua`,
  `nvim/lua/user/plugins/claudecode.lua`, `nvim/lua/user/plugins/completion.lua`
