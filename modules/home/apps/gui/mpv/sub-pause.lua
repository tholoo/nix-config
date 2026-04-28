-- sub-pause.lua
-- Pauses playback just before each subtitle line fades out, so the line is
-- still on screen when playback stops. Disabled by default; toggle via
-- script-message. Skips pausing on punctuation-only / bracketed sub lines so
-- markers like "[musique]" or "..." don't interrupt flow.
--
-- Key bindings live in mpv config; example:
--   p   script-message-to sub_pause toggle
--   r   script-message-to sub_pause replay

local mp = require 'mp'
local msg = require 'mp.msg'

msg.info("loaded; handlers: toggle, on, off, replay")

-- How early (in seconds of video time) to pause before the subtitle fades.
-- Small positive value — sub is still visible, you have time to read.
local LEAD = 0.05

local enabled = false
local fire_at = nil  -- video timestamp at which to pause, or nil

local function is_meaningful(text)
    if not text or text == "" then return false end
    local s = text:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return false end
    if s:match("^[%.%-%_%s]+$") then return false end
    if s:match("^%[.-%]$") then return false end
    if s:match("^%(.-%)$") then return false end
    return s:find("[^%p%s]") ~= nil
end

local function on_sub_text(_, text)
    if not enabled then
        fire_at = nil
        return
    end
    if is_meaningful(text) then
        local sub_end = mp.get_property_native("sub-end")
        if sub_end then
            fire_at = sub_end - LEAD
        else
            fire_at = nil
        end
    else
        fire_at = nil
    end
end

local function on_time_pos(_, pos)
    if not enabled or not pos or not fire_at then return end
    if pos >= fire_at then
        fire_at = nil
        mp.set_property_native("pause", true)
    end
end

local function set_enabled(state)
    enabled = state
    if not enabled then fire_at = nil end
    mp.osd_message("Auto-pause: " .. (enabled and "ON" or "OFF"), 1)
end

mp.observe_property("sub-text", "string", on_sub_text)
mp.observe_property("time-pos", "number", on_time_pos)

mp.register_script_message("toggle", function() set_enabled(not enabled) end)
mp.register_script_message("on",     function() set_enabled(true)       end)
mp.register_script_message("off",    function() set_enabled(false)      end)

-- Replay the current subtitle line from its start. Bound separately because
-- mpv's built-in `sub-seek 0` is inconsistent across versions.
mp.register_script_message("replay", function()
    local sub_start = mp.get_property_native("sub-start")
    if sub_start then
        mp.commandv("seek", sub_start, "absolute+exact")
        mp.set_property_native("pause", false)
    end
end)
