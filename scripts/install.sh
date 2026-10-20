#!/usr/bin/env bash
# One-shot setup: Alacritty starts tmux, and tmux forwards Shift+Enter.
# Idempotent: re-running backs up and rewrites the same two files.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v alacritty >/dev/null || die "alacritty not installed"
command -v tmux     >/dev/null || die "tmux not installed"

ALACRITTY_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
TMUX_CFG="$HOME/.tmux.conf"
STAMP="$(date +%s)"

backup() { [ -e "$1" ] && cp -a "$1" "$1.bak.$STAMP" && printf 'backup: %s.bak.%s\n' "$1" "$STAMP"; return 0; }

# --- alacritty ----------------------------------------------------------
[ -f "$ALACRITTY_CFG" ] || { mkdir -p "$(dirname "$ALACRITTY_CFG")"; }
backup "$ALACRITTY_CFG"
cp "$SRC/files/alacritty.toml" "$ALACRITTY_CFG"

# A legacy ~/.alacritty.toml would be shadowed by this file anyway; retire it so
# the two cannot drift apart.
if [ -f "$HOME/.alacritty.toml" ]; then
    backup "$HOME/.alacritty.toml"
    rm -f "$HOME/.alacritty.toml"
    printf 'retired legacy: %s/.alacritty.toml (backup kept)\n' "$HOME"
fi

# --- tmux ---------------------------------------------------------------
backup "$TMUX_CFG"
cp "$SRC/files/tmux.conf" "$TMUX_CFG"

# --- verify -------------------------------------------------------------
printf '\n== versions ==\n'
alacritty --version
tmux -V

printf '\n== validate alacritty config ==\n'
alacritty migrate --dry-run --config-file "$ALACRITTY_CFG" >/dev/null

printf '== validate tmux config ==\n'
tmux -f "$TMUX_CFG" -L "otas-validate-$STAMP" start-server \; kill-server

printf '\n== done ==\n'
printf 'alacritty: %s\n' "$ALACRITTY_CFG"
printf 'tmux:      %s\n' "$TMUX_CFG"
printf '\nReload a running tmux with: tmux source-file ~/.tmux.conf\n'
printf 'Rows already inside a running tmux keep their old key mode; restart that server to pick up extended-keys.\n'
