# alacritty-tmux-setup

One-shot config for **Alacritty + tmux** on Linux.

Two goals:

1. **Every Alacritty window is a tmux window.** `Shift+Enter` works inside TUI
   agents (Claude Code, Codex, omp, …) instead of being swallowed as a plain
   `Enter`.
2. **No wrapper scripts.** Alacritty's own `[terminal] shell` option starts
   `tmux new-session`; there is no `aliases`/`xinitrc`/`.bashrc` hack.

## Install

One line, no clone:

```sh
curl -fsSL https://raw.githubusercontent.com/PamelaSprin47685ghall/alacritty-tmux-setup/main/install.sh | bash
```

Or from a checkout:

```sh
git clone https://github.com/PamelaSprin47685ghall/alacritty-tmux-setup.git
cd alacritty-tmux-setup
./install.sh
```

The script is self-contained — the configs are inlined — so it does not care
about its working directory. It backs up anything it overwrites
(`*.bak.<epoch>`), then validates both files with `alacritty migrate --dry-run`
and a throwaway tmux server.

Requirements: `alacritty`, `tmux`. The config assumes the font
`Sarasa Term SC` is already installed — swap `font.normal.family` if not.

## What gets written

| File | Purpose |
| --- | --- |
| `~/.config/alacritty/alacritty.toml` (or `$XDG_CONFIG_HOME`) | visuals, font, `Shift+Enter` key binding, `[terminal] shell = tmux new-session` |
| `~/.tmux.conf` | `extended-keys on`, `mouse on`, vi copy mode, status bar styling, window-title propagation |

A legacy `~/.alacritty.toml` is retired to a backup, since the XDG file would
shadow it and the two could drift apart.

## Edge-to-edge and dynamic title

The Alacritty window has no padding (`padding = { x = 0, y = 0 }`) and no
decorations, so text sits flush against the screen edge.

The window title follows the active pane: `set-titles on` makes tmux report it,
`allow-rename on` lets programs inside the pane push their own title, and
Alacritty's `dynamic_title = true` renders it.

## Why `Shift+Enter` needs all of this

Three layers have to line up, and by default two of them do not:

| Layer | Default | Problem |
| --- | --- | --- |
| Alacritty | encodes `Shift+Enter` as `\r` | byte-identical to plain `Enter` |
| Alacritty | supports kitty `CSI > 1 u`, ignores xterm `CSI > 4 ; 2 m` | most TUIs only send `modifyOtherKeys` |
| tmux | `extended-keys off` | discards modified-key reports |

This repo fixes all three:

* Alacritty binding emits `CSI 13 ; 2 u` for `Shift+Enter`, scoped with
  `mode = "Alt"` so a normal shell prompt still gets a newline on `Enter`.
* `extended-keys on` makes tmux forward whatever the application asks for, and
  re-encodes it as `CSI 27 ; 2 ; 13 ~` for the pane.

`extended-keys always` is deliberately **not** used: it pushes the escape
sequence into programs that cannot parse it, which corrupts a plain bash
prompt (`bash: 2: command not found`).

## Apply to a running session

```sh
tmux source-file ~/.tmux.conf
```

Options that affect the terminal handshake (`extended-keys`) are read when a
pane's application starts, so restart long-running panes to pick them up.
Alacritty reloads its config live; no restart needed.

## Uninstall

Restore the newest `*.bak.*` next to each file.
