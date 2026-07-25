#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

XDG_BIN_HOME="$TMP/custom bin"
XDG_CONFIG_HOME="$TMP/custom config"
export XDG_BIN_HOME XDG_CONFIG_HOME

HYPR_DIR="$XDG_CONFIG_HOME/hypr"
CONFIG_DIR="$XDG_CONFIG_HOME/yt-stream-workspace"
SOURCE_LINE="source = $HYPR_DIR/yt-stream-workspace.conf"
printf -v QUOTED_BIN '%q' "$XDG_BIN_HOME/workspace-stream"

# A missing Hyprland root config must fail before writing a partial install.
if XDG_BIN_HOME="$TMP/missing-bin" XDG_CONFIG_HOME="$TMP/missing-config" \
    "$ROOT/install.sh" --hypr-source >"$TMP/missing.log" 2>&1; then
    printf 'install unexpectedly accepted a missing hyprland.conf\n' >&2
    exit 1
fi
test ! -e "$TMP/missing-bin/workspace-stream"
test ! -e "$TMP/missing-config/yt-stream-workspace/config"

mkdir -p "$HYPR_DIR"
printf '# test Hyprland config\n' >"$HYPR_DIR/hyprland.conf"

"$ROOT/install.sh" --hypr-source >"$TMP/install.log"

test -x "$XDG_BIN_HOME/workspace-stream"
test -r "$CONFIG_DIR/config"
test -r "$HYPR_DIR/yt-stream-workspace.conf"
grep -Fqx "$SOURCE_LINE" "$HYPR_DIR/hyprland.conf"
grep -Fq "$QUOTED_BIN" "$HYPR_DIR/yt-stream-workspace.conf"
test -e "$CONFIG_DIR/hypr-source-added"
test "$(sed -n '1p' "$CONFIG_DIR/.install-state/bin")" = created
test "$(sed -n '1p' "$CONFIG_DIR/.install-state/config")" = created
test "$(sed -n '1p' "$CONFIG_DIR/.install-state/hypr-snippet")" = created

"$XDG_BIN_HOME/workspace-stream" --help >/dev/null

"$ROOT/uninstall.sh" >"$TMP/uninstall.log"
test ! -e "$XDG_BIN_HOME/workspace-stream"
test ! -e "$HYPR_DIR/yt-stream-workspace.conf"
test -r "$CONFIG_DIR/config"
if grep -Fqx "$SOURCE_LINE" "$HYPR_DIR/hyprland.conf"; then
    printf 'uninstall left its owned Hyprland source line behind\n' >&2
    exit 1
fi
grep -Fqx '# test Hyprland config' "$HYPR_DIR/hyprland.conf"

"$ROOT/install.sh" >"$TMP/reinstall.log"
"$ROOT/uninstall.sh" --purge >"$TMP/purge.log"
test ! -e "$CONFIG_DIR/config"

# Existing files and a pre-existing source line are user-owned. A forced
# installation must back them up, and uninstall must restore them byte-for-byte.
mkdir -p "$XDG_BIN_HOME" "$CONFIG_DIR" "$HYPR_DIR"
printf '#!/usr/bin/env bash\nprintf "personal executable\\n"\n' \
    >"$XDG_BIN_HOME/workspace-stream"
chmod 700 "$XDG_BIN_HOME/workspace-stream"
printf 'YTWS_OUTPUT=PERSONAL\n' >"$CONFIG_DIR/config"
printf 'bind = SUPER,X,exec,true\n' >"$HYPR_DIR/yt-stream-workspace.conf"
printf '# user source\n%s\n' "$SOURCE_LINE" >"$HYPR_DIR/hyprland.conf"

cp "$XDG_BIN_HOME/workspace-stream" "$TMP/original-bin"
cp "$CONFIG_DIR/config" "$TMP/original-config"
cp "$HYPR_DIR/yt-stream-workspace.conf" "$TMP/original-snippet"

"$ROOT/install.sh" --force --hypr-source >"$TMP/forced-install.log"
test ! -e "$CONFIG_DIR/hypr-source-added"
test "$(sed -n '1p' "$CONFIG_DIR/.install-state/bin")" = replaced
test "$(sed -n '1p' "$CONFIG_DIR/.install-state/config")" = replaced
test "$(sed -n '1p' "$CONFIG_DIR/.install-state/hypr-snippet")" = replaced

"$ROOT/uninstall.sh" --purge >"$TMP/forced-uninstall.log"
cmp "$TMP/original-bin" "$XDG_BIN_HOME/workspace-stream"
cmp "$TMP/original-config" "$CONFIG_DIR/config"
cmp "$TMP/original-snippet" "$HYPR_DIR/yt-stream-workspace.conf"
grep -Fqx "$SOURCE_LINE" "$HYPR_DIR/hyprland.conf"
test "$(stat -c %a "$XDG_BIN_HOME/workspace-stream")" = 700

printf 'install smoke test passed\n'
