# Roslyn LSP for Unity: Windows-host TCP bridge vs. Windows-only roslyn.nvim

## Summary and recommendation

Two architectures were researched for getting full-fidelity Roslyn LSP
support for Unity C# in this repo's dual WSL2/native-Windows Neovim setup:

- **Architecture A (bridge):** run `Microsoft.CodeAnalysis.LanguageServer`
  natively on Windows, wrapped by a small third-party adapter
  (`walcht/LSP-TCP-socket-adapter`) that exposes it over a TCP socket; WSL2
  Neovim's `roslyn.nvim`/`nvim-lspconfig` connects to that socket instead of
  spawning a local process.
- **Architecture B (Windows-only):** only run `roslyn.nvim` on native Windows
  Neovim; gate it off entirely on WSL2 (via lazy.nvim's `cond`), and keep
  `csharp_ls` as WSL2's independent, fully local C# LSP.

**Bottom line recommendation: Architecture B (Windows-only roslyn.nvim,
`cond`-gated; WSL2 keeps `csharp_ls`).** The bridge (Architecture A) is real,
documented by its own author, and reportedly performs well — but it is
**brand new (built the week of Dec 1–10, 2025, i.e. about three months before
this research), untested beyond one author's own admission ("haven't tested
this yet thoroughly"), has no daemonization/persistence story, and no
documented reconnect behavior** if the Windows-side process dies or the
machine sleeps. It also has zero third-party field reports beyond the GitHub
issue thread where it was invented — no Reddit/blog confirmations of
day-to-day reliability were found. Architecture B, by contrast, needs no new
moving part: WSL2 keeps using `csharp_ls`, completely independent of anything
happening on the Windows side, and a `cond` gate on the lazy.nvim spec is a
well-documented, one-line, officially supported lazy.nvim mechanism. Given
this repo already treats `csharp_ls` as WSL2's daily driver and this is a
single maintainer's personal dotfiles (not something that needs the single
best possible LSP fidelity in WSL at the cost of new failure surface), the
operational simplicity of B outweighs A's fidelity gain for the WSL side.
Architecture A is worth revisiting once the adapter has a few months of
field use and/or gains a persistence/reconnect story.

---

## Architecture A: TCP-bridge (single Windows-native Roslyn instance)

### 1. What `walcht/LSP-TCP-socket-adapter` is and how it works

It is a small **standalone .NET console app that runs on the Windows side**,
built from a ~1 file `Program.cs` (plus `Logger.cs`). Per its README ("About"
section):

> Language Server (LS) TCP socket adapter for LSP servers that do not offer a
> TCP socket endpoint and only expect communication via stdin/stdout or a
> pipe. An example of such LS is the official C# LS Roslyn LS.
>
> This adapter is proven to be useful, for instance, for: Neovim LSP client
> on WSL2 <=> Windows LS host setup.

Architecture, exactly as diagrammed in the README (and matching wording in
`walcht/neovim-unity`'s README):

```
Neovim LSP Client ----- LSP IP Socket Adapter ------- Roslyn LS
                         |            |                  |
             + - - - - - +            |                  + - - - +
             |              forward msgs from  both ends           |
     communication via      and adjust Neovim LSP client    communication via
     IP socket:             URIs to  valid Windows  URIs      stdin/stdout
     <windows-host-ip>:<port>
```

- The adapter process **runs on Windows** (it's a `.exe`), spawning
  `Microsoft.CodeAnalysis.LanguageServer` (via `dotnet ...`) as its own local
  child subprocess and talking to it over normal **stdin/stdout** (the only
  channel Roslyn LS supports — it has no native TCP/pipe listener).
- Simultaneously, the adapter **listens on a TCP socket** (`<host>:<port>`)
  and relays LSP JSON-RPC messages between that socket and the child
  process's stdio, in both directions.
- Critically, it also **rewrites URIs/paths in the LSP traffic** between the
  WSL-style path (`/mnt/c/...`) the Neovim client sends and the native
  Windows path (`C:\...`) Roslyn LS expects, via the `--mount` flag (see
  below). This URI translation is the actual fix for the root-cause bug from
  `roslyn.nvim` issue #266 — it's not just a dumb byte-for-byte TCP↔stdio
  pipe, it actively patches the path mismatch that broke same-OS-WSL Roslyn.
- The author explicitly tried and **failed to get WSL2↔Windows Unix domain
  sockets working first** ("Couldn't get a Unix domain socket to connect
  between WSL2 and Windows (even though there is a claim that that should be
  possible). I fell back to TCP socket...", `walcht/neovim-unity` issue #21,
  Dec 1 2025) — TCP is a fallback, not the original design choice, which is
  a mild reliability yellow flag (the "cleaner" IPC path didn't work for the
  author).

Confirmed: nothing here runs inside WSL except the standard Neovim LSP
client itself. Source: https://github.com/walcht/LSP-TCP-socket-adapter
(README, "About" / architecture diagram), corroborated in
https://github.com/walcht/neovim-unity#setting-neovim-in-wsl-with-unity-projects-in-windows
and https://github.com/walcht/neovim-unity/issues/21.

### 2. Exact setup steps — Windows side

From the adapter's own `--help` output (quoted verbatim from the README):

```
Usage:
  LSPTCPSocketAdapter <host> <port> <filename> <arguments> [options]

Arguments:
  <host>       IPv4 of the IP socket endpoint through which this LSP adapter communicates.
  <port>       Port of the IP socket endpoint through which this LSP adapter communicates.
  <filename>   Executable that launches the language server (e.g., dotnet) or the LS directly (passed to StartInfo.FileName).
  <arguments>  Arguments that are passed as-is to the provided filename command (passed to StartInfo.Arguments).

Options:
  --logFile <logFile>              Log file path...
  --logLevel <ERROR|INFO|WARNING>  Log level of this adapter: INFO | WARNING | ERROR
  --mount <mount>                  Windows drive mount path in WSL2. If supplied, URIs and paths will be adjusted
                                    from WSL2 to Windows by removing the leading mount path. E.g., "/mnt/c"
  -?, -h, --help                   Show help and usage information
  --version                        Show version information
```

Concrete invocation (quoted from both the adapter README and the
`neovim-unity` README, they match):

```
LSPTCPSocketAdapter.exe <windows-host-ip> <port> dotnet "<roslyn-ls-path> --logLevel=Error --extensionLogDirectory=log --stdio" --mount=/mnt/c
```

Install options are: grab the prebuilt `.exe` from the
[releases page](https://github.com/walcht/LSP-TCP-socket-adapter/releases),
or build from source (`dotnet build --configuration Release`, requires
.NET >= 9.0; output at `./bin/Release/net9.0/LSPTCPSocketAdapter.exe`).

**Persistence: this is a foreground/manual process, not a service.** Nothing
in the README, the adapter's own repo, or either GitHub issue thread
describes wrapping it as a Windows Service, a Scheduled Task, or any other
auto-start/keep-alive mechanism. It reads as "you run this .exe in a
terminal each session you want to use it," with the burden of automating
that (a scheduled task, a shortcut, a wrapper batch script) left entirely to
the user. **This is a confirmed gap, not an assumption on my part** — I
searched the repo and both issue threads specifically for "service",
"scheduled task", "persistent", "startup", "autostart" and found no mention.

### 3. Exact setup — WSL/Neovim side

The `neovim-unity` README's own recommended config snippet, quoted verbatim:

```lua
local roslyn_ls_config = {
    -- ...
    cmd = vim.lsp.rpc.connect(<windows-host-ip>, <port>),
    -- ...
    }
```

This is the actual mechanism, and it answers the question in the task
directly: **not** an `ncat`/`socat` stdio↔TCP shim script — Neovim's LSP
client has a **built-in** helper, `vim.lsp.rpc.connect(host, port)`, that
returns a function suitable for use as `cmd` directly. Nvim's LSP `cmd` field
normally expects a local-process argv table, but it also accepts a function
returned by `vim.lsp.rpc.connect()`, which internally opens a raw TCP
connection and speaks JSON-RPC over it instead of spawning a subprocess. No
external `nc`/`ncat`/`socat` glue is needed on the WSL side at all — this
sidesteps the traditional "turn a TCP LSP into stdio" trick because Neovim's
LSP client natively supports TCP transport via this API.

`<port>` is any free TCP port (example given: `56777`). This config
presumably needs to be wired into whatever `roslyn.nvim` or
`vim.lsp.config()` mechanism is normally used to define the `roslyn` server;
the README doesn't show the full `roslyn.nvim`-specific integration (e.g.,
whether `roslyn.nvim`'s own setup function accepts an override `cmd`, or
whether this requires bypassing `roslyn.nvim` and configuring the server
directly via `vim.lsp.config('roslyn', {...})`) — **this integration detail
is not confirmed in the docs and would need to be verified empirically
against the current `roslyn.nvim` API** if this path is pursued.

### 4. Networking specifics

The README's own instructions assume **default WSL2 NAT networking**, not
mirrored mode. Step 1 of the README's setup:

```
ip route show | grep -i default | awk '{ print $3}'
```

with the note: "`<windows-host-ip>` now refers to the outputed IP... For a
program running on WSL2 (a whole different machine - somewhat) to
communicate with a program running on Windows host, you have to get its
IP." This is the classic WSL2-NAT-mode "find the Windows host gateway IP via
the default route" trick, and the README links Microsoft's own networking
guide for justification.

Cross-checked against Microsoft's current WSL networking docs
(https://learn.microsoft.com/en-us/windows/wsl/networking, fetched during
this research):

> By default WSL uses a NAT based architecture, and we recommend trying the
> new **Mirrored networking mode** to get the latest features and
> improvements.
>
> When WSL2 is running with the new mirrored mode, the Windows host and WSL2
> VM can connect to each other using `localhost` (127.0.0.1) as the
> destination address, so the trick of using a query peer's IP address is
> not required.
>
> On machines running **Windows 11 22H2 and higher** you can set
> `networkingMode=mirrored` under `[wsl2]` in `.wslconfig` to enable mirrored
> mode... Connect to Windows servers from within Linux using the localhost
> address `127.0.0.1`.

**This means the `neovim-unity` docs are written against the older/default
NAT networking mode**, not the mode Microsoft now recommends. If this repo's
Windows machine is on Windows 11 22H2+ and mirrored mode is enabled (or
gets enabled), the entire `ip route show | grep default` step becomes
unnecessary and `<windows-host-ip>` can simply be `localhost`/`127.0.0.1` —
simpler and immune to the host IP changing across WSL restarts (the default
NAT gateway IP is **not guaranteed stable** across reboots, which is a
second latent fragility in the documented setup: any script/config that
hardcodes the discovered IP would need to be re-run or the IP re-discovered
after a Windows/WSL restart, unless mirrored mode is used).

### 5. Reliability/failure modes

**No documentation was found — from the adapter repo, `neovim-unity`, or
either GitHub issue thread — describing what happens on:**
- Windows-side adapter/Roslyn process crashing while WSL Neovim is attached
- Windows sleep/hibernate/wake
- Unity Editor restart while the bridge is live
- Automatic reconnection behavior in `roslyn.nvim` or plain Neovim LSP client

This is a genuine gap, not something I'm inferring negatively without
basis: I specifically searched GitHub issues, Reddit r/neovim, and general
web search for real-world usage reports of this specific adapter and found
**none beyond the two GitHub issue threads where the tool was invented**
(`seblyng/roslyn.nvim#266` and `walcht/neovim-unity#21`, both closed
Dec 10–11, 2025). No blog posts, no Reddit threads, no "I've been using this
for N weeks and here's what broke" reports exist yet — the tool is roughly
three months old as of this research (2026-09-02) and appears to have a very
small user base so far (the two comments who reacted positively in the issue
thread, `sebastianstudniczek` and `codevogel`, said only that they intended
to *try* it, not that they'd used it in production).

What **is** documented: Neovim's LSP client generally does not auto-restart
a dead LSP connection; `vim.lsp.rpc.connect()` establishes a single TCP
connection at server-start time, and if that connection drops (peer
process died, socket reset), the general Neovim LSP client behavior (not
adapter-specific — this is standard `vim.lsp` behavior, not confirmed against
this specific adapter/config combination) is that the client reports the
server as exited and the user must manually re-trigger it (e.g.
`:LspRestart` or reopening the buffer) rather than it transparently
reconnecting. **This is an inference from general Neovim LSP client
behavior, not something confirmed in the adapter's own docs** — the adapter
README does not discuss reconnection at all.

### 6. Resource/performance footprint

The only concrete performance claim is from the adapter's author, walcht, in
`seblyng/roslyn.nvim#266` (Dec 4, 2025):

> Essentially - run Neovim on WSL2 and Roslyn LS on Windows via an IP
> Sockets adapter... **The performance is similar to running everything
> natively.**

And again (Dec 10, 2025):

> The performance is (expectedly) really good - **but I haven't tested this
> yet thoroughly** (due to time limitations).

So the "similar to native" claim is the author's own qualitative impression,
explicitly caveated by the same author as not yet rigorously tested. No
numbers (latency, memory, CPU) were published anywhere found. No independent
third party has published a benchmark or even a confirmation of "yes, this
feels fast to me" beyond intent-to-try comments.

---

## Architecture B: Windows-only Roslyn (no bridge; WSL keeps csharp_ls)

### 7. Gating `roslyn.nvim` to native Windows only via lazy.nvim

lazy.nvim's plugin spec has a documented `cond` field, confirmed from the
official spec docs (https://lazy.folke.io/spec, "Spec Loading" table):

> **cond** | `boolean?` or `fun(LazyPlugin):boolean` | Behaves the same as
> `enabled`, but **won't uninstall the plugin** when the condition is
> `false`. Useful to disable some plugins in vscode, or firenvim for
> example.

This is exactly the right primitive for a config shared across OSes via one
synced dotfiles repo/lockfile: `cond` (unlike `enabled`) does not trigger
lazy.nvim to uninstall the plugin's files when the condition evaluates
false on one OS, so the plugin's install state / lockfile entry stays
consistent between the WSL and Windows checkouts of this repo — only its
*loading* is conditional per-OS. The standard idiom (matching the OS-check
pattern already implied by the repo's existing WSL/Windows dual deployment)
is:

```lua
{
  "seblyng/roslyn.nvim",
  cond = function() return vim.fn.has("win32") == 1 end,
  -- ...
}
```

`vim.fn.has('win32')` is Neovim's own standard native-Windows detection
(true for native Windows Neovim, **false** under WSL2 — WSL2's Neovim
reports as Linux, which is exactly the split this repo needs). I did not
find a public real-world dotfiles repo using this exact `roslyn.nvim` +
`cond` + `win32` combination (the searches for "lazy.nvim cond windows-only
example dotfiles" surfaced only generic `cond`/`enabled` documentation and
unrelated vscode/firenvim examples, not a Unity-specific precedent) — this
pattern is a direct, faithful application of `cond`'s documented semantics
rather than a copied example, and should be treated as inferred-but-solid,
not "confirmed via a known working config in the wild."

### 8. Mason's per-platform binary handling for `Crashdummyy/mason-registry`'s `roslyn` package

I fetched the actual package definition directly from the registry
(https://raw.githubusercontent.com/Crashdummyy/mason-registry/master/packages/roslyn/package.yaml):

```yaml
source:
  id: pkg:github/Crashdummyy/roslynLanguageServer@5.12.0-1.26428.1
  asset:
    - target: darwin_x64
      file: microsoft.codeanalysis.languageserver.osx-x64.zip:libexec/
      bin: libexec/Microsoft.CodeAnalysis.LanguageServer
    - target: darwin_arm64
      ...
    - target: linux_x64
      file: microsoft.codeanalysis.languageserver.linux-x64.zip:libexec/
      bin: libexec/Microsoft.CodeAnalysis.LanguageServer
    - target: linux_arm64
      ...
    - target: win_x64
      file: microsoft.codeanalysis.languageserver.win-x64.zip:libexec/
      bin: libexec/Microsoft.CodeAnalysis.LanguageServer.exe
    - target: win_arm64
      ...
```

This confirms Mason's registry model is exactly the general-purpose
per-platform `asset`/`target` list mechanism, and **this specific `roslyn`
package explicitly lists both `linux_x64` and `win_x64` assets** (among
others). Mason's installer selects the matching `target` entry for whatever
OS/arch it's currently running on and downloads only that one — it does
**not** attempt to install assets for other platforms, and does **not**
error simply because other platforms are also listed.

Consequence for this repo: running the exact same `mason.setup({registries
= {...}})` and `ensure_installed = {"roslyn"}` unconditionally on both WSL2
and native Windows **will not error on either side** — WSL2's Mason install
pulls `microsoft.codeanalysis.languageserver.linux-x64.zip`, Windows' pulls
the `.win-x64.zip` variant, each into that OS's own separate Mason data
directory (already naturally separate since WSL2 and Windows are distinct
filesystems/environments in this repo's existing dual-deployment setup). So
**Architecture B does not actually need to gate the Mason install step at
all** — only `roslyn.nvim`'s LSP *activation* (via `cond`) needs to be
Windows-only; letting Mason install the (unused, harmless) Linux Roslyn
binary on WSL2 alongside `csharp_ls` costs only some disk space, not
correctness.

For general robustness context: when a Mason package's registry entry does
**not** list an asset for the current platform, Mason's documented failure
mode (per multiple community reports — e.g. rust-analyzer/clangd/ocamllsp
"the current platform is unsupported" errors surfaced in Reddit/Stack
Overflow threads found during this research) is a clear, visible
**installation-time error** ("The current platform is unsupported"), not a
silent no-op and not a runtime crash later. This doesn't apply to `roslyn`
here since both `linux_x64` and `win_x64` are present, but it's the general
behavior worth knowing if any other Mason package in this repo's config
ever lacks a target for one of the two OSes.

---

## Comparison and recommendation

| | Architecture A (TCP-bridge) | Architecture B (Windows-only) |
|---|---|---|
| **One-time setup complexity** | Higher: build/download adapter binary on Windows, discover WSL2 NAT gateway IP (or configure mirrored networking), wire a non-standard `vim.lsp.rpc.connect(host, port)` `cmd` into `roslyn.nvim`'s config, and reverse-engineer how to override `roslyn.nvim`'s `cmd` (not documented) | Low: one `cond` predicate in the lazy.nvim spec; everything else (Mason install, `roslyn.nvim` setup, `Crashdummyy` custom registry) is otherwise identical to a normal single-OS `roslyn.nvim` install, just Windows-only |
| **Per-session friction** | High, unless the user builds their own auto-start wrapper: the adapter `.exe` is a manually-run foreground process with **no documented service/scheduled-task/persistence story** — confirmed absent from all sources checked | None beyond normal `roslyn.nvim` startup (already required for Architecture B regardless) |
| **New moving parts / blast radius if something breaks** | A third process (the Windows-side adapter) plus a network hop that WSL Neovim now depends on for **all** WSL C# LSP support. If the adapter crashes, Windows sleeps, or the discovered NAT IP goes stale after a reboot, **WSL2 loses Roslyn entirely** with no documented auto-recovery — user must notice, and manually restart the adapter and/or re-fetch the IP and/or `:LspRestart` in Neovim | None: WSL2's `csharp_ls` is fully local and independent of anything on the Windows side. If Windows Roslyn/Unity/the adapter (Architecture A doesn't even exist here) has any problem, WSL2 editing is entirely unaffected |
| **Maturity / field validation** | ~3 months old at time of research (built Dec 2025); zero independent user reports of sustained day-to-day use found (only the inventor's own qualitative "performance is similar to native," itself caveated as "not tested thoroughly"); Unix-domain-socket approach was tried first and abandoned as not working, TCP was the fallback | Both halves (`roslyn.nvim` on native Windows, `csharp_ls` on WSL2) are the status quo / already-vetted-per-OS approaches from this repo's own prior research (`01-csharp-lsp-servers.md`); `cond` is a stable, long-documented lazy.nvim feature |
| **LSP fidelity delivered to WSL2** | Full Roslyn LSP fidelity in WSL2 (if it works reliably) | WSL2 stays on `csharp_ls`'s smaller feature surface (per prior research: weaker code actions/refactorings, less semantic highlighting depth than Roslyn LSP) |
| **Networking assumptions baked into the docs** | Assumes default WSL2 **NAT** mode (`ip route show` trick); doesn't reflect Microsoft's now-recommended **mirrored** mode, which would simplify but wasn't accounted for in the source docs | N/A — no cross-machine networking involved |

**Recommendation for this repo:** adopt **Architecture B**. The specific
reasons, weighted for this repo's actual situation (single maintainer,
personal dotfiles, switches between WSL2 and native Windows for Unity work,
already has a working `csharp_ls` setup on WSL2 per prior research):

1. The bridge trades a one-line `cond` gate for an ongoing operational
   dependency (a manually-started Windows process with no persistence
   story) that, when it breaks, breaks **all** WSL2 C# LSP support rather
   than degrading gracefully.
2. The fidelity gain (Roslyn vs. `csharp_ls` in WSL2) is real but was
   already accepted as a tradeoff in the prior research's baseline
   recommendation (`csharp_ls` for WSL2) — this task doesn't change that
   calculus, it just re-confirms a fancier alternative exists and is
   currently too immature to trust for daily-driver use.
3. If the bridge matures — gains a documented Windows Service/Scheduled
   Task wrapper, gets a few more months of field use with confirmed
   reconnect behavior, and/or the WSL2 host machine is moved to mirrored
   networking mode (removing the stale-IP fragility) — it's worth
   revisiting. Nothing about adopting Architecture B now forecloses
   switching later; the two are not architecturally entangled (Architecture
   A is purely additive on top of what B already has).

---

## Sources

- https://github.com/walcht/neovim-unity — README (`Setting Neovim in WSL
  with Unity Projects in Windows` section, `Known Limitations`, `FAQ`)
- https://github.com/walcht/LSP-TCP-socket-adapter — README (`About`,
  `Installation`, `Usage`, `TODOs`)
- https://github.com/seblyng/roslyn.nvim/issues/266 — full closed issue
  thread (root-cause diagnosis, adapter's invention/announcement, closing
  comments)
- https://github.com/walcht/neovim-unity/issues/21 — "WSL2 Support for
  Windows" issue thread (adapter's development history, Unix-domain-socket
  attempt and failure, TCP fallback)
- https://learn.microsoft.com/en-us/windows/wsl/networking — Microsoft's
  current WSL2 networking docs (NAT vs. mirrored mode, `localhost` behavior,
  Windows 11 22H2+ requirement for mirrored mode)
- https://lazy.folke.io/spec — lazy.nvim official plugin spec docs (`cond`
  field definition)
- https://raw.githubusercontent.com/Crashdummyy/mason-registry/master/packages/roslyn/package.yaml
  — actual registry package definition (per-platform `asset`/`target` list)
- General web search (no substantive unique content beyond the above found):
  Reddit r/neovim search for real-world bridge usage reports (none found
  beyond intent-to-try comments already captured in the GitHub issue
  threads above); Stack Overflow / Reddit threads on Mason's "current
  platform is unsupported" error message, used only for general Mason
  platform-handling context, not `roslyn`-specific
