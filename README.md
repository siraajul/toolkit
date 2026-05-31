# toolkit

A personal command-line toolkit for macOS — a `menu` launcher plus seven
focused utilities for daily maintenance, diagnostics, and git workflow.

Every script is self-contained, dependency-light, and degrades gracefully:
each section checks for its backing tool with `command -v` and skips (rather
than errors) when something isn't installed.

---

## Install

```sh
git clone https://github.com/siraajul/toolkit.git ~/toolkit
~/toolkit/install.sh
```

`install.sh` symlinks every script in `bin/` into `~/.local/bin` and ensures
that directory is on your `PATH` (it appends to `.zshrc` / `.bashrc` /
`.bash_profile` only if needed). It is **idempotent** — safe to re-run anytime
you add or rename a tool. Open a new shell (or `source` your rc) afterward so
the updated `PATH` takes effect.

Then just run:

```sh
menu
```

---

## Tools

### `menu` — launcher / cheat-sheet
The front door. With no arguments it opens an interactive picker (uses
[`fzf`](https://github.com/junegunn/fzf) if installed, otherwise a numbered
fallback) and launches the tool you choose.

```sh
menu              # interactive picker
menu --list       # print the tool table and exit
menu --help       # usage + table
menu <name>       # launch a tool directly, e.g. `menu doctor`
```

Tools that aren't currently on `PATH` are shown greyed-out with an `✗`, so the
menu doubles as an install-status board. The registry lives in the `TOOLS=(...)`
array near the top of `bin/menu` — edit it to add or remove entries.

---

### `update` — system & package updates
Runs the upgrades you'd otherwise do by hand, each section independent and
skipped if the tool is missing. Safe to re-run.

Covers: **Homebrew** (`update` → `upgrade` → `cleanup`), **conda**
(`update --all`), **Flutter** (`flutter upgrade`), **npm** globals
(`npm update -g`), and **RubyGems** (`gem update --system`, Homebrew Ruby).

```sh
update
```

---

### `morning` — daily status board
Read-only dashboard for the start of the day. Prints, in order:

- **Weather** via `wttr.in` (no API key needed)
- **Battery** status (`pmset`)
- **Disk** usage of `/`
- **Recently active git repos** under `~` (edited in the last 7 days, depth ≤ 3)
- **GitHub notifications** (`gh api notifications`)
- **Today's calendar** (`icalBuddy`, if installed — `brew install ical-buddy`)

```sh
morning
```

---

### `sweep` — reclaim disk space
Walks common developer caches, shows each one's size, and **prompts before
deleting** (nothing is removed without a `y`).

Targets: pip cache, npm `_cacache`, Yarn cache, Homebrew cache, Docker
(`docker system prune`), and Xcode DerivedData + iOS DeviceSupport.

```sh
sweep
```

> ⚠️ Interactive and destructive on confirmation — read each prompt before
> answering `y`.

---

### `doctor` — system health diagnostics
**Read-only**, never changes anything. Reports OS version & uptime, load
average, memory (`vm_stat`), disk, the `en0` IP address, and the top processes
by CPU.

```sh
doctor
```

---

### `recon` — local network reconnaissance
**Read-only** LAN dashboard: your interfaces & IPs, default gateway, DNS
servers, local listening TCP ports (`lsof`), and a quick parallel ping sweep of
your `/24` to list reachable hosts.

```sh
recon
```

> Intended for inspecting **your own** network. The ping sweep scans the local
> subnet `en0` is attached to.

---

### `focus` — pomodoro timer
A minimalist countdown timer with large block-digit display.

```sh
focus            # default 25m
focus 25m        # minutes
focus 90s        # seconds
focus 1h         # hours
focus 50         # bare number = minutes
```

---

### `ship` — git workflow helper
One command for the lint → test → commit → push → open-PR loop.

```sh
ship                       # prompts for a commit message
ship -m "fix: tighten X"   # provide the message inline
ship -n                    # dry run — show what would happen, don't push
```

---

## How it works

The real scripts live in `bin/` under git. The commands in `~/.local/bin/` are
**symlinks** pointing back here, so editing a file in `bin/` instantly updates
the live command — no reinstall needed.

```
~/toolkit/
├── bin/            # the real scripts (menu + 7 tools)
├── install.sh      # symlinks bin/* → ~/.local/bin, ensures PATH
├── README.md
└── .gitignore
```

**Back up:** `cd ~/toolkit && git add -A && git commit -m "…" && git push`
**Restore on a new machine:** clone + `install.sh` (see [Install](#install)).

---

## Adding a new tool

1. Drop an executable script in `bin/` (`chmod +x`).
2. Add a row to the `TOOLS=(...)` registry near the top of `bin/menu`,
   following the `name | usage | description` format.
3. Run `~/toolkit/install.sh` to symlink it.
4. `git add -A && git commit && git push`.

---

## Requirements

- **macOS** (uses `pmset`, `sw_vers`, `vm_stat`, `ipconfig`, `scutil`, `route`).
- **bash** (scripts use `#!/usr/bin/env bash`).
- Optional, per tool: `fzf`, `brew`, `conda`, `flutter`, `npm`, `gem`, `gh`,
  `icalBuddy`, `docker`, `curl`. Anything missing is skipped, not fatal.
