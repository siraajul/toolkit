#!/usr/bin/env bash
# install.sh — set up the toolkit on this machine.
# Symlinks every script in ./bin into ~/.local/bin and makes sure that
# directory is on PATH. Safe to re-run (idempotent).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin"
BIN_DST="$HOME/.local/bin"

mkdir -p "$BIN_DST"

echo "Linking tools from $BIN_SRC -> $BIN_DST"
for tool in "$BIN_SRC"/*; do
  [ -f "$tool" ] || continue
  name="$(basename "$tool")"
  chmod +x "$tool"
  ln -sf "$tool" "$BIN_DST/$name"
  echo "  linked $name"
done

# Ensure ~/.local/bin is on PATH (check common shell rc files).
path_line='export PATH="$HOME/.local/bin:$PATH"'
added=0
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  [ -f "$rc" ] || continue
  if ! grep -qF "$BIN_DST" "$rc" 2>/dev/null; then
    printf '\n# Added by toolkit install.sh\n%s\n' "$path_line" >> "$rc"
    echo "  added ~/.local/bin to PATH in $rc"
    added=1
  fi
done

echo
echo "Done. Run 'menu' to launch (open a new shell first if PATH was just updated)."
[ "$added" -eq 1 ] && echo "Note: restart your terminal or 'source' your shell rc to pick up PATH changes."
