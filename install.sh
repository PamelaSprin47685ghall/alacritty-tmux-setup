#!/usr/bin/env bash
# Alacritty + tmux one-shot setup.
#
# Every Alacritty window starts a tmux session, and Shift+Enter reaches TUI
# agents instead of being collapsed into a plain Enter.
#
# Usage (either works, no clone required):
#   curl -fsSL https://raw.githubusercontent.com/PamelaSprin47685ghall/alacritty-tmux-setup/main/install.sh | bash
#   ./install.sh
#
# Idempotent. Overwrites are backed up as <file>.bak.<epoch>.

set -euo pipefail

ALACRITTY_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
TMUX_CFG="$HOME/.tmux.conf"
LEGACY_CFG="$HOME/.alacritty.toml"
STAMP="$(date +%s)"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

command -v alacritty >/dev/null || die "alacritty not installed"
command -v tmux >/dev/null || die "tmux not installed"

backup() {
    [ -e "$1" ] || return 0
    cp -a "$1" "$1.bak.$STAMP"
    say "backup: $1.bak.$STAMP"
}

# --- write alacritty config ---------------------------------------------
mkdir -p "$(dirname "$ALACRITTY_CFG")"
backup "$ALACRITTY_CFG"

cat >"$ALACRITTY_CFG" <<'ALACRITTY_TOML'
# Alacritty + tmux setup
# https://github.com/PamelaSprin47685ghall/alacritty-tmux-setup
# Every Alacritty window starts a tmux session; the shell runs inside tmux.

[general]
live_config_reload = true

[window]
opacity = 0.9
startup_mode = "Maximized"
decorations = "None"
dynamic_padding = true
padding = { x = 10, y = 8 }
dynamic_title = true

[font]
normal = { family = "Sarasa Term SC" }
size = 18
offset = { x = 0, y = 1 }

[colors.primary]
background = "#000000"
foreground = "#dcdfe4"

[colors.cursor]
text = "#000000"
cursor = "#e5c07b"

[colors.normal]
black = "#3b4048"
red = "#e06c75"
green = "#98c379"
yellow = "#e5c07b"
blue = "#61afef"
magenta = "#c678dd"
cyan = "#56b6c2"
white = "#dcdfe4"

[colors.bright]
black = "#5c6370"
red = "#ff7b86"
green = "#b5e890"
yellow = "#ffd68a"
blue = "#7cc4ff"
magenta = "#dda0ee"
cyan = "#66d9e0"
white = "#ffffff"

[cursor]
style = { shape = "Underline", blinking = "Off" }
unfocused_hollow = true

[mouse]
bindings = [
    { mouse = "Right", action = "Paste" }
]

[selection]
save_to_clipboard = true

# Shift+Enter must reach applications (tmux, TUI agents) as a distinct key.
# Alacritty has no xterm modifyOtherKeys support, so emit the CSI-u form that
# tmux forwards. "mode = Alt" scopes it to full-screen apps: a plain shell
# prompt keeps its normal Enter behaviour.
[keyboard]
bindings = [
    { key = "Return", mods = "Shift", mode = "Alt", chars = "\u001b[13;2u" }
]

# Native Alacritty launch hook: no wrapper script needed.
[terminal]
shell = { program = "tmux", args = ["new-session"] }
ALACRITTY_TOML

# A legacy ~/.alacritty.toml is shadowed by the XDG file but can drift from it.
if [ -f "$LEGACY_CFG" ]; then
    backup "$LEGACY_CFG"
    rm -f "$LEGACY_CFG"
    say "retired legacy: $LEGACY_CFG (backup kept)"
fi

# --- write tmux config --------------------------------------------------
backup "$TMUX_CFG"

cat >"$TMUX_CFG" <<'TMUX_CONF'
# tmux setup for Alacritty
# https://github.com/PamelaSprin47685ghall/alacritty-tmux-setup

# --- terminal -----------------------------------------------------------
set -g default-terminal "tmux-256color"

# Shift+Enter / Ctrl+Enter / modified keys must be distinguishable inside
# panes. "on" lets applications opt in (TUI agents send CSI > 4 ; 2 m);
# "always" would push the sequences into programs that cannot parse them,
# which corrupts e.g. a plain bash prompt. Keep "on".
set -g extended-keys on
set -g extended-keys-format xterm
set -g focus-events on
set -g escape-time 10

# --- behaviour ----------------------------------------------------------
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
set -g set-clipboard on
set -g display-time 2000
setw -g mode-keys vi
setw -g monitor-activity on
set -g visual-activity off
set -g detach-on-destroy off

# --- look ---------------------------------------------------------------
set -g status-position bottom
set -g status-interval 5
set -g status-style "bg=#16181d,fg=#9aa5b1"

set -g status-left-length 40
set -g status-left "#[bg=#61afef,fg=#0b0d10,bold] #S #[bg=#16181d,fg=#61afef,nobold] "

set -g status-right-length 60
set -g status-right "#[fg=#5c6370]%Y-%m-%d #[fg=#98c379]%H:%M "

setw -g window-status-format "#[fg=#5c6370] #I:#W "
setw -g window-status-current-format "#[bg=#98c379,fg=#0b0d10,bold] #I:#W #[default]"
setw -g window-status-activity-style "fg=#e5c07b,bg=#16181d"

set -g pane-border-style "fg=#2b2f38"
set -g pane-active-border-style "fg=#61afef"

set -g message-style "bg=#16181d,fg=#e5c07b"
setw -g mode-style "bg=#3b4048,fg=#dcdfe4"

set -g clock-mode-colour "#61afef"
TMUX_CONF

# --- verify -------------------------------------------------------------
say ''
say '== versions =='
alacritty --version
tmux -V

say ''
say '== validate alacritty config =='
alacritty migrate --dry-run --config-file "$ALACRITTY_CFG" >/dev/null

say '== validate tmux config =='
tmux -f "$TMUX_CFG" -L "otas-validate-$STAMP" start-server \; kill-server

say ''
say '== done =='
say "alacritty: $ALACRITTY_CFG"
say "tmux:      $TMUX_CFG"
say ''
say 'Reload a running tmux with: tmux source-file ~/.tmux.conf'
say 'Panes already running keep their old key mode; restart that tmux server to pick up extended-keys.'
