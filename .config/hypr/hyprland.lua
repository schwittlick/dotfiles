-- Hyprland config. See https://wiki.hypr.land/Configuring/Start/
-- Only non-default values are set here; everything else uses Hyprland's defaults.

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-2", mode = "3840x2160@60", position = "0x0", scale = 1.0 })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nemo"
local menu        = "rofi -show drun"
local whisperPtt  = "~/dev/whisper/.venv/bin/whisper-ptt" -- push-to-talk dictation, see ~/dev/whisper/readme.md

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")

    -- Deferred: dispatching dpms during startup directly is undefined behaviour.
    hl.timer(function()
        hl.dispatch(hl.dsp.dpms({ action = "on" }))
    end, { timeout = 500, type = "oneshot" })
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,

        border_size = 2,

        col = {
            active_border   = "rgba(ffff00ee)",
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = true,

        layout = "master",
    },

    decoration = {
        rounding       = 1,
        rounding_power = 10,

        blur = {
            size = 3,
        },
    },

    animations = {
        enabled = true,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/
    master = {
        mfact = 0.6,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        background_color        = 0x000000,
        -- lets a fresh hyprlock take over if the running one dies (recovery from tty2)
        allow_session_lock_restore = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "de",

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-------------------------------
---- LOCK SCREEN VT WORKAROUND ----
-------------------------------

-- After a tty round trip (Ctrl+Alt+F2, back to F1) Hyprland does not repaint the lock
-- screen. hyprlock then never gets a frame callback, never finishes its fade-out and cannot
-- unlock even after the password is accepted. Actions via hyprctl from tty2 do not help,
-- because Hyprland cannot commit while its VT is inactive. So: watch the active VT, and when
-- ours becomes active again while hyprlock runs, force a repaint with a DPMS off/on cycle.
if not _G.__vtWatch then
    local function activeVT()
        local f = io.open("/sys/class/tty/tty0/active", "r")
        if not f then return nil end
        local vt = f:read("*l")
        f:close()
        return vt
    end
    -- os.execute exit codes are lost (Hyprland reaps children), so read pidof's output
    local function hyprlockRunning()
        local p = io.popen("pidof hyprlock")
        if not p then return false end
        local out = p:read("*a") or ""
        p:close()
        return out:match("%d") ~= nil
    end
    local ownVT = activeVT()
    local lastVT = ownVT
    _G.__vtWatch = hl.timer(function()
        local vt = activeVT()
        if vt and vt ~= lastVT and vt == ownVT and hyprlockRunning() then
            hl.timer(function()
                hl.dispatch(hl.dsp.dpms({ action = "off" }))
                hl.timer(function()
                    hl.dispatch(hl.dsp.dpms({ action = "on" }))
                end, { timeout = 300, type = "oneshot" })
            end, { timeout = 1000, type = "oneshot" })
        end
        lastVT = vt or lastVT
    end, { timeout = 500, type = "repeat" })
end

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock &"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(
    [[command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()']]))

hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

hl.bind(mainMod .. " + A", hl.dsp.layout("swapwithmaster"))
hl.bind(mainMod .. " + S", hl.dsp.layout("focusmaster"))
hl.bind(mainMod .. " + Tab", function()
    hl.dispatch(hl.dsp.layout("rollnext"))
    hl.dispatch(hl.dsp.layout("focusmaster"))
end)

hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

-- Push-to-talk dictation: hold mainMod + Space to record, release to transcribe and type the
-- text at the cursor. The release bind does not fire when Super is let go before Space, so the
-- press handler also polls the Space key until it is released (a duplicate stop is a no-op).
do
    local pttPoll = nil
    local function pttStop()
        if pttPoll then pttPoll:set_enabled(false); pttPoll = nil end
        hl.dispatch(hl.dsp.exec_cmd(whisperPtt .. " stop"))
    end
    hl.bind(mainMod .. " + Space", function()
        hl.dispatch(hl.dsp.exec_cmd(whisperPtt .. " start"))
        if pttPoll then pttPoll:set_enabled(false) end
        pttPoll = hl.timer(function()
            if not hl.is_key_down("space") then pttStop() end
        end, { timeout = 50, type = "repeat" })
    end)
    hl.bind(mainMod .. " + Space", pttStop, { release = true })
end

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))

-- Switch workspaces with mainMod + [0-9], move the active window with SHIFT
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                 { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("~/.config/hypr/lid.sh close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid.sh open"),  { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    -- Ignore maximize requests from all apps.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
