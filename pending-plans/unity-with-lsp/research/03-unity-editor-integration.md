# Unity Editor Integration Options for Neovim (research)

Context: `nvim/lua/user/unity.lua` in this repo currently only wires up the
`csharp_ls` LSP server for Unity-generated `.csproj` files. There is an open
TODO to wire up "double-click-to-open-at-line from the Unity Editor into a
running Neovim instance" via `nvim --server` / `--remote`. Since Unity Editor
only runs on Windows/PowerShell in this setup, only the Windows side of any
integration needs to work; WSL/Linux behavior of these tools is documented
below for completeness but is not a hard requirement.

This report covers three specific GitHub projects: `apyra/nvim-unity`,
`apyra/nvim-unity-sync`, and `walcht/neovim-unity` (plus its companion Unity
package `walcht/com.walcht.ide.neovim`, which turned out to be where the
actual "open at line" implementation lives).

---

## 1. `apyra/nvim-unity`

**What it is.** A **Unity-as-External-Script-Editor integration**, distributed
as a Unity package (`Editor/`, `Runtime/` folders, `package.json` — installed
via Package Manager "Install from Git URL") paired with a small, optional
Neovim-Lua-side convention. Per its own README: "This Unity package integrates
Neovim as an external script editor and provides a **Regenerate Project
Files** button inside the Unity Editor." [github.com/apyra/nvim-unity]

**Features claimed:**
- Auto-opens `.cs` files in Neovim when clicked in the Unity Editor.
- Opens all files from the same Unity project in the **same terminal and
  buffer** (i.e., a single shared Neovim instance per project, not one per
  file).
- A "Regenerate Project Files" button (also reachable via
  `Tools > Neovim Code Editor > Regenerate Project Files`) that (re)generates
  `.csproj`/`.sln`.
- Explicitly touts **"Zero dependency on `nvr` (Neovim Remote)"** — i.e., it
  does not shell out to the `neovim-remote` Python tool; it appears to
  implement its own launcher/IPC (the repo ships platform-specific
  installers rather than exposing the mechanism in the README).

**Does it solve "double-click a script/error → jump to that line in a running
Neovim instance"?** The README documents opening files on click, but does
**not** document line-number/cursor-position jumping (e.g. for double-clicking
a compiler error in the Console to land on the exact line). Nothing in the
README mentions `--remote-send`/cursor-jump args the way `com.walcht.ide.neovim`
does. This should be treated as **unverified/likely-missing** rather than
confirmed present — the source under `Editor/` was not inspected in detail
(only the README/file listing were fetched), so it is possible finer-grained
jump-to-line behavior exists in code without being documented. Flagging this
explicitly since I could not confirm it either way from the docs.

**Installation / platform support:**
- **Not a lazy.nvim/Neovim plugin manager package** in the traditional sense —
  it's installed as a **Unity package** (`https://github.com/apyra/nvim-unity.git`
  via Package Manager), "for every project you want to use it with." There is
  a companion Lua snippet you drop into your Neovim config, but the repo
  itself isn't structured as an `opts`/`setup()`-style Neovim plugin (contrast
  with `nvim-unity-sync` below, which is).
- Ships **prebuilt cross-platform launcher binaries/installers**:
  - Windows: `nvimunity-setup.exe` installer (via GitHub Releases).
  - Linux: `nvimunity-linux.AppImage`, or a shell-script fallback
    (`nvimunity.sh`) "since the AppImage doesn't seem to work for many
    people," plus a sample Nix derivation for NixOS users.
  - macOS: `NvimUnity.dmg` (marked "Test and feedbacks required," i.e.
    not fully vetted).
- So it is explicitly **cross-platform by design**, not Windows-only, though
  Linux/macOS support is self-described as less mature ("✅ Test and feedbacks
  required!" on both).

**Maintenance status.** Actively maintained as of this research (Sept 2026):
- 240 commits on `master`, latest commit "Removed error on project generate
  sln" dated **Apr 1, 2026** (~6 months before this research date).
- 124 GitHub stars, 23 forks, 9 contributors, listed on `awesome-neovim`.
- Only 1 tagged release (`v1.0.0`, Apr 2025) despite many subsequent commits —
  i.e., it ships mostly off `master`/rolling installers rather than frequent
  tagged releases, and `package.json` was bumped to `1.3.3` post-tag (visible
  in commit history), suggesting the Releases page is stale relative to
  `master`.

**Caveat from real-world usage:** In a Nov 2025 Unity Discussions thread, a
user reported that `apyra/nvim-unity` "seems to throw a bunch of errors upon
importing it, and relies on nvchad rather than a custom nvim configuration"
[discussions.unity.com/t/unity-neovim-and-wsl/1696326]. The README's
"Recommended Configuration" section does indeed lean on NvChad conventions
(though it presents Neovim/Lazy/Mason/Telescope as prerequisites generically,
not as a hard NvChad-only dependency). Treat "works with any Neovim config"
as **unverified** — the one field report found says otherwise.

---

## 2. `apyra/nvim-unity-sync`

**What it is.** A **companion Neovim-side plugin** (proper Lazy.nvim spec,
`require("unity.plugin").setup()`), separate from the Unity-side package
above. Per its README: "a lightweight Neovim plugin designed to enhance Unity
development inside Neovim. It automatically manages `.csproj` files based on
file events, helping you avoid the need to manually regenerate project files
in Unity." [github.com/apyra/nvim-unity-sync]

**"Sync" here means csproj sync, not asset sync or running-instance
discovery:**
- Automatically adds/removes `<Compile>` tags in `.csproj` files when `.cs`
  files are created, deleted, or renamed **from within Neovim** (hooking into
  `nvim-tree` events and LSP rename/move-to-file actions).
- Ships user commands: `:Ustatus` (project status info), `:Usync` (force sync
  all `.cs` files under `Assets`), `:Uopen` (launch the Unity Editor for the
  current project, if `unity_path` is configured).
- Explicit purpose stated in `nvim-unity`'s own README: keeps `.csproj`
  updated "even if Unity is closed" — this addresses the specific pain point
  that Roslyn/OmniSharp LSP only "sees" newly created files after Unity
  itself recompiles and regenerates project files, which normally requires
  focusing the Unity window.

**Relationship to `nvim-unity`.** They are explicitly designed to be used
together but are **not the same thing and not forks of each other** — one is
a Unity Editor package (external-script-editor + regenerate-solution), the
other is a pure-Lua Neovim plugin (keeps `.csproj` current without Unity
running). `nvim-unity`'s README links to `nvim-unity-sync` under a "🔁 File
Sync" section, and `nvim-unity-sync`'s README links back describing
`nvim-unity` as the optional "Unity Editor Integration" half. Both are
maintained by the same author/org (`apyra`).

**Setup requirements on the Unity project side:** **None** — `nvim-unity-sync`
is a pure Neovim (Lua) plugin with a required dependency on
`nvim-tree/nvim-tree.lua`; it does not require installing anything via
Unity's Package Manager. (Installing `apyra/nvim-unity` on the Unity side is
optional/complementary, not required, for `nvim-unity-sync` to function.)

**Windows-only vs. cross-platform.** Cross-platform — it's pure Lua operating
on the filesystem (`.csproj` XML) and editor events; no OS-specific code is
described. The optional `unity_path` config for `:Uopen` would need adjusting
per-OS (e.g., pointing at `Unity.exe` on Windows).

**Maintenance status.** Much smaller and slower-moving than `nvim-unity`:
22 commits total, last commit **Oct 29, 2025** ("Add MIT License to the
project"), 20 stars, 9 forks, 2 watchers. No tagged releases. README says
explicitly: "This plugin is still under early development." Compared to
`nvim-unity`'s Apr 2026 last-commit date, `nvim-unity-sync` appears to have
gone quieter (~11 months stale as of Sept 2026 vs. `nvim-unity`'s ~6 months).

---

## 3. `walcht/neovim-unity` (+ `walcht/com.walcht.ide.neovim`)

**What `walcht/neovim-unity` is.** Not a plugin itself — it is a **guide
repository** (a single detailed README) plus pointers to a constellation of
small companion projects by the same author. Its own description: "a
single README file that provides instructions on how to setup Neovim for
Unity game engine development tasks on both Windows 10/11 and Linux."
Explicitly **not affiliated with Unity Technologies**. It documents, and
depends on, three separate companion repos:
- **`walcht/com.walcht.ide.neovim`** — the actual Unity-side External Script
  Editor package (this is the piece that answers the "double-click to open
  at line" question — see below).
- **`walcht/LSP-TCP-socket-adapter`** — a small relay used only for the
  WSL2-Neovim ↔ Windows-Roslyn-LS scenario (bridges Roslyn's stdio-only LSP
  transport to a TCP socket reachable from WSL2).
- **`walcht/unity-dap`** — a Debug Adapter Protocol (DAP) server for
  debugging Unity/Mono from Neovim (via `nvim-dap`).

**Does it solve the open-at-line TODO? Yes — via the companion Unity package,
`com.walcht.ide.neovim`.** This is the most directly relevant find for this
repo's `unity.lua` TODO. Per that package's README
[github.com/walcht/com.walcht.ide.neovim/blob/master/README.md]:

- Feature list explicitly includes "Opening of a new-tab in the currently
  running Neovim server instance" and "**Jumping to cursor position on the
  requested file in the currently running Neovim server instance**," plus
  auto-focusing the Neovim window (full support on Windows; GNOME-only
  workaround on Linux via the `activate-window-by-title` extension).
- It does this **exactly** the way this repo's TODO anticipates: by shelling
  out to `nvim --server <socket> --remote-tab <file>` for opening files, and
  `nvim --server <socket> --remote-send ":call cursor({line},{column})<CR>"`
  for jumping to a location. Both command templates are **user-configurable**
  in `Neovim -> Settings` inside the Unity Editor, with placeholders `{app}`,
  `{filePath}`, `{serverSocket}`, `{line}`, `{column}`.
- **Server socket details (Windows-specific):** on Windows the default
  `{serverSocket}` placeholder resolves to `127.0.0.1:<RANDOM-PORT>` (a
  randomly chosen available TCP port each session) rather than a Unix domain
  socket path (which is the Linux default, `/tmp/nvimsocket`). Because it's a
  loopback TCP port picked per-session, there is **no fixed port to open in
  a firewall** and no registry changes documented — Windows Defender Firewall
  normally does not prompt for loopback-only connections, and the README does
  not mention any firewall exception being required.
- Persistence: the Unity-side config (which running Neovim server instance to
  target) is stored via `EditorPrefs.SetString("NvimUnityConfigJson", ...)`,
  so the same Neovim server instance keeps being targeted across Unity Editor
  restarts for a given project, as long as that Neovim server process is
  still alive.
- Terminal launch is also configurable per-OS; on Windows, "no additional
  dependencies are needed to switch focus to Neovim window" — window
  focusing is implemented via Win32 API against the launched process handle,
  with a documented PowerShell-based PPID relay for terminals like Windows
  Terminal (`wt`) that spawn a detached child process. Recommended setup is
  **Windows Terminal (`wt`) with PowerShell as the default shell** — directly
  relevant since this repo's target Windows shell is PowerShell.

**Installation:** Unity-side, via Package Manager → "Install package from git
URL" → `https://github.com/walcht/com.walcht.ide.neovim.git`, then restart
Unity so "Neovim v<version>" appears under `External Tools`. On the Neovim
side, `walcht/neovim-unity`'s README is a step-by-step config guide (not a
`require("plugin").setup()` package) — you paste Lua snippets into your own
config, or optionally adopt the author's full prebuilt config, **CGNvim**.
There is **no lazy.nvim plugin spec** to install for the core open-at-line
feature; that logic lives entirely in the Unity-side C# package, driven by
its own `Settings` UI, not by anything installed into `~/.config/nvim`.

**Windows-only vs. cross-platform:** `com.walcht.ide.neovim` explicitly
targets "Cross-platform support (Linux and Windows 10/11 - MacOS is TODO)" as
a listed feature, and its compatibility matrix reports "OK" across several
Unity LTS versions on both Ubuntu and Windows 10. The WSL2 path (Neovim
running inside WSL2, Unity running on Windows, talking over `127.0.0.1`/host
IP with `LSP-TCP-socket-adapter` for the language server) is documented but
explicitly called out as **not fully tested** by the author ("using WSL2 on
Windows is still not fully tested"). Given this repo's Unity Editor runs
natively on Windows (not WSL) and only the Windows-native path needs to work,
the more mature "Neovim running natively on Windows" path applies, and the
WSL-specific TCP-adapter complexity in this guide is not needed here.

**Maintenance status.** Actively maintained:
- `walcht/neovim-unity`: 151 commits, latest **Mar 24, 2026** ("feat: add
  reference to unity-dap release page instead of building from source"), 192
  stars, 7 forks, 4 branches, no tags (rolling guide, not versioned software).
- `walcht/com.walcht.ide.neovim`: latest commit **Mar 20, 2026** ("chore:
  update README"), 25 stars, 15 forks. Its own README lists two open TODOs:
  "automatically refresh and sync Unity project when Neovim
  changes/adds assets (CRUCIAL)" and "add MacOS support (IMPORTANT)" — i.e.
  the author acknowledges the same Unity-doesn't-see-Neovim-created-files gap
  that `apyra/nvim-unity-sync` was built to plug, but has not yet closed it.
- Both repos are noticeably more recently touched (Mar 2026) than
  `apyra/nvim-unity-sync` (Oct 2025), and roughly contemporaneous with
  `apyra/nvim-unity` (Apr 2026).

**Known limitations documented by the author** (relevant if adopting this):
Unity does not recompile/pick up Neovim-side script changes until the Unity
Editor window regains focus (same gap as above); new C# files created from
Neovim get no LSP support until Unity is focused and regenerates `.csproj`
(this is precisely the problem `nvim-unity-sync` targets, but the two
projects are unrelated/not designed to interoperate); IL2CPP debugging is
unsupported in `unity-dap` (Mono only).

---

## Comparison

**Overlap and lineage.** All three projects are **independent, unrelated
implementations** of the same idea (Neovim as Unity's External Script
Editor) — none is a fork or documented successor of another. They were
created by two different, apparently-unconnected authors (`apyra` for the
first two; `walcht` for the third, which itself is really a guide bundling
together `com.walcht.ide.neovim`, `LSP-TCP-socket-adapter`, and `unity-dap`).
A Nov 2025 Unity Discussions thread has a user evaluating exactly this set of
options side by side and independently arriving at a similar decision matrix
to this report [discussions.unity.com/t/unity-neovim-and-wsl/1696326]:
`apyra/nvim-unity` "throw[s] a bunch of errors upon importing" for them and
assumes NvChad; `walcht/neovim-unity` "relies on yet another 'custom neovim
configuration'" (i.e. its README leans on the author's CGNvim distribution,
though plain Lua snippets are also given). The same thread's later replies
conclude that a bare `seblyng/roslyn.nvim` + Mason setup gets LSP working
without needing either project, and that `walcht/neovim-unity`'s WSL section
specifically is useful "for extra tooling support" but "not necessary to get
the LSP working" — i.e. these tools are additive to, not required for, the
LSP piece this repo has already solved with `csharp_ls`.

**Most actively maintained (as of Sept 2026):** `walcht/neovim-unity` /
`walcht/com.walcht.ide.neovim` (last touched Mar 2026, 192 stars on the guide
repo) and `apyra/nvim-unity` (last touched Apr 2026, 124 stars) are close,
both meaningfully more active than `apyra/nvim-unity-sync` (last touched Oct
2025, 20 stars, self-described "early development"). By star count and
apparent community pickup, `walcht/neovim-unity` is the more visible project;
by commit-recency and packaged installer distribution, `apyra/nvim-unity` is
comparably active.

**Most directly solves the `unity.lua` "open at line via `nvim --server`/
`--remote`" TODO:** **`walcht/com.walcht.ide.neovim`**, unambiguously — it is
the only one of the three whose documentation explicitly names the mechanism
this repo's TODO describes (`--server {serverSocket} --remote-tab {filePath}`
for opening, `--server {serverSocket} --remote-send
":call cursor({line},{column})<CR>"` for jump-to-line), with fully
user-configurable command templates and Windows-specific defaults (loopback
TCP socket on a random port, Win32-API window focusing, Windows
Terminal+PowerShell as the recommended terminal). `apyra/nvim-unity` also
claims click-to-open but does not document a jump-to-line/cursor-position
capability, and doesn't publish its underlying mechanism (it explicitly
avoids `nvr` but doesn't say whether it uses `--remote`/`--server` or
something else — likely proprietary logic inside its compiled
launcher/installer). `apyra/nvim-unity-sync` doesn't address this at all —
it only keeps `.csproj` current, with no Unity-Editor-side "open" or "jump"
behavior.

**Windows/PowerShell-specific setup facts gathered:**
- No registry changes are documented by any of the three projects.
- No firewall/port considerations are documented as required: the
  `com.walcht.ide.neovim` server socket on Windows is a loopback
  (`127.0.0.1`) TCP port chosen randomly per session — loopback traffic is
  not gated by Windows Firewall the way LAN-facing ports are, and nothing in
  the docs mentions needing an inbound-rule exception.
- `com.walcht.ide.neovim` recommends **Windows Terminal (`wt`) with
  PowerShell as the default shell**, and documents a PowerShell-script-based
  PPID relay it uses internally to find/focus the correct terminal window
  when the launch command spawns a detached child process (as `wt` does) —
  this is baked into the plugin, not something the user has to configure
  manually, but it's worth knowing "why PowerShell/wt" is the recommended
  combo.
- `apyra/nvim-unity`'s Windows path is the simplest to install (a single
  `nvimunity-setup.exe` installer) but its internal open/jump mechanism is
  undocumented, so it cannot be verified against this repo's TODO without
  reading its Editor C# source directly (out of scope for this pass — the
  source was not fetched).

---

## Sources

- https://github.com/apyra/nvim-unity (README, file listing, commit history, releases, contributors)
- https://github.com/apyra/nvim-unity-sync (README, file listing, commit history)
- https://github.com/walcht/neovim-unity (full README: installation, WSL2 setup, debugger setup, known limitations, commit history)
- https://github.com/walcht/com.walcht.ide.neovim/blob/master/README.md (full README: features, `--server`/`--remote-tab`/`--remote-send` command templates, Windows socket defaults, window-focus mechanism, TODOs)
- https://discussions.unity.com/t/unity-neovim-and-wsl/1696326 (real-world user comparison of `apyra/nvim-unity` vs. `walcht/neovim-unity` vs. plain `roslyn.nvim`, Nov 2025–Feb 2026)

Not fetched / not verified in this pass (flagged above where relevant):
- `apyra/nvim-unity`'s `Editor/` C# source (to confirm/deny jump-to-line
  support and its exact IPC mechanism).
- The Reddit release-announcement thread for `nvim-unity`
  (`r/linux_gaming`, "Plugin release: NvimUnity") — attempted but skipped
  after a Firecrawl rate limit; unlikely to add facts beyond the README.
- `walcht/LSP-TCP-socket-adapter` and `walcht/unity-dap` repos directly
  (covered only via the parent guide's description; relevant mainly to the
  WSL2 and debugging scenarios, which are out of scope since Unity Editor
  runs natively on Windows in this setup).
