# toolkit

Personal command-line toolkit. A `menu` launcher plus the tools it runs.

## Tools

| Command   | What it does                                                        |
|-----------|--------------------------------------------------------------------|
| `menu`    | Interactive launcher / cheat-sheet for everything below            |
| `update`  | Run all system tool updates (brew, conda, flutter, npm, …)         |
| `morning` | Daily kickoff: weather, battery, disk, repos, GH, calendar         |
| `sweep`   | Reclaim disk space across pip/npm/brew/docker/xcode caches         |
| `doctor`  | Read-only system health diagnostics                                |
| `recon`   | Local network reconnaissance dashboard                             |
| `focus`   | Pomodoro timer with block-digit countdown (sets Do Not Disturb)    |
| `ship`    | Git workflow: lint → test → commit → push → PR                     |

## Install (on this or a new machine)

```sh
git clone <your-repo-url> ~/toolkit
~/toolkit/install.sh
```

`install.sh` symlinks every script in `bin/` into `~/.local/bin` and ensures
that directory is on your `PATH`. It is idempotent — safe to re-run after you
add or change tools.

## How it works

The real scripts live in `bin/` (under git). `~/.local/bin/<tool>` are just
symlinks pointing here, so editing a file in `bin/` immediately updates the
live command. Commit and push to back up; clone and run `install.sh` to restore.

## Adding a new tool

1. Drop an executable script in `bin/`.
2. Add a row to the `TOOLS=(...)` registry near the top of `bin/menu`.
3. Run `~/toolkit/install.sh` to link it, then `git add` + commit.
