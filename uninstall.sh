#!/usr/bin/env bash
set -Eeuo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yt-stream-workspace"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
HYPR_SOURCE_MARKER="$CONFIG_DIR/hypr-source-added"
INSTALL_STATE_DIR="$CONFIG_DIR/.install-state"
BACKUP_DIR="$INSTALL_STATE_DIR/backups"
BIN_MARKER="$INSTALL_STATE_DIR/bin"
CONFIG_MARKER="$INSTALL_STATE_DIR/config"
SNIPPET_MARKER="$INSTALL_STATE_DIR/hypr-snippet"
PURGE=0

case "${1:-}" in
"")
    ;;
--purge)
    PURGE=1
    ;;
-h|--help)
    printf 'Usage: ./uninstall.sh [--purge]\n'
    printf '  --purge  also remove installer-created config or restore replaced config\n'
    exit 0
    ;;
*)
    printf 'uninstall.sh: unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
esac

printf 'This removes only files installed by yt-stream-workspace.\n'

HYPR_LUA="$HYPR_DIR/hyprland.lua"
if [[ -e "$HYPR_SOURCE_MARKER" && -f "$HYPR_LUA" ]]; then
    BACKUP="$HYPR_LUA.yt-stream-workspace-uninstall.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$HYPR_LUA" "$BACKUP"
    # Remove the require line this installer owns, plus any source line left by
    # an install made before the Hyprland 0.55 Lua migration.
    sed -i \
        -e '/^# yt-stream-workspace$/d' \
        -e '/^require("yt-stream-workspace")$/d' \
        -e '/^source = .*yt-stream-workspace.*\.conf$/d' \
        "$HYPR_LUA"
    printf 'Removed the installer-owned Hyprland require line. Backup: %s\n' "$BACKUP"
fi

restore_or_remove() {
    local target="$1"
    local marker="$2"
    local backup="$3"
    local label="$4"

    [[ -r "$marker" ]] || {
        printf 'Preserving unowned %s: %s\n' "$label" "$target"
        return
    }

    case "$(sed -n '1p' "$marker")" in
    created)
        rm -f "$target"
        ;;
    replaced)
        if [[ -e "$backup" ]]; then
            mkdir -p "$(dirname "$target")"
            cp -a -- "$backup" "$target"
            rm -f "$backup"
            printf 'Restored pre-existing %s: %s\n' "$label" "$target"
        else
            printf 'uninstall.sh: missing backup; preserving %s: %s\n' \
                "$label" "$target" >&2
            return
        fi
        ;;
    *)
        printf 'uninstall.sh: invalid ownership marker; preserving %s: %s\n' \
            "$label" "$target" >&2
        return
        ;;
    esac
    rm -f "$marker"
}

restore_or_remove \
    "$BIN_DIR/workspace-stream" "$BIN_MARKER" "$BACKUP_DIR/workspace-stream" \
    "workspace-stream executable"
restore_or_remove \
    "$HYPR_DIR/yt-stream-workspace.lua" "$SNIPPET_MARKER" \
    "$BACKUP_DIR/yt-stream-workspace.lua" "Hyprland module"

rm -f "$HYPR_SOURCE_MARKER"

if [[ "$PURGE" == 1 ]]; then
    restore_or_remove \
        "$CONFIG_DIR/config" "$CONFIG_MARKER" "$BACKUP_DIR/config" \
        "configuration"
else
    printf 'Preserving configuration: %s/config\n' "$CONFIG_DIR"
fi

if [[ -d "$BACKUP_DIR" ]]; then
    rmdir "$BACKUP_DIR" 2>/dev/null || true
fi
if [[ -d "$INSTALL_STATE_DIR" ]]; then
    rmdir "$INSTALL_STATE_DIR" 2>/dev/null || true
fi
if [[ -d "$CONFIG_DIR" ]]; then
    rmdir "$CONFIG_DIR" 2>/dev/null || true
fi

printf 'Uninstalled yt-stream-workspace files.\n'