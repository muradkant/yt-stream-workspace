#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yt-stream-workspace"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
HYPR_SOURCE_MARKER="$CONFIG_DIR/hypr-source-added"
INSTALL_STATE_DIR="$CONFIG_DIR/.install-state"
BACKUP_DIR="$INSTALL_STATE_DIR/backups"
BIN_MARKER="$INSTALL_STATE_DIR/bin"
CONFIG_MARKER="$INSTALL_STATE_DIR/config"
SNIPPET_MARKER="$INSTALL_STATE_DIR/hypr-snippet"
FORCE=0
INSTALL_DEPS=0
HYPR_SOURCE=0

for arg in "$@"; do
    case "$arg" in
    --force)
        FORCE=1
        ;;
    --deps)
        INSTALL_DEPS=1
        ;;
    --hypr-source)
        HYPR_SOURCE=1
        ;;
    -h|--help)
        printf 'Usage: ./install.sh [--force] [--deps] [--hypr-source]\n'
        printf '  --force        replace existing project files after backing them up\n'
        printf '  --deps         install Arch/CachyOS runtime dependencies with pacman\n'
        printf '  --hypr-source  append the source line to ~/.config/hypr/hyprland.conf if missing\n'
        exit 0
        ;;
    *)
        printf 'install.sh: unknown argument: %s\n' "$arg" >&2
        exit 2
        ;;
esac
done

if [[ "$INSTALL_DEPS" == 1 ]]; then
    if ! command -v pacman >/dev/null 2>&1; then
        printf 'install.sh: --deps requires pacman; install dependencies manually for this distro\n' >&2
        exit 1
    fi
    sudo pacman -S --needed wf-recorder wl-mirror jq ffmpeg pipewire-pulse kitty wtype iproute2
fi

if [[ "$HYPR_SOURCE" == 1 ]]; then
    HYPR_CONF="$HYPR_DIR/hyprland.conf"
    if [[ ! -e "$HYPR_CONF" ]]; then
        printf 'install.sh: cannot use --hypr-source; missing %s\n' "$HYPR_CONF" >&2
        exit 1
    fi
fi

backup_unowned_file() {
    local target="$1"
    local marker="$2"
    local backup="$3"

    if [[ ! -e "$marker" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -a -- "$target" "$backup"
        printf 'replaced\n' >"$marker"
    fi
}

mark_created() {
    local marker="$1"
    [[ -e "$marker" ]] || printf 'created\n' >"$marker"
}

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$HYPR_DIR" "$INSTALL_STATE_DIR"

if [[ -e "$BIN_DIR/workspace-stream" ]]; then
    backup_unowned_file \
        "$BIN_DIR/workspace-stream" "$BIN_MARKER" "$BACKUP_DIR/workspace-stream"
else
    mark_created "$BIN_MARKER"
fi
install -Dm755 "$ROOT/bin/workspace-stream" "$BIN_DIR/workspace-stream"

if [[ ! -e "$CONFIG_DIR/config" ]]; then
    mark_created "$CONFIG_MARKER"
    install -Dm644 "$ROOT/config.example" "$CONFIG_DIR/config"
elif [[ "$FORCE" == 1 ]]; then
    backup_unowned_file "$CONFIG_DIR/config" "$CONFIG_MARKER" "$BACKUP_DIR/config"
    install -Dm644 "$ROOT/config.example" "$CONFIG_DIR/config"
else
    printf 'Keeping existing config: %s\n' "$CONFIG_DIR/config"
fi

install_hypr_snippet() {
    local target="$HYPR_DIR/yt-stream-workspace.conf"
    local quoted_bin escaped_bin temporary

    printf -v quoted_bin '%q' "$BIN_DIR/workspace-stream"
    escaped_bin="${quoted_bin//\\/\\\\}"
    escaped_bin="${escaped_bin//&/\\&}"
    escaped_bin="${escaped_bin//|/\\|}"
    temporary="$(mktemp "$HYPR_DIR/.yt-stream-workspace.conf.XXXXXX")"
    sed "s|~/.local/bin/workspace-stream|$escaped_bin|g" \
        "$ROOT/hyprland/yt-stream-workspace.conf" >"$temporary"
    install -m 644 "$temporary" "$target"
    rm -f "$temporary"
}

if [[ ! -e "$HYPR_DIR/yt-stream-workspace.conf" ]]; then
    mark_created "$SNIPPET_MARKER"
    install_hypr_snippet
elif [[ "$FORCE" == 1 ]]; then
    backup_unowned_file \
        "$HYPR_DIR/yt-stream-workspace.conf" \
        "$SNIPPET_MARKER" \
        "$BACKUP_DIR/yt-stream-workspace.conf"
    install_hypr_snippet
else
    printf 'Keeping existing Hyprland snippet: %s\n' "$HYPR_DIR/yt-stream-workspace.conf"
fi

if [[ "$HYPR_SOURCE" == 1 ]]; then
    SOURCE_LINE="source = $HYPR_DIR/yt-stream-workspace.conf"
    LEGACY_SOURCE_LINE='source = ~/.config/hypr/yt-stream-workspace.conf'
    if grep -Fqx "$SOURCE_LINE" "$HYPR_CONF" ||
       grep -Fqx "$LEGACY_SOURCE_LINE" "$HYPR_CONF"; then
        printf 'Hyprland source line already present in %s\n' "$HYPR_CONF"
    else
        BACKUP="$HYPR_CONF.yt-stream-workspace.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$HYPR_CONF" "$BACKUP"
        printf '\n# yt-stream-workspace\n%s\n' "$SOURCE_LINE" >>"$HYPR_CONF"
        printf '%s\n' "$SOURCE_LINE" >"$HYPR_SOURCE_MARKER"
        printf 'Added Hyprland source line to %s\n' "$HYPR_CONF"
        printf 'Backup: %s\n' "$BACKUP"
    fi
fi

printf 'Installed workspace-stream to %s/workspace-stream\n' "$BIN_DIR"
printf 'Config: %s/config\n' "$CONFIG_DIR"
printf 'Hyprland snippet: %s/yt-stream-workspace.conf\n' "$HYPR_DIR"
printf '\n'
printf 'Add this line to hyprland.conf if you have not already:\n'
printf 'source = %s/yt-stream-workspace.conf\n' "$HYPR_DIR"
printf '\n'
printf 'Then reload Hyprland and run: workspace-stream self-test\n'
printf 'For prerequisite diagnostics, run: workspace-stream doctor\n'
