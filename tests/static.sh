#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT/bin/workspace-stream"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
# Match literal shell defaults; expansion here would weaken the assertion.
# shellcheck disable=SC2016
grep -Fqx 'YTWS_WALLPAPER="$HOME/Pictures/background.jpg"' "$ROOT/config.example"
# shellcheck disable=SC2016
grep -Fq 'WALLPAPER="${YTWS_WALLPAPER:-$HOME/Pictures/background.jpg}"' \
    "$ROOT/bin/workspace-stream"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$ROOT/bin/workspace-stream" "$ROOT/install.sh" "$ROOT/uninstall.sh"
else
    printf 'shellcheck not installed; skipped\n'
fi

printf 'static checks passed\n'
