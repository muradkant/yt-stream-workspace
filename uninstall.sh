#!/usr/bin/env bash
set -Eeuo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yt-stream-workspace"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
HYPR_CONF="$HYPR_DIR/hyprland.conf"
HYPR_SOURCE_MARKER="$CONFIG_DIR/hypr-source-added"

printf 'This removes only files installed by yt-stream-workspace.\n'

if [[ -e "$HYPR_SOURCE_MARKER" && -f "$HYPR_CONF" ]]; then
    BACKUP="$HYPR_CONF.yt-stream-workspace-uninstall.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$HYPR_CONF" "$BACKUP"
    sed -i \
        -e '/^# yt-stream-workspace$/d' \
        -e '\|^source = ~/\.config/hypr/yt-stream-workspace\.conf$|d' \
        "$HYPR_CONF"
    printf 'Removed the installer-owned Hyprland source line. Backup: %s\n' "$BACKUP"
fi

rm -f "$BIN_DIR/workspace-stream"
rm -f "$HYPR_DIR/yt-stream-workspace.conf"

if [[ -d "$CONFIG_DIR" ]]; then
    rm -f "$HYPR_SOURCE_MARKER"
    rm -f "$CONFIG_DIR/config"
    rmdir "$CONFIG_DIR" 2>/dev/null || true
fi

printf 'Uninstalled yt-stream-workspace files.\n'
