-- Hyprland integration for yt-stream-workspace.
--
-- Include it from hyprland.lua (Hyprland 0.55+ uses Lua instead of the
-- deprecated hyprlang .conf format):
--   require("yt-stream-workspace")
--
-- Or install it automatically with:
--   ./install.sh --hypr-source
--
-- Keep this aligned with ~/.config/yt-stream-workspace/config.

hl.monitor({
    output   = "YT-STREAM",
    mode     = "1920x1080@60",
    position = "auto-right",
    scale    = 1.5,
})

-- Control handoff.
hl.bind("SUPER + F11", hl.dsp.exec_cmd("~/.local/bin/workspace-stream enter"))
hl.bind("SUPER + F12", hl.dsp.exec_cmd("~/.local/bin/workspace-stream leave"))

-- Optional but recommended: route ordinary workspace switching through the
-- wrapper so the virtual stream output stays pinned to the stream workspace
-- during normal Super+number and mouse-wheel navigation. Add something like
-- this to your main hyprland.lua:
--
--   for i = 1, 10 do
--       local key = i % 10
--       hl.bind("SUPER + " .. key, hl.dsp.exec_cmd("~/.local/bin/workspace-stream workspace " .. i))
--   end
--   hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd("~/.local/bin/workspace-stream workspace m+1"))
--   hl.bind("SUPER + mouse_up",   hl.dsp.exec_cmd("~/.local/bin/workspace-stream workspace m-1"))
