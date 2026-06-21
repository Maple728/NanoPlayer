-- NanoPlayer custom idle screen.
-- Draws our logo (play triangle + wordmark + hint) when no file is playing, and
-- hides it once playback starts. mpv's own idle logo is disabled via
-- `--script-opts=osc-idlescreen=no`, so this replaces it.
--
-- Uses ASS vector drawing on an OSD overlay — the same mechanism mpv's built-in
-- OSC uses for its logo, so it scales cleanly with the window.

local overlay = mp.create_osd_overlay("ass-events")
overlay.res_x = 1280
overlay.res_y = 720

local function build()
    -- Play triangle (centroid-centered around cx, cy), accent magenta.
    local cx, cy = 640, 300
    local tri = string.format(
        "{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c&HE6308C&\\p1}m -30 -54 l -30 54 l 60 0{\\p0}",
        cx, cy)
    local name = "{\\an5\\pos(640,398)\\bord0\\shad0\\b1\\fs64\\1c&HFFFFFF&}NanoPlayer"
    local hint = "{\\an5\\pos(640,458)\\bord0\\shad0\\fs28\\1c&HBBBBBB&}拖入文件，或按 ⌘O 打开"
    return tri .. "\n" .. name .. "\n" .. hint
end

local function show()
    overlay.data = build()
    overlay:update()
    mp.set_property_native("user-data/nano/idle", true)
end

local function hide()
    overlay:remove()
    mp.set_property_native("user-data/nano/idle", false)
end

-- `idle-active` is true exactly when mpv has no file loaded.
mp.observe_property("idle-active", "bool", function(_, active)
    if active then show() else hide() end
end)
