# Architecture

```text
applications
    │
    ▼
workspace N ──moved to──▶ headless output YT-STREAM
    │                          ├─ wf-recorder -o YT-STREAM → RTMP/RTMPS
    │                          └─ wl-mirror → physical monitor
    ▼
private workspaces on physical outputs
```

## Capture contract

- Visual isolation comes from `wf-recorder -o YT-STREAM`; process location has
  no bearing on capture.
- The designated workspace must both belong to and be active on `YT-STREAM`.
  Startup verifies both conditions.
- Hyprland remembers the last monitor used by a workspace. Recreating a
  same-named headless output can therefore attract unrelated workspaces.
  Startup snapshots existing workspace-to-monitor assignments and moves known
  private workspaces back before capture can begin.
- Safe workspace bindings call `workspace-stream workspace SELECTOR`, keeping
  the designated workspace assigned to the headless output.
- `enter` directs input to the stream workspace; `leave` returns it to the
  remembered physical monitor.

## Video contract

The recorder uses H.264 VAAPI on a render node proven by a tiny FFmpeg encode:

```text
wf-recorder -o YT-STREAM -c h264_vaapi -d /dev/dri/renderD…
```

Resolution, rate, scale, bitrate, GOP, and device are configuration, but output
selection is invariant.

## Preview contract

`wl-mirror` is a preview, not the capture boundary. Its automatic backend order
prefers `extcopy-dmabuf`, then other DMA-BUF paths, before shared-memory
fallbacks. `YTWS_MIRROR_BACKEND=extcopy-dmabuf` makes a path without a CPU
framebuffer copy a requirement on systems that support it.

The preview necessarily adds a presentation stage. Hyprland-native monitor
mirroring is not a safe replacement: Hyprland removes the mirrored physical
monitor from the logical monitor set and migrates its workspaces to another
monitor. If that monitor is `YT-STREAM`, private workspaces cross the capture
boundary. The windowed DMA-BUF mirror preserves monitor ownership and is the
intentional tradeoff.

## Audio contract

The prepared graph contains:

- `yt_stream_mix`, a null sink whose monitor `wf-recorder` captures;
- `yt_stream_output`, a combined sink feeding both the real output and mix;
- a loopback from the default microphone to the mix.

This yields desktop plus microphone with local monitoring. It is deliberately
global: visual isolation does not imply private audio.

## State and cleanup contract

Mode-700 state lives at `$XDG_RUNTIME_DIR/yt-stream-workspace/state`. It records
the session-defining configuration, stream workspace, original monitor and
active workspace, pre-session workspace-to-monitor assignments, preview
workspace, original audio devices, created PipeWire/Pulse modules, helper PIDs,
live PID, and VAAPI node. Snapshotting configuration is essential: editing the
config during a session must not change which output or audio resources
`stop` removes.

`workspace-stream stop` uses that ownership record to stop delivery and helper
processes, unload temporary audio modules, restore the original sink and
workspace assignments and focus, remove the headless output, and delete runtime
state. It checks helper executable identity before signalling recorded PIDs and
verifies that the virtual output actually disappeared, because Hyprland can
report command errors with a successful process exit status.

Diagnostic logs live separately under
`${XDG_STATE_HOME:-$HOME/.local/state}/yt-stream-workspace`, so cleanup does not
destroy the evidence needed to diagnose a failed start or self-test.

Install-time ownership is separate. Markers record whether the installer
created or replaced the executable, config, and Hyprland module; replacements
have restorable backups. The source marker contains the exact require line
added to `hyprland.lua`.

## Upstream contracts

- [Hyprland output control](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/)
  defines named headless output creation and removal.
- [wf-recorder](https://github.com/ammen99/wf-recorder) defines named output
  selection, audio source selection, codec parameters, VAAPI devices, and
  graceful signal handling.
- [wl-mirror](https://github.com/Ferdi265/wl-mirror) defines the preview backend
  preference order.
- [YouTube live encoder settings](https://support.google.com/youtube/answer/2853702)
  define the 60 fps maximum, H.264/AAC/CBR shape, and two-second recommended /
  four-second maximum keyframe interval enforced by configuration validation.
