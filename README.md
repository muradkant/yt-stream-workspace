# yt-stream-workspace

Stream one Hyprland workspace to YouTube while private workspaces remain local.

```text
stream workspace → headless output YT-STREAM → wf-recorder → YouTube
                         │
                         └→ wl-mirror preview on the physical monitor
```

The visual boundary is one argument: `wf-recorder -o YT-STREAM`. Capture follows
that output, not the workspace where the recorder process was launched. The
wrapper always names it explicitly.

This is practical visual isolation, not a sandbox. Desktop and microphone audio
are mixed globally by default; notifications, pinned windows, and overlays
rendered on `YT-STREAM` can appear; raw Hyprland commands can bypass the safe
workspace bindings.

## Install

The supported fast path is Arch/CachyOS with Hyprland:

```sh
git clone https://github.com/muradkant/yt-stream-workspace.git
cd yt-stream-workspace
./install.sh --deps --hypr-source
hyprctl reload
workspace-stream doctor
workspace-stream self-test
```

`--deps` installs `wf-recorder`, `wl-mirror`, `jq`, `ffmpeg`, `pipewire-pulse`,
`kitty`, `wtype`, and `iproute2` through pacman. On another distribution,
install those commands yourself and run `./install.sh --hypr-source`.
`swaybg` adds an optional virtual-output wallpaper; `shellcheck` strengthens
development checks.

Installation writes:

```text
~/.local/bin/workspace-stream
~/.config/yt-stream-workspace/config
~/.config/hypr/yt-stream-workspace.lua
```

With `--hypr-source`, it backs up `hyprland.lua` (Hyprland 0.55+ replaced the
hyprlang `.conf` format with Lua), appends `require("yt-stream-workspace")`
only when absent, and records ownership so `./uninstall.sh` removes only a line
this installation added. Generated bindings use the actual `XDG_BIN_HOME`, and
the require line is path-independent; non-default XDG paths are supported.

The installer records whether it created or replaced each managed file.
Replaced executables and modules are backed up and restored by uninstall. A
normal uninstall preserves the user configuration; `--purge` removes a created
config or restores a replaced one:

```sh
./uninstall.sh          # preserve config
./uninstall.sh --purge  # remove created config or restore replaced config
```

## Stream

Prepare workspace 3:

```sh
workspace-stream start 3
```

This moves workspace 3 to a `1920x1080@60` headless output at scale 1.5, opens
a local mirror, selects a working VAAPI H.264 render node, and creates the audio
mix. The selected workspace is explicitly activated on the virtual output;
known private workspaces are verified back on their original monitors even if
Hyprland tries to restore them to a same-named output from an earlier session.

Use `Super+F11` to control the stream workspace and `Super+F12` to return to the
physical monitor, or run `workspace-stream enter` and `workspace-stream leave`.
For ordinary navigation, replace direct Hyprland bindings with the wrapper so
the stream workspace stays pinned:

```ini
bind = SUPER,1,exec,~/.local/bin/workspace-stream workspace 1
bind = SUPER,2,exec,~/.local/bin/workspace-stream workspace 2
# continue through workspace 10
```

Validate locally before publishing:

```sh
workspace-stream test 5
```

The test starts a temporary RTMP receiver, records only `YT-STREAM`, injects a
tone, and requires H.264 at the configured dimensions plus non-silent AAC.

Start and stop YouTube delivery:

```sh
workspace-stream live       # prompts for the stream key without echo
workspace-stream stop-live  # leaves the prepared workspace intact
workspace-stream stop       # restores workspace, output, audio, and processes
```

`workspace-stream self-test` performs the entire local lifecycle on a temporary
workspace: virtual output, test terminal, keyboard handoff, return to the
physical monitor, RTMP, video, audio, and cleanup.

## Preview performance

The preview defaults to `wl-mirror`'s `auto` backend. It tries the GPU DMA-BUF
paths before shared memory; current Hyprland and wl-mirror releases normally
select `extcopy-dmabuf`. To reject a slower fallback instead of accepting it:

```sh
YTWS_MIRROR_BACKEND=extcopy-dmabuf
```

The recorder is also kept on the GPU: wf-recorder captures `YT-STREAM` through
DMA-BUF and H.264 encoding uses a tested VAAPI render node. `--no-damage` keeps
moving output paced at the configured 60 fps rather than recording only damage
events.

There is still an unavoidable distinction from a normal workspace. A normal
workspace is presented once; this design renders the headless output and then
presents a copied GPU buffer in a physical-output window. That can add a frame
of preview latency even when no frames are dropped. Hyprland's compositor-native
monitor mirroring is deliberately not used: it removes the physical output from
the logical layout and migrates its private workspaces onto the captured output,
which breaks the isolation contract.

`workspace-stream test` verifies encoded frame rate and media shape. It cannot
measure human-perceived input-to-preview latency. If preview motion is uneven,
first run `workspace-stream doctor`, require `extcopy-dmabuf`, and inspect the
persistent logs before changing resolution or frame rate.

## Configure

Edit `~/.config/yt-stream-workspace/config`:

```sh
YTWS_OUTPUT=YT-STREAM
YTWS_WIDTH=1920
YTWS_HEIGHT=1080
YTWS_FPS=60
YTWS_SCALE=1.5
YTWS_MIRROR_BACKEND=auto
YTWS_VIDEO_BITRATE=12M
YTWS_VIDEO_GOP=120
```

Leave `YTWS_VAAPI_DEVICE` unset unless detection chooses badly. The script tests
each `/dev/dri/renderD*` with a tiny FFmpeg H.264 encode and keeps the first
working node. Intel integrated graphics commonly provide this path; MX110/130
class NVIDIA GPUs do not provide NVENC.

The default audio graph sends desktop output to both the real speakers and a
stream sink, then loops the default microphone into that stream sink. If a
private application's audio must not leak, give it a separate PipeWire routing
policy before going live; visual separation cannot solve audio routing.

## Diagnose

```sh
workspace-stream status
workspace-stream doctor
```

If startup fails midway, `workspace-stream stop` is the first recovery step.
If the local RTMP port is occupied, change `YTWS_TEST_RTMP_PORT` (default
19350). If encoding fails, inspect `/dev/dri/renderD*` and set the tested node as
`YTWS_VAAPI_DEVICE`.

Logs survive session cleanup:

```sh
workspace-stream logs
```

They are stored under
`${XDG_STATE_HOME:-~/.local/state}/yt-stream-workspace`. Runtime ownership state
remains separate under `XDG_RUNTIME_DIR` and is removed after successful
cleanup.

The recorder's safety-critical shape is always:

```sh
wf-recorder -o YT-STREAM --audio=yt_stream_mix.monitor ...
```

Never substitute process location for `-o` output selection.

## Verify and develop

Repository checks are reproducible without modifying the real home directory:

```sh
make test   # syntax, ShellCheck, CLI/config behavior
make smoke  # isolated install, command load, and owned-config uninstall
```

Runtime verification needs a live Hyprland/PipeWire session:

```sh
workspace-stream self-test
```

[Architecture](docs/ARCHITECTURE.md) defines the capture, audio, state, and
cleanup contracts.
