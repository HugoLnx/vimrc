# Unity live-debugging integration for Neovim (research)

Context: `plan.md`/`solutions.md` cover LSP (Roslyn on Windows, `csharp_ls` on
WSL) and Unity Editor open-at-line integration (`walcht/com.walcht.ide.neovim`,
Windows only), but not attaching a debugger to a running Unity Editor from
Neovim. This report covers `ownself/nvim-dap-unity` (the tool the user asked
about directly) plus the other live-debugging options found while researching
it. Since Unity Editor only runs on Windows/PowerShell in this repo's setup,
Windows is the relevant platform; other-OS behavior is noted for completeness
only.

---

## Background: how Unity debugging actually works

Unity's Editor exposes a **Mono soft-debugger** endpoint (the same mechanism
Visual Studio, Rider, and VS Code's Unity tooling all attach to) — historically
discovered via `<project>/Library/EditorInstance.json` and a predictable port
range. Every option below is ultimately a Debug Adapter Protocol (DAP) front
end that drives that same Mono soft-debugger connection; they differ in whose
debug-adapter binary does the DAP↔Mono-soft-debugger translation, and how that
binary is obtained/licensed.

---

## 1. `ownself/nvim-dap-unity` (the tool asked about)

**What it is.** A Neovim plugin (`mfussenegger/nvim-dap` dependency) that
automates *installing and wiring up* Microsoft's own debug-adapter binary from
**`vstuc`** ("Visual Studio Tools for Unity", Microsoft's official VS Code/VS
extension for Unity) — it downloads the `vstuc` package, extracts the debug
adapter into Neovim's data dir, and injects a `dap.adapters.unity` +
`dap.configurations.cs` "Attach to Unity" entry into `nvim-dap` automatically.

**Setup:**
- Neovim, `mfussenegger/nvim-dap`, `dotnet` on PATH.
- Windows: PowerShell (used to download/extract). Linux/macOS: `curl` +
  `unzip`. Author reports testing on Windows, macOS, and Linux (Arch).
- lazy.nvim spec:
  ```lua
  {
    "ownself/nvim-dap-unity",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("nvim-dap-unity").setup({})
    end,
  }
  ```
  Config knobs: `vstuc_version` (pin or `"latest"`), `install_dir`,
  `download_url` override, `auto_install_on_start`, `auto_setup_dap`,
  `add_default_cs_configuration` / `auto_add_cs_configuration_if_missing` /
  `enable_unity_cs_configuration` (control whether/how it appends the
  "Attach to Unity" DAP config alongside any existing C# DAP configs).

**IL2CPP:** not mentioned in the README — treat as unsupported/unverified
(Mono soft-debugger attach is inherently editor/Mono-player debugging, not
IL2CPP).

**Maintenance:** small (22 stars, 17 commits at last check) but the only
plugin that fully automates the `vstuc`-adapter path specifically for
Neovim.

**Known practical friction (from `mfussenegger/nvim-dap` Discussion #815,
"Can't get Unity Debugger to work"):**
- Older `path`-based approach (pointing at
  `<project>/Library/EditorInstance.json` to disambiguate which running Unity
  process to attach to) was the original workaround when multiple Unity
  Editor instances are running.
- After Unity/Microsoft deprecated the older VS Code "Unity Debugger"
  extension in favor of `vstuc`, users hit **`System.NullReferenceException`**
  errors from the `vstuc` adapter tied to exception-breakpoint requests —
  worked around by patching `nvim-dap`'s `session.lua` to send
  `filterOptions = {}` on exception-breakpoint requests (a client-side patch,
  not something `nvim-dap-unity` does for you automatically — confirm whether
  the plugin has since absorbed this fix before assuming attach "just works").
- A further refinement used `UnityAttachProbe.dll` to dynamically discover the
  correct debugger port/process instead of hardcoding it, needed specifically
  when more than one non-background Unity instance is running.
- **This is a live, evolving workaround thread, not a solved/packaged
  feature** — expect to need to debug the debugger setup itself, at least the
  first time, even with `nvim-dap-unity` doing the installation.

**⚠️ Licensing — unresolved, worth checking before adopting.** A web search
surfaced a claim that Microsoft's Visual Studio Tools for Unity license
restricts the extension to Microsoft Visual Studio products, which would make
using its debug adapter through Neovim (a third-party, non-Microsoft IDE) a
license violation. A direct fetch of Microsoft's own license-terms page for
this product (`visualstudio.microsoft.com/license-terms/mt170620/`), however,
found **no explicit clause limiting use to Visual Studio/Microsoft products**
in the text retrieved — general restrictions only (no reverse engineering, no
commercial hosting, no license transfer). **These two sources disagree and
neither was independently confirmed against the actual, current license
text in full** — this should be read directly and in full by the user before
depending on `vstuc` (via `nvim-dap-unity` or otherwise) for anything beyond
personal experimentation. Not treated as resolved either way in this report.

---

## 2. `walcht/unity-dap`

**What it is.** A from-scratch DAP server for Unity/Mono debugging, part of
the `walcht/neovim-unity` guide's toolset (alongside `com.walcht.ide.neovim`
and `LSP-TCP-socket-adapter`, already covered in `research/03-...` and
`research/04-...`). Explicitly built to avoid depending on Microsoft's
`vstuc`/VS Code tooling at all.

**Backend:** `Mono.Debugger.Soft` (from Mono's own `debugger-libs`) — talks
directly to Unity's Mono soft-debugger endpoint, same protocol every other
option ultimately uses, but with an independent (non-Microsoft) DAP front end.
GDB support is listed as a future TODO (not available today).

**IL2CPP:** explicitly and permanently **out of scope** — the author states
IL2CPP debugging "is not and will not be supported," citing complexity, the
closed-source nature of IL2CPP's generated C++, and a stated philosophical
objection to debugging generated C++ through a C# lens. If IL2CPP-build
debugging is ever needed (as opposed to Editor/Mono-player debugging), none
of the options in this report cover it.

**Setup:** clone with submodules, build via `dotnet` (9.0.108+ tested), on
Ubuntu 24.04 in the author's own testing; may require adding an outdated
NuGet package source. Executable permissions needed on Unix.
**Correction from a follow-up check:** the `walcht/neovim-unity` guide (and
the `unity-dap` GitHub Releases page) point to **prebuilt releases** for
`win-x64`, `linux-x64`, and `osx-x64` (latest at check time: `v0.1.0`,
Mar 24) — a from-source build is not actually required on Windows; download
the release archive, extract `unity-debug-adapter.exe`, done. (The releases
page's asset list itself failed to load in this pass, so the exact asset
filenames weren't independently confirmed — verify at install time.)

**Licensing:** MIT (per `walcht/neovim-unity`'s stated goal of keeping all
3rd-party tooling in its guide permissively licensed) — sidesteps the `vstuc`
licensing question entirely, at the cost of IL2CPP support and a rougher
Windows build story.

**Maintenance:** small (18 stars, 2 forks), same author/ecosystem as the
already-adopted `com.walcht.ide.neovim`.

---

## 3. Other tools surveyed (not viable / not applicable here)

- **`Insprill/unity-nvim-adapter`** — a Rust-based compatibility layer that
  makes Unity's built-in "Visual Studio Editor" external-tool integration
  launch Neovim instead of VS Code (open file / jump to log line), similar in
  *purpose* to `com.walcht.ide.neovim` (already chosen). It is **not** a
  debugger — no debug-adapter/DAP functionality is documented. 0 stars, 21
  commits. Not relevant to the debugging question; noted only because it
  surfaced during this search and could be confused for a debugging tool by
  name/topic proximity.
- **The old, deprecated VS Code "Unity Debugger" extension** (predecessor to
  `vstuc`, referenced in the `nvim-dap` Discussion #815 thread as the
  original `EditorInstance.json`-based workaround) — Microsoft has since
  deprecated/archived this in favor of `vstuc`. Not a live option for new
  setups; mentioned only as the origin of the `EditorInstance.json`
  disambiguation trick still relevant to `nvim-dap-unity`'s setup.

---

## Comparison

| | `ownself/nvim-dap-unity` (+ `vstuc`) | `walcht/unity-dap` |
|---|---|---|
| **Setup effort (Windows)** | Low — plugin downloads/installs `vstuc` automatically via PowerShell | Low-medium — prebuilt `win-x64` release exists (download + extract), but no Neovim plugin automates the fetch; manual `dap.adapters`/`dap.configurations` Lua required |
| **Backend licensing** | Microsoft `vstuc` — **use-with-non-Microsoft-IDE status unresolved**, see above | MIT, no ambiguity |
| **IL2CPP** | Unverified/likely unsupported | Explicitly, permanently unsupported |
| **Maturity of the DAP integration itself** | Actively discussed/patched in the `nvim-dap` community (exception-breakpoint bug, port-discovery workaround) — works, but expect rough edges | Newer, smaller community, less field-tested with `nvim-dap` specifically |
| **Maintenance** | 22 stars, 17 commits | 18 stars, 2 forks |

**No clear winner without a decision from the user.** `nvim-dap-unity` is far
less setup effort on Windows and is the tool actually asked about, but its
backend's licensing status for non-Microsoft-IDE use was not resolved by this
research (sources disagree) and its DAP integration has documented rough
edges (exception-breakpoint bug, multi-instance port discovery) that may need
manual patching. `walcht/unity-dap` has unambiguous MIT licensing and reuses
the same author/ecosystem as the already-chosen Unity Editor open-at-line
integration, but costs a from-source Windows build with no documented
prebuilt release, and is a smaller/less field-tested `nvim-dap` integration.
Neither should be adopted silently — this needs a user decision, not a
default pick, given the licensing question in particular. Not folded into
`plan.md`'s execution steps pending that decision.

---

## Sources

- https://github.com/ownself/nvim-dap-unity (README — setup, config options, requirements)
- https://github.com/walcht/unity-dap (README — Mono.Debugger.Soft backend, IL2CPP exclusion, build instructions)
- https://github.com/walcht/neovim-unity (guide repo tying `unity-dap` into a Neovim `nvim-dap` config)
- https://github.com/mfussenegger/nvim-dap/discussions/815 ("Can't get Unity Debugger to work" — EditorInstance.json workaround, vstuc exception-breakpoint bug, UnityAttachProbe.dll port discovery, filterOptions patch)
- https://visualstudio.microsoft.com/license-terms/mt170620/ (Visual Studio Tools for Unity license terms — fetched directly, no explicit non-Microsoft-IDE restriction found in the retrieved text)
- https://github.com/Insprill/unity-nvim-adapter (README — confirmed not a debugging tool, out of scope)
- General web search for "vstuc license neovim third party editor" (surfaced the licensing-restriction claim that the direct license-page fetch did not corroborate — flagged as unresolved, not confirmed either way)

### Notes on verification gaps

- The Visual Studio Tools for Unity license was fetched and summarized by an
  automated tool, not read in full by a human or cross-checked clause-by-
  clause against the licensing-restriction claim from search results — genuinely
  unresolved, recommend the user read the license directly before adopting
  `vstuc` via `nvim-dap-unity` for anything beyond throwaway local experiments.
- Whether `nvim-dap-unity`'s current release already includes the
  `filterOptions = {}` exception-breakpoint fix and `UnityAttachProbe.dll`
  port-discovery approach discussed in Discussion #815, or whether those are
  still manual patches a user would need to apply on top of the plugin, was
  not confirmed against the plugin's current source.
- `walcht/unity-dap`'s Windows support: the repo's own README build/test
  process is Ubuntu-only, but its GitHub Releases page and the
  `walcht/neovim-unity` guide both reference a prebuilt `win-x64` release
  asset — the releases page's asset list failed to load during this check,
  so the exact filename/download URL was not directly confirmed, only that
  a Windows release is advertised to exist.
