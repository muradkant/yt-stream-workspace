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

## Audio contract

The prepared graph contains:

- `yt_stream_mix`, a null sink whose monitor `wf-recorder` captures;
- `yt_stream_output`, a combined sink feeding both the real output and mix;
- a loopback from the default microphone to the mix.

This yields desktop plus microphone with local monitoring. It is deliberately
global: visual isolation does not imply private audio.

## State and cleanup contract

Mode-700 state lives at `$XDG_RUNTIME_DIR/yt-stream-workspace/state`. It records
the stream workspace, original monitor, preview workspace, original audio
devices, created PipeWire/Pulse modules, helper PIDs, live PID, and VAAPI node.

`workspace-stream stop` uses that ownership record to stop delivery and helper
processes, unload temporary audio modules, restore the original sink and
workspace, remove the headless output, and delete runtime state. Install-time
ownership is separate: a marker records whether this project appended the
Hyprland source line, allowing uninstall to remove its own edit but preserve a
pre-existing user line.
