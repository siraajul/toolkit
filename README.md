<div align="center">

```
███╗   ███╗███████╗███╗   ██╗██╗   ██╗
████╗ ████║██╔════╝████╗  ██║██║   ██║
██╔████╔██║█████╗  ██╔██╗ ██║██║   ██║
██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║   ██║
██║ ╚═╝ ██║███████╗██║ ╚████║╚██████╔╝
╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝
```

### `~/toolkit` — one launcher, seven dashboards, zero clutter

A personal macOS command-line toolkit. Type `menu`, pick a payload, watch it run
as a colorful step-by-step dashboard. Maintenance, diagnostics, and your git
workflow — all behind one door.

![platform](https://img.shields.io/badge/platform-macOS-000?logo=apple)
![shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![tools](https://img.shields.io/badge/payloads-8-39FF14)
![install](https://img.shields.io/badge/install-one%20script-blue)
![deps](https://img.shields.io/badge/missing%20deps-skipped%2C%20never%20fatal-success)

</div>

---

## ⚡ Quickstart

```sh
git clone https://github.com/siraajul/toolkit.git ~/toolkit
~/toolkit/install.sh
menu
```

That's it. `install.sh` symlinks everything into place, wires up `PATH`, and is
safe to re-run anytime. Open a fresh shell, type `menu`, go.

---

## 🧰 The payloads

| | command | what it does |
|---|---|---|
| 🎛️ | **`menu`** | Interactive launcher / cheat-sheet for everything below |
| 🔄 | **`update`** | Upgrade brew · conda · flutter · npm · rustup · uv · gem · macOS |
| ☀️ | **`morning`** | Daily brief: weather, battery, disk, dirty repos, GH, calendar |
| 🧹 | **`sweep`** | Reclaim disk — pip/npm/yarn/brew/docker/xcode/gradle caches + trash |
| 🩺 | **`doctor`** | Read-only health check: net, mem, battery, toolchains, brew doctor |
| 📡 | **`recon`** | Local network recon: IPs, gateway, DNS, ports, ARP, connections |
| 🍅 | **`focus`** | Pomodoro with giant block-digit countdown + Do-Not-Disturb |
| 🚀 | **`ship`** | Git flow: lint → typecheck → test → commit → push → open PR |

> Every tool renders a live grid of steps. Each step is independent and
> fault-tolerant — a missing tool is **skipped, not fatal**, and the tool only
> exits nonzero if something genuinely fails.

---

## 🎛️ `menu` — the front door

```sh
menu              # interactive picker (fzf, or numbered fallback)
menu --list       # just print the table
menu doctor       # launch a tool by name
```

Tools not on your `PATH` show up greyed-out with `✗`, so the menu doubles as an
install-status board. The registry is the `TOOLS=(...)` array atop `bin/menu`.

<details>
<summary><b>📖 Per-tool details (click to expand)</b></summary>

### 🔄 `update`
Refreshes every installed toolchain, skipping whatever's absent, continuing on
failure: **Homebrew** (`update`→`upgrade`→`cleanup`), **conda** base,
**Flutter** (retries `--force`), **npm** globals, **rustup**, **uv** self-update,
**RubyGems** (Homebrew Ruby; Apple's system gem skipped as read-only), and
**macOS** `softwareupdate -l` (lists only — never auto-installs).

### ☀️ `morning`
Read-only kickoff board: date, weather (`wttr.in`), battery, disk free, uptime,
outdated brew/npm counts, a clean-vs-dirty scan of git repos under `$HOME`, GH
unread notifications + open/review-requested PRs (`gh`), and today's calendar
(`icalBuddy`). Limit the repo scan with `REPO_DIRS="$HOME/code:$HOME/work" morning`.

### 🧹 `sweep`
Clears dev caches and reports bytes freed per step plus a measured grand total:
pip, npm, yarn, brew (`cleanup -s`), Docker (`system prune`), Xcode DerivedData,
CoreSimulator caches, Gradle build-cache, user `~/Library/Caches` files **>7 days
old**, and the Trash. Skips `~/Downloads` by design. ⚠️ Destructive — no prompt.

### 🩺 `doctor`
Read-only diagnostics: disk, memory pressure, swap, internet (multi-endpoint),
DNS, VPN (`utun`), battery health (cycles + condition), time sync, Xcode path,
toolchain versions (node/python/go/rust/git), `brew doctor`, dotfiles status.
Flags real problems (disk >90%, low memory, "Service Battery") as failures.

### 📡 `recon`
Read-only network dashboard for **your own** machine + LAN: hostname, MAC, LAN
IP, gateway, Wi-Fi SSID (when macOS permits), DNS servers, public IP / ISP /
city (`ipinfo.io`), VPN status, ARP neighbors, listening TCP ports, a localhost
port self-scan, and established-connection counts.

### 🍅 `focus`
Full-screen pomodoro: big block-digit `MM:SS`, progress bar, completion banner +
bell, then a one-line debrief logged to `~/.local/state/focus/log.txt`. Wire up
DnD via macOS Shortcuts named `DND On`/`DND Off`, or `SLACK_TOKEN` for Slack.

```sh
focus        # 25m default
focus 90s    # seconds
focus 1h     # hours
focus 50     # bare number = minutes
```

### 🚀 `ship`
Auto-detects your stack (`package.json` / `Cargo.toml` / `pyproject.toml` /
`go.mod`) and runs lint → typecheck → test → stage → commit → push → open PR as
a dashboard. **Refuses to run on `main`/`master`.** Stages tracked changes only;
opens a PR with `gh pr create --fill`. Optional `SLACK_WEBHOOK` posts on ship.

```sh
ship                      # auto commit message
ship -m "fix: tighten X"  # explicit message
ship -n                   # dry run — show steps, change nothing
```

</details>

---

## 🏗️ How it works

```
~/toolkit/
├── bin/            # the commands (menu + 7 tools) — real files live here
├── lib/
│   └── dashlib.sh  # shared dashboard engine, sourced by most tools
├── install.sh      # symlinks bin/* + lib/dashlib.sh into place, ensures PATH
└── README.md
```

Most tools share one engine — **`dashlib.sh`** — which draws the banner, the
step grid, runs steps in parallel with captured logs, and prints the summary.

The installed commands in `~/.local/bin/` and `~/.local/share/dashlib/` are
**symlinks back into this repo**, so editing a file here updates the live command
instantly — no reinstall needed.

```sh
# back up
cd ~/toolkit && git add -A && git commit -m "…" && git push

# restore on a new machine
git clone https://github.com/siraajul/toolkit.git ~/toolkit && ~/toolkit/install.sh
```

---

## ➕ Add your own tool

1. Drop an executable script in `bin/`. Want the dashboard look? `source
   ~/.local/share/dashlib/dashlib.sh` and use `dash_init` / `add_step` /
   `dash_run` / `dash_summary` like the others.
2. Add a row to the `TOOLS=(...)` registry in `bin/menu`.
3. `~/toolkit/install.sh && git add -A && git commit && git push`.

---

## 📦 Requirements

**macOS** + **bash**. Everything else is optional and skipped when missing:
`fzf` · `brew` · `conda` · `flutter` · `npm` · `yarn` · `rustup` · `uv` · `gem` ·
`go` · `node` · `python3` · `gh` · `jq` · `docker` · `icalBuddy` · `curl`.

<div align="center"><sub>built for <code>~</code> · made to survive a reinstall</sub></div>
