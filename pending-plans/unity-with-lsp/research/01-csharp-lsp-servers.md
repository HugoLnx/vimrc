# C# language servers for Neovim + Unity: roslyn.nvim vs csharp_ls vs OmniSharp

## Summary

There are effectively three live options for C# in Neovim today:

1. **`seblyng/roslyn.nvim`** — a thin Neovim wrapper around Microsoft's own
   Roslyn language server (`Microsoft.CodeAnalysis.LanguageServer`), the same
   engine that ships inside the VS Code C# extension / C# Dev Kit. This is
   the option with the most feature parity to "real" Visual Studio tooling
   (fast, in-sync project system, better analyzers), and it is the option
   the wider Neovim/C# community has converged on during 2025–2026 (per
   `programmingheadache.com`, per the pinned/closed OmniSharp issue #2663
   where a OmniSharp maintainer himself points people at roslyn.nvim).
2. **`csharp_ls`** (`razzmatazz/csharp-language-server`) — what this repo
   uses today. It is *also* Roslyn-based (it uses the Roslyn workspace APIs
   directly, just not Microsoft's own LSP host), is actively and currently
   maintained (commits as recent as 2 days before this research, per the
   repo's own commit history), but has a smaller feature surface than the
   Microsoft Roslyn LSP server, particularly around code actions/refactorings
   and semantic highlighting depth.
3. **OmniSharp** (`omnisharp-roslyn`) — the historical default. Microsoft's
   own team has told the OmniSharp maintainer that OmniSharp is no longer
   the default even inside VS Code, is a "community project with a very
   small community", and multiple people confirm it is being slowly wound
   down. Not recommended as a new choice today.

The strongest concrete finding for **this repo's specific situation**
(Unity via WSL + native Windows, same person switching between them) is
that **roslyn.nvim (or any Roslyn-LSP-based setup) run *inside WSL2* against
a Unity project whose `.csproj`/`.sln` files were generated on the Windows
side is a known-broken combination** — Unity embeds absolute Windows paths
(`C:\Program Files\Unity\...\UnityEngine.dll`) into the generated `.csproj`,
and the Roslyn LSP running under Linux/WSL2 cannot resolve those paths, so
you get partial IntelliSense (built-in .NET types work, `UnityEngine`/custom
types don't). This is documented in detail below and is very likely to bite
this repo's dual-environment (WSL + native Windows) usage pattern if Roslyn
is adopted uncritically. **csharp_ls has no evidence in public issue
trackers of hitting the same WSL/Windows-path failure mode** (though it also
hasn't been specifically stress-tested for Unity's cross-OS path issue by
the community the way roslyn.nvim has — there's just no assumption that its
users are all on native OS).

---

## 1. `seblyng/roslyn.nvim`

**What it is.** A Neovim plugin (Lua, ~920 GitHub stars, actively developed —
latest commit 3 weeks before this research, 491 commits) that is "an actively
maintained & upgraded fork" of an original `jmederosalvarado/roslyn.nvim`,
built to drive Microsoft's open-sourced Roslyn language server — "this
language server is currently used in the Visual Studio Code C# Extension,
which is shipped with the standard C# Dev Kit" (per roslyn.nvim README).
It is explicitly positioned as the modern replacement for OmniSharp.

It also recently absorbed Razor/`.cshtml` cohosting support (superseding the
formerly-separate `rzls.nvim`), which is irrelevant to Unity but shows active
scope growth.

**How the Roslyn server binary is obtained.** Three requirements per the
README:
- Neovim >= 0.12.0
- Roslyn language server downloaded locally
- .NET SDK installed and `dotnet` command available

The server itself is **not bundled** with the plugin — you must fetch the
`Microsoft.CodeAnalysis.LanguageServer` binary/DLL yourself, and .NET SDK
must be present to run it (Roslyn LSP ships as a `dotnet`-hosted DLL, or a
native single-file executable on Windows: `Microsoft.CodeAnalysis.LanguageServer.exe`).
Two install paths (per roslyn.nvim README):
- **Mason (recommended, with caveats)**: `MasonInstall roslyn-language-server`
  installs from nuget.org, but the author explicitly warns this "is not
  necessarily up to date with the same version used in vscode," and
  recommends adding a **custom Mason registry** for a fresher build:
  ```lua
  require("mason").setup({
      registries = {
          "github:mason-org/mason-registry",
          "github:Crashdummyy/mason-registry",
      },
  })
  ```
  That third-party registry (`Crashdummyy/mason-registry`) provides two
  packages: `roslyn` (same version as VS Code) and `roslyn-nightly`.
- **Manual (`dotnet tool install`)**: since `roslyn-language-server` v5.8.0-1.26262.10
  it supports Razor and can be installed as a .NET global tool from either
  nuget.org or Microsoft's own Azure DevOps feed (recommended by the README
  because it updates "multiple times a day" vs. nuget.org's slower cadence):
  ```
  dotnet tool install -g roslyn-language-server --prerelease --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json
  ```

**Mason(-lspconfig) integration status (at research time, 2026-09).** There
is **no official Mason registry entry for Roslyn** — it depends entirely on
the community-run `Crashdummyy/mason-registry`. Separately, `nvim-lspconfig`
itself has grown a built-in `roslyn` server definition (name `roslyn`),
which roslyn.nvim's own README calls out directly: *"`roslyn` is now a part
of nvim-lspconfig, but it does not implement all things that are implemented
here."* roslyn.nvim adds, on top of what lspconfig alone gives you:
- Support for multiple solutions in one workspace
- Broad `root_dir` detection (searching upward for `.sln` files when
  `broad_search` is enabled)
- Support for source-generated files
- A `:Roslyn target` command to switch between multiple detected solutions

So: **mason-lspconfig can enable `roslyn` automatically once installed**
(it's a normal server name it recognizes), but *getting a Roslyn binary
installed via Mason at all* still requires the non-official registry, and
you get materially more Unity-relevant capability (multi-solution handling)
by using `roslyn.nvim` on top rather than raw lspconfig.

**Neovim version requirement.** `>= 0.12.0` (this was a breaking bump — the
Makefile shows a `feat!: >=0.12` commit from earlier in 2026; older
roslyn.nvim versions supported 0.10+, so pin carefully if the dotfiles
target an older Neovim on either OS).

**lazy.nvim install snippet (from README):**
```lua
return {
    "seblyng/roslyn.nvim",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
        -- your configuration comes here; leave empty for default settings
    },
}
```

**Configuration for Unity's multi-project `.sln`/`.csproj` layout.**
roslyn.nvim's defaults are explicitly built around the "multiple solutions /
multiple projects" case that Unity produces (one `.sln` with many
per-asmdef `.csproj` files, e.g. `Assembly-CSharp.csproj`,
`Assembly-CSharp-Editor.csproj`, one per `.asmdef`, plus package/editor
projects):

```lua
opts = {
    -- "auto" | "roslyn" | "off" -- filewatching strategy
    filewatching = "auto",

    -- pick a target programmatically when multiple .sln/.csproj are found
    choose_target = function(target)
        return vim.iter(target):find(function(item)
            return string.match(item, "Foo.sln")
        end)
    end,

    -- exclude specific targets (e.g. an old .NET Framework solution)
    ignore_target = nil,

    -- search upward through parent directories for a solution, useful
    -- when the file you opened isn't a direct child of the sln's folder
    broad_search = false,

    -- lock onto the first-picked solution rather than re-detecting each attach
    lock_target = false,
}
```
Plus a runtime `:Roslyn target` command to switch the active solution and
`vim.g.roslyn_nvim_selected_solution` to read the current one (useful for a
statusline). Unity's projects are usually a *single* `.sln` with *many*
`.csproj`s underneath it (one solution, not multiple solutions), so the
"multiple solutions" handling matters less than you'd think for a single
Unity project — the more relevant Unity pain points are the ones covered in
the issues below (dependency resolution, WSL path translation), not
solution *selection*.

**Known Unity-specific issues (GitHub, `seblyng/roslyn.nvim`).**

- **Issue #266, "Only getting partial LSP support (Only standard C# classes)"**
  (opened Nov 20, 2025, pinned by the maintainer as a known/expected
  FAQ-level issue, unpinned May 2026 once presumably stabilized as
  "solved/known"). Multiple users hit the *same* symptom on Unity projects:
  Roslyn attaches, `List<T>`/built-in BCL types resolve fine, but
  `UnityEngine`/`MonoBehaviour`/user-defined types across files never
  resolve — LSP logs show
  `"...has unresolved dependencies"` for every generated `.csproj`
  (`Assembly-CSharp.csproj`, `Unity.InputSystem.csproj`, etc.). Root cause,
  worked out over the thread by user `walcht` (author of the separate
  `walcht/neovim-unity` project) and confirmed by the maintainer `seblyng`:
  **when Neovim + Roslyn LS run under WSL2 but the Unity `.csproj` files were
  generated by Unity running on the Windows host, the generated files embed
  Windows-native absolute paths** (e.g.
  `<HintPath>C:\Program Files\Unity\Hub\Editor\6000.0.40f1\Editor\Data\Managed\UnityEngine\UnityEngine.dll</HintPath>`)
  which a Linux-side Roslyn process cannot resolve (`/mnt/c/...` vs `C:\...`).
  `dotnet restore` sometimes "fixes" it *temporarily* for non-Unity WSL
  projects but does not fix the fundamental cross-OS path mismatch for
  Unity's own generated references.
  - The thread's accepted resolution (issue closed as completed, Dec 2025)
    is **not** to run the Roslyn LSP inside WSL2 at all when your Unity
    project files were generated by Windows-side Unity. Instead: **run
    `Microsoft.CodeAnalysis.LanguageServer` natively on Windows**, and have
    Neovim (running inside WSL2) talk to it over an **IP/TCP socket bridge**
    rather than stdio, because Windows-native LSP processes can't be reached
    from WSL2 via named pipes (WSL2 can't do Windows IPC pipes; only TCP or
    AF_UNIX-over-9P works). `walcht` built and published exactly this
    adapter: **`walcht/LSP-TCP-socket-adapter`**, documented in
    `walcht/neovim-unity`'s README section *"Setting Neovim in WSL with Unity
    Projects in Windows."* Reported result: "performance is similar to
    running everything natively."
  - A related data point from the same thread: even *without* WSL/Windows
    path issues, one contributor (`walcht`) separately found that adding the
    official `Microsoft.Unity.Analyzers` Roslyn analyzer (specifically
    v1.25.0, and later reportedly also v1.19.0) caused severe LSP slowdowns
    (startup going from <3s to multiple minutes) and "silently screwed up"
    completion for random Unity modules — an analyzer-related regression
    independent of roslyn.nvim itself, but relevant if this dotfiles repo
    plans to wire up that analyzer for Unity-specific lint rules.
  - Separately, a second contributor (`21Beagle`, on native Windows, no WSL)
    reported the *same* "partial LSP, only works right after `dotnet
    restore`, then silently degrades" behavior on a plain WinForms project —
    so at least one flavor of "unresolved dependencies" is **not**
    Unity- or WSL-specific, but a more general Roslyn-LSP project-loading
    flakiness that intermittently needs a manual restore to recover.
- **Issue #217, "Roslyn doesn't work in newly-added files until I restart nvim."**
  Consistent with Unity's workflow of frequently adding new `.cs` files —
  Roslyn's incremental project model can lag behind newly created files
  until a restart, an ergonomic wrinkle for iterative MonoBehaviour
  authoring. (Found via search; not fully read for this report — flagged
  as unverified beyond the title/topic.)
- **Issue #324, "Whole solution analysis is slow."** Directly relevant to
  Unity, where a `.sln` legitimately contains dozens of generated
  `.csproj`s (one per asmdef/package); full-solution background analysis
  scope is expensive. (Title-level only; not read in full — the mitigation
  is presumably the `csharp|background_analysis` settings below, defaulting
  scope to `openFiles` rather than `fullSolution`.)

**Relevant runtime configuration knobs** (all set via `vim.lsp.config("roslyn", {...})`,
not roslyn.nvim's own `opts`, since these are settings sent to the Roslyn
server itself):
```lua
vim.lsp.config("roslyn", {
    on_attach = function() end,
    settings = {
        ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles", -- vs fullSolution/none
            dotnet_compiler_diagnostics_scope = "openFiles",
        },
        ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true,
            dotnet_enable_tests_code_lens = true,
        },
        ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
        },
    },
})
```
`fullSolution` scope for diagnostics is explicitly flagged by Microsoft's
own vscode-csharp issue tracker (linked from the vscode-csharp
configuration test roslyn.nvim's README points to) as causing "significant
performance degradation" — worth keeping at `openFiles` for a Unity-sized
solution.

**Razor/Debugging note (not Unity-relevant but worth flagging):** roslyn.nvim
recently absorbed Razor cohosting support, superseding `rzls.nvim` — a
no-op for pure Unity C# work.

---

## 2. Staying on `csharp_ls`

**Current status in this repo.** `nvim/lua/user/unity.lua` wires up
`csharp_ls` manually (`vim.lsp.config('csharp_ls', {...}); vim.lsp.enable('csharp_ls')`),
installed via Mason, deliberately excluded from mason-lspconfig's automatic
enable list per the task background.

**Maintenance status: actively maintained, not stagnant.** Checked the
`razzmatazz/csharp-language-server` GitHub repo directly (per repo commit
history): 1,346 commits, 984 stars, 87 branches/46 tags, and — notably —
**commits as recent as 2 days before this research** (`chore: update
CHANGELOG.md`, Aug 31, 2026), with substantive perf work in the same window
(`perf(diagnostics): bound analyzer concurrency to fix completion stalls`,
`perf(diagnostics): re-enable concurrentAnalysis after validating fix`). The
project has also adopted AI-assisted development (README explicitly credits
Claude models per-commit under a Linux-kernel-style `Assisted-by:`
convention), which at minimum indicates ongoing maintainer investment. **This
contradicts any assumption that csharp_ls is abandoned or slow-moving** —
if anything its cadence looked comparable to roslyn.nvim's in this snapshot.

**What csharp_ls actually is, architecturally.** It is *also* Roslyn-based —
"csharp-ls uses Roslyn to parse and update code" (per its README) — it is
not a from-scratch reimplementation. The distinction from `roslyn.nvim`'s
target is that csharp_ls is an independent, from-scratch LSP host written in
F# (via the Ionide.LanguageServerProtocol library) around Roslyn's public
workspace/compiler APIs, whereas roslyn.nvim drives Microsoft's own
purpose-built LSP host (`Microsoft.CodeAnalysis.LanguageServer`) that ships
inside VS Code/C# Dev Kit and gets first-party engineering investment from
the Roslyn team itself (per the OmniSharp maintainer's comparison in
omnisharp-roslyn#2663, see OmniSharp section below — that comparison was
OmniSharp-vs-MS-Roslyn-LSP specifically, but the "the MS Roslyn LSP project
system is faster and better at staying in sync with changes from outside
the editor" advantage generalizes to any non-Microsoft Roslyn-LSP
implementation, csharp_ls included, since it's the same fundamental
project-system architecture gap).

**Known feature gaps vs. the Microsoft Roslyn LSP (roslyn.nvim's backend).**
Could not find a maintained, explicit "feature comparison table" document
from either project (this should be treated as **unverified/best-effort**,
not a confirmed fact list) — but the following gaps are corroborated by
csharp_ls's own README/docs and by community reports surfaced in search:
- **No built-in decompilation/source-generated-file browsing without an
  extra client plugin.** csharp_ls exposes this via a *custom, non-standard*
  `csharp/metadata` LSP request (needs `csharp.useMetadataUris = true` or
  `--features metadata-uris`), and explicitly needs a separate Neovim plugin
  (`Decodetalkers/csharpls-extended-lsp.nvim`) to make "go to definition"
  into BCL/decompiled code actually open a buffer — this does not "just
  work" the way it does with the Roslyn LSP + roslyn.nvim combination.
- **Analyzers are opt-in and cost latency.** `csharp.analyzersEnabled`
  defaults to `false` — "run Roslyn analyzers... increases diagnostic
  latency and CPU usage." Turning it on is required to get IDE-style
  analyzer diagnostics at all (e.g. for Microsoft.Unity.Analyzers-style
  Unity linting), and the README frames it as a deliberate cost trade-off,
  not something tuned to "just work" like VS Code's C# Dev Kit.
  Roslyn LSP's `csharp|background_analysis` setting was clearly modeled to
  give more granular control (`openFiles`/`fullSolution`/`none`) — csharp_ls
  is coarser (on/off).
  - Note: it's not clear from this research whether the current dotfiles
    setup has `analyzersEnabled` on; if it's off today, some of the
    "csharp_ls is comparatively lightweight" impression in the task
    background may simply be this default rather than an inherent
    limitation — worth checking before concluding a switch is needed purely
    for that.
- **Formatting defers to `.editorconfig` by default** (`csharp.applyFormattingOptions`
  defaults to `false`), which is generally desirable but different in
  default posture from editors that push their own formatting options.
- **No first-party multi-solution target switching** equivalent to
  roslyn.nvim's `:Roslyn target` — csharp_ls picks up `--solution`/
  `csharp.solutionPathOverride` for a *fixed* override, not a runtime
  picker; for a single-Unity-project workflow this is a non-issue (only one
  `.sln` exists) but is a UX regression versus roslyn.nvim if this repo ever
  edits multiple side-by-side Unity/.NET repos from the same Neovim config.
- Historical community friction points (via search, unverified against
  current version): older Stack Overflow / GitHub issues (e.g. neovim/neovim#18147,
  a Reddit thread "csharp-ls not showing documentation") describe
  completion/hover regressions, and a Stack Overflow thread describes
  `root_markers`-based root detection not supporting globs, requiring a
  custom `root_dir` function — none of these were re-verified against the
  current csharp_ls release, and given the "2 days ago" commit cadence
  found above, some may already be fixed.

**No Razor/`.cshtml` support** is available via a `csharp.razorSupport` flag,
but this is not relevant to Unity.

**Bottom line for csharp_ls vs. roslyn.nvim, given what was verifiable:**
csharp_ls is not unmaintained, and is also Roslyn-backed rather than some
weaker legacy engine — but it deliberately keeps a smaller, opt-in feature
surface (analyzers off by default, no built-in multi-target switching, needs
an extra plugin for decompiled-source navigation) compared to what
roslyn.nvim gets "for free" by fronting Microsoft's own first-party Roslyn
LSP host. Whether that gap matters for Unity work specifically comes down to
whether this repo wants analyzer-driven diagnostics/refactorings inside
Neovim — if mostly go-to-def/completion/hover is needed, the practical delta
may be smaller than the "comparatively lightweight" framing suggests.

---

## 3. OmniSharp (Roslyn-based)

**Current maintenance state: in managed decline, not recommended for new
setups.** Directly from `OmniSharp/omnisharp-roslyn` issue #2663 ("Question
about state and future of omnisharp," opened Mar 2025, closed the next day):
maintainer `JoeRobich` (a Microsoft/Roslyn-affiliated contributor) states
plainly:
> "OmniSharp is a community project with a very small community. It will
> make progress slowly. Contributions are welcome."

and confirms that VS Code dropped OmniSharp as its default years ago in
favor of the Microsoft Roslyn LSP, and when asked directly "are there any
plans to make [the Roslyn LSP] vscode independent to be able to be used in
neovim," he points the asker straight at **`seblyng/roslyn.nvim`** — i.e.
Microsoft's own OmniSharp maintainer is recommending roslyn.nvim as the
neovim path forward, not further OmniSharp investment. The `walcht/neovim-unity`
guide is blunter still: *"you might have heard of Omnisharp as another C#
LSP, **avoid using it** as it is being(?) discontinued and has major memory
leakage issues."*

**Architecture, for comparison.** Per the same maintainer's explanation in
that issue: OmniSharp's LSP mode
(`OmniSharp.LanguageServerProtocol`) wraps OmniSharp's own O# protocol
handlers around Roslyn — i.e. it is *also* Roslyn-based, just via an older,
independent LSP framework (`OmniSharp/csharp-language-server-protocol`)
rather than Microsoft's newer `Microsoft.CommonLanguageServerProtocol.Framework`
that the modern Roslyn LSP is built on. Per that maintainer's own
pros/cons list:
- **OmniSharp pros**: supports "load project on demand" (defers loading
  projects until their files are opened — useful for very large solutions);
  supports loading C# script (`dotnet-script`) and Cake build files, which
  neither Roslyn LSP nor csharp_ls do.
- **Roslyn LSP pros**: "project system is faster and better at staying in
  sync with changes from outside the editor," "analyzer runner is faster,"
  and — critically — "there are developer resources dedicated to fixing
  bugs and improving the experience" (i.e. it gets first-party Microsoft
  engineering time; OmniSharp does not).

**Neovim integration path.** `nvim-lspconfig`'s built-in `omnisharp.lua`
config (confirmed by reading the file directly from the `nvim-lspconfig`
repo) requires the `omnisharp-roslyn` release binary downloaded/extracted
manually (or built from source) plus the .NET SDK, and explicitly notes:
> "For `go_to_definition` to work fully, extended `textDocument/definition`
> handler is needed" via a separate plugin,
> **`Hoffs/omnisharp-extended-lsp.nvim`** — the same "needs an extra client
> plugin for decompiled/external navigation" pattern seen with csharp_ls,
> but for OmniSharp instead.

Root detection in lspconfig's OmniSharp config looks for `.slnx`/`.sln`/
`.csproj`/`omnisharp.json`/`function.json`, so Unity's generated solution
layout is nominally supported the same way as the other servers, but given
the community consensus above (both this repo's requirements and the wider
ecosystem), **OmniSharp is not a serious contender for a new/updated
setup** — it is covered here only for completeness and because the task
asked for it.

---

## Platform parity (WSL-Linux vs native Windows/PowerShell)

This is the most consequential finding for this specific repo, since it is
deployed identically to both environments by the same person.

### roslyn.nvim / Roslyn LSP

- **Dependencies on both OSes**: .NET SDK (`dotnet` on PATH) + a
  `Microsoft.CodeAnalysis.LanguageServer` build for the matching OS/arch
  (separate NuGet feeds exist per-OS:
  `Microsoft.CodeAnalysis.LanguageServer.win-x64`,
  `.linux-x64`, `.osx-x64`, per `walcht/neovim-unity`'s README) — **you
  cannot share one downloaded server binary across WSL and Windows**; each
  side needs its own OS-matched build. Neovim itself must also be
  `>= 0.12.0` on both sides.
- **The critical failure mode (confirmed via `seblyng/roslyn.nvim` issue
  #266, closed Dec 2025)**: if Unity (running on the Windows host, as it
  must, since Unity Editor doesn't run under WSL) generates the `.sln`/
  `.csproj` files, those files embed **Windows-native absolute paths** to
  engine DLLs (`C:\Program Files\Unity\...`). A Roslyn LSP process running
  *inside WSL2* cannot resolve those paths (needs `/mnt/c/...`), so
  IntelliSense partially breaks: built-in .NET/BCL types resolve, but
  `UnityEngine`/`UnityEditor`/user Unity types do not. This is **not** a
  roslyn.nvim bug per se — it reproduces with plain `nvim-lspconfig`
  wiring too, per the thread — it's an inherent consequence of running a
  Linux-side compiler/LSP against Windows-side generated project files
  without a path-translation layer. Regenerating the `.csproj` files
  *from* WSL doesn't help either, because then Unity (on Windows) can't
  read the resulting Unix-style paths back.
- **The only reasonable fix identified in the community** (per the same
  issue thread, and documented in `walcht/neovim-unity`'s README section
  "Setting Neovim in WSL with Unity Projects in Windows"): **do not run the
  Roslyn LSP under WSL2 at all for a Unity project.** Instead, run
  `Microsoft.CodeAnalysis.LanguageServer` **natively on Windows** and bridge
  Neovim-in-WSL2 to it over a **TCP/IP socket** using a small adapter
  (`walcht/LSP-TCP-socket-adapter`) that pipes the Windows-native LS's
  stdio to a socket WSL2 can reach — because WSL2 cannot reach a Windows
  process via native Windows named pipes, only via TCP or the AF_UNIX/9P
  interop path. Reported performance after doing this: "similar to running
  everything natively."
- **Practical implication for this repo**: if this repo's Unity work is
  edited from WSL at all (task background implies dual-boot-style usage,
  Unity itself Windows-only), a naive "just run roslyn.nvim the same way on
  both sides" config will silently produce degraded IntelliSense on the WSL
  side specifically for Unity projects (non-Unity/plain .NET projects on
  WSL are unaffected per the same thread — plain `dotnet new console`
  projects created and opened from WSL worked fine; it's specifically
  Unity's Windows-path-laden generated project files that break). Achieving
  identical behavior on both sides is possible but requires **extra
  infrastructure** (the socket adapter) rather than being free — it is not
  "drop in roslyn.nvim on both machines and done."
- Separately, WSL2 is confirmed (by a contributor in the same thread) to be
  slower than WSL1 for this kind of workload because WSL2 uses a real Linux
  kernel translating through 9P/virtio rather than direct NT syscall
  translation — a general WSL2-vs-native performance tax independent of the
  Unity path bug.
- **Native Windows-only** deployment (Unity + Neovim + Roslyn LSP all on
  Windows, PowerShell) avoids all of the above — this is the "just works"
  path per the compatibility table in `walcht/neovim-unity`'s README
  ("Unity 6000.3 LTS / Windows 10: OK", etc.), and per the original
  `codevogel` report in issue #266 (opening a WSL-created console app from
  Windows-side directories, or a Windows-created one, both worked once
  purely single-OS).

### csharp_ls

- **Dependencies on both OSes**: .NET 10 SDK or later (per its README —
  note this is a *higher* SDK floor than what was historically true;
  confirm this doesn't conflict with whatever SDK version this repo already
  pins), installed as a `dotnet tool install --global csharp-ls` — this
  mechanism is **OS-agnostic** in the sense that `dotnet tool install`
  produces a small native shim per-platform automatically; the same install
  *command* works on both WSL-Ubuntu and Windows PowerShell, each producing
  its own OS-appropriate binary under `~/.dotnet/tools` (Linux) or
  `%USERPROFILE%\.dotnet\tools` (Windows). No manual OS/arch NuGet feed
  picking is needed the way it is for the standalone Roslyn LSP binary.
- **No public reports found (in the sources reviewed) of csharp_ls hitting
  the same WSL-vs-Windows-path failure mode that roslyn.nvim's Unity users
  hit.** This is not strong evidence it's immune — csharp_ls also resolves
  `HintPath`/project references through the same underlying MSBuild/Roslyn
  workspace loading machinery, which is exactly the layer where the Windows-
  path problem originates, so the same class of failure (Windows absolute
  paths inside `.csproj` unreadable from a Linux-hosted process) would
  plausibly reproduce with csharp_ls too if run inside WSL2 against
  Windows-generated Unity project files. Absence of reports likely just
  reflects a much smaller "csharp_ls + Unity + WSL2" user overlap in public
  issue trackers, not a verified fix — **do not treat this as confirmed
  parity**; if switching away from Roslyn-in-WSL, csharp_ls-in-WSL should be
  spot-checked against a real Unity project before trusting it, or simply
  run csharp_ls only on the native Windows side for Unity work as a
  precaution, same as the roslyn.nvim recommendation.
- Because it's an independent host rather than a Microsoft-shipped binary
  bound to per-OS NuGet feeds, there is no equivalent of "have to hunt down
  a `.win-x64` vs `.linux-x64` NuGet feed" step — one `dotnet tool install`
  invocation per machine suffices, which is simpler operationally on both
  sides.

### OmniSharp

- Needs the .NET SDK plus a manually downloaded/extracted `omnisharp-roslyn`
  release per OS (or a source build) — same "separate per-OS artifact"
  shape as the Roslyn LSP. Given the community consensus that OmniSharp is
  being phased out, no further platform-parity investigation was done here
  beyond noting the same class of manual-binary-per-OS friction applies.
- Nothing was found in the sources reviewed that specifically addresses
  OmniSharp's behavior against WSL2 + Windows-generated Unity project files
  — presumably subject to the same MSBuild/HintPath-resolution risk as the
  other two, but unverified.

### General cross-cutting note

Every option above needs the Unity Editor's **"Generate .csproj files
for..."** external-tools setting enabled and regenerated whenever
asmdefs/packages change (this repo's `nvim/lua/user/unity.lua` already
documents this for csharp_ls; it applies identically to roslyn.nvim/OmniSharp
since it's a Unity-side project-file-generation step, not an LSP-side one).
Since Unity itself only runs on the Windows side of this dual-boot setup,
the generated `.csproj`/`.sln` will *always* be Windows-path-flavored
regardless of which LSP is chosen — the WSL-side risk described above is
inherent to editing Unity C# from WSL at all, not specific to picking
roslyn.nvim vs csharp_ls. The practical exit routes if WSL-side Unity
editing is wanted are: (a) run the C# LSP natively on Windows and bridge to
WSL over TCP (roslyn.nvim's community solution, adaptable in principle to
csharp_ls since `dotnet tool`-based servers can also be pointed at over a
socket with similar plumbing, though no one has published a ready-made
adapter for csharp_ls specifically), or (b) just edit Unity projects from
native Windows Neovim and reserve WSL for non-Unity/.NET work, sidestepping
the issue entirely.

---

## Sources

- https://github.com/seblyng/roslyn.nvim (README — requirements, installation, Mason registry, configuration, `Difference to nvim-lspconfig` section)
- https://github.com/seblyng/roslyn.nvim/issues/266 ("Only getting partial LSP support (Only standard C# classes)" — WSL2/Windows-path root cause, TCP socket adapter fix, Microsoft.Unity.Analyzers slowdown note)
- https://github.com/razzmatazz/csharp-language-server (repo file listing/commit history — maintenance cadence, AI-assistance note, .NET 10 SDK requirement, `dotnet tool install --global csharp-ls`)
- https://github.com/razzmatazz/csharp-language-server/blob/main/docs/features.md (decompiled/source-generated URI feature, `csharpls-extended-lsp.nvim` client dependency)
- https://github.com/razzmatazz/csharp-language-server (README settings section — `csharp.analyzersEnabled` default false, `csharp.applyFormattingOptions` default false, `csharp.solutionPathOverride`)
- https://github.com/OmniSharp/omnisharp-roslyn/issues/2663 ("Question about state and future of omnisharp" — maintainer confirms small community, points to roslyn.nvim, OmniSharp-vs-Roslyn-LSP pros/cons)
- https://raw.githubusercontent.com/neovim/nvim-lspconfig/master/lsp/omnisharp.lua (nvim-lspconfig's built-in OmniSharp config — manual binary install, `omnisharp-extended-lsp.nvim` dependency for go-to-definition)
- https://github.com/walcht/neovim-unity (README — cross-OS Roslyn LSP NuGet feeds per-arch, WSL2+Windows-Unity bridging guide, "avoid OmniSharp" recommendation, Unity/OS compatibility matrix, full Roslyn LSP Neovim config example)
- https://programmingheadache.com/2025/10/17/you-ve-been-using-wrong-lsp/ ("You've Been Using the WRONG LSP for C# in Neovim" — community framing of roslyn.nvim as the modern default, step-by-step Mason+roslyn.nvim setup)
- https://spaceandtim.es/code/nvim_unity_setup/ (older OmniSharp+Unity-on-Linux setup guide — kept for historical OmniSharp/Unity context, not for current recommendations)
- Firecrawl web search results surveyed but not deep-read (titles/descriptions only, flagged where used as unverified): Reddit r/neovim "Unity Development using Lazyvim, Mason, & Roslyn LSP", Stack Overflow "How to get csharp-ls language server in neovim to find the root of my project", neovim/neovim#18147, Reddit r/neovim "csharp-ls not showing documentation".

### Notes on verification gaps

- roslyn.nvim issues #217 (new-file detection lag) and #324 (whole-solution
  analysis slowness) were found via search by title only and not read in
  full — flagged inline above as title-level-only findings.
- Whether this repo's current csharp_ls config has `analyzersEnabled` on
  or off was not checked against `nvim/lua/user/plugins/lsp.lua` in this
  research pass — worth confirming before attributing perceived
  "lightweight" behavior to an inherent csharp_ls limitation rather than a
  default-off setting.
- Whether csharp_ls specifically reproduces the WSL2/Windows-Unity-path bug
  documented for roslyn.nvim was **not tested** and no public report was
  found either way — treat as an open risk, not a cleared one.
