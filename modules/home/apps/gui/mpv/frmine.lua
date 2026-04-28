-- frmine.lua
-- One-shot mine-and-enrich: pick a French word (cycle or type), this script
-- triggers mpvacious to mine the current sub AND enriches the new card with
-- the word's dictionary data — all from a single keypress.
--
-- Each mine creates a new card. Multiple words from the same scene → multiple
-- cards (one per word, all sharing the same Sentence/Audio/Screenshot). This
-- is the standard immersion-mining approach so each word gets its own SRS
-- review schedule. "Bury siblings" in Anki prevents seeing the same scene
-- twice on one review day.
--
-- Bindings live in the mpv module:
--   Alt+w    script-message-to frmine cycle          (scrub words: see+hear, Enter mines)
--   Ctrl+d   script-message-to frmine enrich         (type word → mine card)
--   Ctrl+L   script-message-to frmine lookup-type    (type word → OSD lookup, no card)
--   Ctrl+k   script-message-to frmine mark-known     (add lemma to known list)
--
-- Alt+w opens a unified scrub UI: each h/l or ←/→ step live-fetches the
-- highlighted word's dictionary entry, displays it in the OSD, and speaks
-- the lemma via espeak-ng. Enter mines the currently-highlighted word into
-- Anki and exits. Esc exits without mining. This is "look up *and* maybe
-- mine" in one keypress instead of two — you don't have to decide before
-- starting which mode you wanted.
--
-- Skipped paths (mining only):
--   - Words already on ~/.local/share/frdict/known.txt are not mined.
--   - Words frdict can't find at all are not mined.
--
-- Ctrl+e (mpvacious-export-note) still works as a separate "mine sentence
-- only, no target word" path.

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

msg.info("loaded; handlers: enrich, cycle, lookup-type, lookup-cycle, mark-known")

local FRDICT_URL = "http://127.0.0.1:8767"
local ANKI_URL = "http://127.0.0.1:8765"
local ANKI_DECK = "French::Mining"
local ANKI_NOTE_TYPE = "French Mining"
local PROMOTE_RANK_THRESHOLD = 2000
local KNOWN_FILE = (os.getenv("HOME") or "") .. "/.local/share/frdict/known.txt"

-- Try to load mp.input; available in mpv 0.38+.
local input_mod = nil
do
    local ok, mod = pcall(require, 'mp.input')
    if ok then input_mod = mod end
end

local function urlencode(s)
    return (s:gsub("[^%w%-_.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Find a whole-word occurrence of `surface` in `sentence`, case-insensitive.
-- Returns byte indices (i, j) of the match in `sentence`, or nil if not found.
-- Word boundary = string start/end or a space/punctuation char on either side.
local function find_word_at_boundary(sentence, surface)
    local lower_sent = sentence:lower()
    local lower_surf = surface:lower()
    local start = 1
    while true do
        local i, j = lower_sent:find(lower_surf, start, true)
        if not i then return nil end
        local before = i == 1 or sentence:sub(i - 1, i - 1):match("[%s%p]")
        local after = j == #sentence or sentence:sub(j + 1, j + 1):match("[%s%p]")
        if before and after then return i, j end
        start = j + 1
    end
end

local function bold_word(sentence, surface)
    local i, j = find_word_at_boundary(sentence, surface)
    if not i then return sentence end
    return sentence:sub(1, i - 1) .. "<b>" .. sentence:sub(i, j) .. "</b>" .. sentence:sub(j + 1)
end

local function blank_word(sentence, surface)
    local i, j = find_word_at_boundary(sentence, surface)
    if not i then return sentence end
    return sentence:sub(1, i - 1) .. "___" .. sentence:sub(j + 1)
end

local function run(args)
    local res = mp.command_native({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    })
    if res.status ~= 0 then
        msg.error("subprocess failed (" .. tostring(res.status) .. "): " .. (res.stderr or ""))
        return nil
    end
    return res.stdout
end

local function http_get_json(url)
    local body = run({ "curl", "-s", "-fL", "--max-time", "5", url })
    if not body then return nil end
    local decoded, err = utils.parse_json(body)
    if err then
        msg.error("parse_json: " .. err)
        return nil
    end
    return decoded
end

local function http_post_json(url, payload)
    local body = utils.format_json(payload)
    local out = run({
        "curl", "-s", "-fL", "--max-time", "5",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", body, url,
    })
    if not out then return nil end
    local decoded, err = utils.parse_json(out)
    if err then
        msg.error("parse_json: " .. err)
        return nil
    end
    return decoded
end

local function find_latest_note()
    local query = string.format('deck:"%s" "note:%s" added:1', ANKI_DECK, ANKI_NOTE_TYPE)
    local res = http_post_json(ANKI_URL, {
        action = "findNotes",
        version = 6,
        params = { query = query },
    })
    if not res or res.error then
        msg.error("findNotes: " .. tostring(res and res.error or "no response"))
        return nil
    end
    local ids = res.result or {}
    if #ids == 0 then return nil end
    local max_id = ids[1]
    for _, id in ipairs(ids) do
        if id > max_id then max_id = id end
    end
    return max_id
end

local function update_note_once(note_id, fields)
    local res = http_post_json(ANKI_URL, {
        action = "updateNoteFields",
        version = 6,
        params = { note = { id = note_id, fields = fields } },
    })
    if not res then return false, "no response" end
    if res.error then return false, res.error end
    return true, nil
end

-- Fetch a single note's fields. Returns table or nil.
local function get_note_fields(note_id)
    local res = http_post_json(ANKI_URL, {
        action = "notesInfo",
        version = 6,
        params = { notes = { note_id } },
    })
    if not res or res.error or not res.result or not res.result[1] then return nil end
    return res.result[1].fields or {}
end

local function get_sentence(note_id)
    local f = get_note_fields(note_id)
    if not f then return "" end
    return (f.Sentence and f.Sentence.value) or ""
end

-- Deselect any note currently open in Anki's browser editor.
-- This forces the editor to flush its in-memory field cache back to disk
-- before we update. Without this step, the editor's cached "[empty]" Lemma
-- (from mpvacious's addNote) gets auto-saved AFTER our update lands,
-- silently reverting our enrichment.
local function deselect_browser_note()
    http_post_json(ANKI_URL, {
        action = "guiBrowse",
        version = 6,
        params = { query = "nid:0" },  -- nid:0 matches nothing → deselects
    })
end

-- Update note fields, then verify the update actually stuck and retry on
-- mismatch. The editor-flush dance is the primary protection against
-- mpvacious's guiBrowse-induced clobber; verify+retry is the fallback.
local function update_note(note_id, fields, on_done)
    local function attempt(retry)
        deselect_browser_note()
        local ok, err = update_note_once(note_id, fields)
        if not ok then
            if on_done then on_done(false, err) end
            return
        end
        -- Read back AFTER a small delay so any editor autosave that might
        -- still be in flight has time to settle.
        mp.add_timeout(0.3, function()
            local actual = get_note_fields(note_id)
            local sentinel = fields.Lemma or ""
            local actual_lemma = (actual and actual.Lemma and actual.Lemma.value) or ""
            if actual_lemma == sentinel then
                if on_done then on_done(true, nil) end
                return
            end
            if retry > 0 then
                msg.warn(string.format(
                    "update verify failed (Lemma=%q expected %q) — retrying in 1s, %d attempts left",
                    actual_lemma, sentinel, retry
                ))
                mp.add_timeout(1.0, function() attempt(retry - 1) end)
            else
                if on_done then on_done(false, "update did not stick after retries") end
            end
        end)
    end
    attempt(2)
end

-- Pick the lemma with the smallest freq_rank (most common). Lemmas without a
-- rank fall to the back.
local function pick_match(matches)
    if not matches or #matches == 0 then return nil end
    table.sort(matches, function(a, b)
        return (a.freq_rank or 999999) < (b.freq_rank or 999999)
    end)
    return matches[1]
end

-- Read the known-words file fresh on each call. Small file, microseconds to
-- parse; lets the Anki addon append concurrently without us caching stale.
local function read_known_set()
    local set = {}
    local f = io.open(KNOWN_FILE, "r")
    if not f then return set end
    for line in f:lines() do
        local t = trim(line):lower()
        if t ~= "" then set[t] = true end
    end
    f:close()
    return set
end

local function append_known(lemma)
    local f = io.open(KNOWN_FILE, "a")
    if not f then
        msg.error("could not open " .. KNOWN_FILE .. " for append")
        return false
    end
    f:write(lemma .. "\n")
    f:close()
    return true
end

-- Apply the dictionary fields for `match` to a specific Anki note.
local function apply_match_to_note(note_id, match, surface, n_alt)
    local rank = match.freq_rank
    local fields = {
        Lemma = match.lemma or "",
        SurfaceForm = match.surface or surface,
        IPA = match.ipa or "",
        POS = match.pos or "",
        FrequencyRank = rank and tostring(rank) or "",
        Definition_EN = table.concat(match.definitions_en or {}, "; "),
        Definition_FR = table.concat(match.definitions_fr or {}, "; "),
    }
    -- mpvacious wrote Sentence as plain subtitle text. Post-process: bold the
    -- target word for the recognition card, build the blanked variant for the
    -- production card. Skipped if the surface isn't found at a word boundary
    -- in the sentence (rare — would mean cycle-state and sub-text drifted).
    local current_sentence = get_sentence(note_id)
    if current_sentence ~= "" then
        local bolded = bold_word(current_sentence, surface)
        if bolded ~= current_sentence then
            fields.Sentence = bolded
            fields.SentenceBlanked = blank_word(current_sentence, surface)
        end
    end
    if rank and rank <= PROMOTE_RANK_THRESHOLD then
        fields.Promote = "1"
    end
    -- Wait 500ms before the first update so mpvacious's addNote has time to
    -- fully commit. Without the delay the update can race the in-flight write
    -- and silently get clobbered (AnkiConnect returns success either way).
    mp.add_timeout(0.5, function()
        update_note(note_id, fields, function(ok, err)
            if not ok then
                msg.error("apply: updateNoteFields failed: " .. tostring(err))
                mp.osd_message("frmine: AnkiConnect error — " .. tostring(err), 5)
                return
            end
            msg.info(string.format("apply: enriched note %d with lemma=%s", note_id, match.lemma))
            local alt_str = ""
            if n_alt > 0 then
                alt_str = string.format(" (+%d alt)", n_alt)
            end
            mp.osd_message(
                string.format("Mined: %s [%s]%s", match.lemma, match.pos or "?", alt_str),
                3
            )
        end)
    end)
end

-- One-shot: trigger mpvacious to mine the current sub, then enrich the
-- newly-created note with `word`'s dictionary data. Polls AnkiConnect for
-- the new note ID since mpvacious mining is asynchronous.
local function mine_and_enrich(word)
    word = trim(word or ""):lower()
    if word == "" then
        mp.osd_message("frmine: empty input", 2)
        return
    end

    -- Look up first so we can bail before mining if the word is unknown
    -- to the dictionary or already on the user's known list.
    local data = http_get_json(FRDICT_URL .. "/lookup?word=" .. urlencode(word))
    if not data then
        mp.osd_message("frmine: lookup failed (is frdict running?)", 4)
        return
    end
    local match = pick_match(data.matches)
    if not match then
        mp.osd_message("frmine: no match for '" .. word .. "'", 3)
        return
    end
    if read_known_set()[match.lemma] then
        mp.osd_message("Already known: " .. match.lemma .. " — skipped", 3)
        return
    end

    local before_id = find_latest_note() or 0
    msg.info(string.format("mine: lemma=%s before_id=%d", match.lemma, before_id))
    mp.osd_message("Mining " .. match.lemma .. "…", 2)
    mp.commandv("script-binding", "mpvacious-export-note")

    -- Poll for the new note ID. mpvacious export is async; usually lands
    -- within a second but can take longer for big audio extractions or
    -- slow disks. Bumped from 5s to 15s after seeing real-world timeouts.
    local n_alt = #data.matches - 1
    local attempts = 75  -- 75 * 200ms = 15s
    local started = mp.get_time()
    local function poll()
        local now_id = find_latest_note()
        if now_id and now_id > before_id then
            local elapsed = mp.get_time() - started
            msg.info(string.format("mine: note %d found after %.2fs, enriching", now_id, elapsed))
            apply_match_to_note(now_id, match, word, n_alt)
            return
        end
        attempts = attempts - 1
        if attempts <= 0 then
            msg.warn(string.format(
                "mine: TIMEOUT after %.1fs — last find_latest_note=%s before_id=%d",
                mp.get_time() - started, tostring(now_id), before_id
            ))
            mp.osd_message(
                "frmine: timed out waiting for card (15s) — see log",
                5
            )
            return
        end
        mp.add_timeout(0.2, poll)
    end
    poll()
end

local function prompt()
    if not input_mod then
        mp.osd_message("frmine: requires mpv 0.38+ (mp.input)", 5)
        return
    end
    input_mod.get({
        prompt = "Mine word: ",
        submit = function(text)
            input_mod.terminate()
            mine_and_enrich(text)
        end,
    })
end

mp.register_script_message("enrich", prompt)

local function prompt_mark_known()
    if not input_mod then
        mp.osd_message("frmine: requires mpv 0.38+ (mp.input)", 5)
        return
    end
    input_mod.get({
        prompt = "Mark known: ",
        submit = function(text)
            input_mod.terminate()
            local word = trim(text or ""):lower()
            if word == "" then
                mp.osd_message("frmine: empty input", 2)
                return
            end
            -- Lemmatize so we add the canonical form even if the user typed
            -- a conjugation/inflection (allions → aller).
            local data = http_get_json(FRDICT_URL .. "/lookup?word=" .. urlencode(word))
            local match = data and pick_match(data.matches)
            local lemma = (match and match.lemma) or word
            if read_known_set()[lemma] then
                mp.osd_message("Already in known list: " .. lemma, 2)
                return
            end
            if append_known(lemma) then
                mp.osd_message("Marked known: " .. lemma, 2)
            end
        end,
    })
end

mp.register_script_message("mark-known", prompt_mark_known)

-- ---------------------------------------------------------------------------
-- Lookup-only (no card creation)
--
-- Format a frdict match as a multi-line OSD overlay. Caller decides duration.

local function format_lookup(match, n_alt)
    local parts = {}
    local header = match.lemma
    if match.pos and match.pos ~= "" then
        header = header .. "  (" .. match.pos .. ")"
    end
    if match.freq_rank then
        header = header .. "  · rank " .. match.freq_rank
    end
    table.insert(parts, header)
    if match.ipa and match.ipa ~= "" then
        table.insert(parts, "/" .. match.ipa .. "/")
    end
    local en = table.concat(match.definitions_en or {}, "; ")
    if en ~= "" then
        if #en > 220 then en = en:sub(1, 217) .. "..." end
        table.insert(parts, "EN: " .. en)
    end
    local fr = table.concat(match.definitions_fr or {}, "; ")
    if fr ~= "" then
        if #fr > 220 then fr = fr:sub(1, 217) .. "..." end
        table.insert(parts, "FR: " .. fr)
    end
    if n_alt > 0 then
        table.insert(parts, string.format("(+%d other matches)", n_alt))
    end
    return table.concat(parts, "\n")
end

-- Speak a French word by streaming frdict's /speak WAV through ffplay. Async
-- so playback doesn't block the OSD render. frdict picks the engine (Piper
-- if PIPER_VOICE is configured, espeak-ng fallback) — quality matches the
-- reader UI's pronunciations.
--
-- Cancels any in-flight pronunciation before starting a new one so fast
-- cycling through words doesn't pile up overlapping playback. Silently
-- no-ops if frdict or ffplay is unavailable.
local active_speak = nil
local function speak(word)
    if active_speak then
        mp.abort_async_command(active_speak)
        active_speak = nil
    end
    local url = FRDICT_URL .. "/speak?word=" .. urlencode(word)
    active_speak = mp.command_native_async({
        name = "subprocess",
        args = { "ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", url },
        playback_only = false,
        capture_stdout = false,
        capture_stderr = false,
    }, function() active_speak = nil end)
end

local function lookup_only(word)
    word = trim(word or ""):lower()
    if word == "" then
        mp.osd_message("frmine: empty input", 2)
        return
    end
    local data = http_get_json(FRDICT_URL .. "/lookup?word=" .. urlencode(word))
    if not data then
        mp.osd_message("frmine: lookup failed (is frdict running?)", 4)
        return
    end
    local match = pick_match(data.matches)
    if not match then
        mp.osd_message("frmine: no match for '" .. word .. "'", 3)
        return
    end
    mp.osd_message(format_lookup(match, #data.matches - 1), 12)
    speak(match.lemma)
end

local function prompt_lookup()
    if not input_mod then
        mp.osd_message("frmine: requires mpv 0.38+ (mp.input)", 5)
        return
    end
    input_mod.get({
        prompt = "Look up: ",
        submit = function(text)
            input_mod.terminate()
            lookup_only(text)
        end,
    })
end

mp.register_script_message("lookup-type", prompt_lookup)

-- ---------------------------------------------------------------------------
-- Word-cycle selection
--
-- One unified scrub UI. Grab current sub, tokenize, walk word-by-word with
-- h/l or ←/→. Each step live-fetches the dictionary entry and speaks the
-- lemma so you read+hear without committing. Enter mines the highlighted
-- word into Anki. Esc exits without mining.

local cycle_state = nil  -- { words, spans, idx, sub_style } when active, nil otherwise
local sub_overlay = nil
local info_overlay = nil
local saved_sub_visibility = nil
local saved_osd_use_margins = nil

-- ASS canvas: 1280x720 is mpv's standard script resolution. Coordinates below
-- are in this space; mpv scales to actual screen size.
local ASS_RES_X = 1280
local ASS_RES_Y = 720

-- INFO and HINT remain styled by us — they're our chrome (definition card +
-- key hint), not the user's sub. SUB_STYLE is built per-cycle in
-- build_sub_style() to mirror mpv's live sub-* render so the overlay is
-- visually seamless with the subtitle it just replaced.
local INFO_STYLE = "\\an8\\pos(640,30)\\fnArial\\fs26\\bord1.5\\shad0.5\\1c&HFFFFFF&\\3c&H000000&"
local HINT_STYLE = "\\fs20\\1c&HAAAAAA&"

-- mpv property output for colors is "#AARRGGBB" (alpha leading) or "#RRGGBB".
-- ASS wants "&HBBGGRR&" (no alpha — opacity goes in separate \1a/\3a/\4a tags
-- we don't bother with; sub rendering is always fully opaque). Getting the
-- byte order wrong here turns the default black border red, because the
-- alpha=FF byte gets read as the red component.
local function ass_color(mpv_color, fallback)
    if not mpv_color or mpv_color == "" then return fallback end
    local hex = mpv_color:gsub("^#", "")
    if #hex == 8 then hex = hex:sub(3) end  -- drop leading alpha
    if #hex ~= 6 then return fallback end
    local rr, gg, bb = hex:sub(1, 2), hex:sub(3, 4), hex:sub(5, 6)
    return "&H" .. bb:upper() .. gg:upper() .. rr:upper() .. "&"
end

-- mpv align-x ∈ {left, center, right}, align-y ∈ {top, center, bottom}.
-- ASS \an: 1=BL 2=BC 3=BR 4=ML 5=MC 6=MR 7=TL 8=TC 9=TR.
local function ass_alignment(align_x, align_y)
    local row = ({ bottom = 0, center = 3, top = 6 })[align_y] or 0
    local col = ({ left = 1, center = 2, right = 3 })[align_x] or 2
    return row + col
end

-- Read mpv's live sub render properties and translate into an ASS style
-- prefix that the overlay can use to mimic the subtitle it's replacing.
-- mpv documents sub-font-size/sub-margin-* as "scaled pixels at 720 height",
-- and our ASS canvas is 1280x720, so values map straight through.
--
-- For subs that carry their own ASS styling (e.g. .ass files), mpv ignores
-- most sub-* properties and renders per-line styles we can't see from here;
-- the overlay will look like mpv's default-text render in that case rather
-- than a perfect match. Acceptable — most French content we mine is .srt.
local function build_sub_style()
    local font     = mp.get_property("sub-font", "sans-serif")
    local size     = mp.get_property_number("sub-font-size", 55)
    local bord     = mp.get_property_number("sub-border-size", 3)
    local shad     = mp.get_property_number("sub-shadow-offset", 0)
    local bold     = mp.get_property_bool("sub-bold", false)
    local italic   = mp.get_property_bool("sub-italic", false)
    local color1   = ass_color(mp.get_property("sub-color"),         "&HFFFFFF&")
    local color3   = ass_color(mp.get_property("sub-border-color"),  "&H000000&")
    local color4   = ass_color(mp.get_property("sub-shadow-color"),  "&H000000&")
    local margin_y = mp.get_property_number("sub-margin-y", 22)
    local margin_x = mp.get_property_number("sub-margin-x", 25)
    local align_x  = mp.get_property("sub-align-x", "center")
    local align_y  = mp.get_property("sub-align-y", "bottom")

    local x
    if align_x == "left" then x = margin_x
    elseif align_x == "right" then x = ASS_RES_X - margin_x
    else x = ASS_RES_X / 2 end

    local y
    if align_y == "top" then y = margin_y
    elseif align_y == "center" then y = ASS_RES_Y / 2
    else y = ASS_RES_Y - margin_y end

    local prefix = string.format(
        "\\an%d\\pos(%d,%d)\\fn%s\\fs%d\\bord%s\\shad%s\\1c%s\\3c%s\\4c%s\\b%d\\i%d",
        ass_alignment(align_x, align_y), x, y, font, math.floor(size + 0.5),
        tostring(bord), tostring(shad), color1, color3, color4,
        bold and 1 or 0, italic and 1 or 0
    )
    return {
        prefix       = prefix,
        base_color   = color1,
        base_bold    = bold and 1 or 0,
        base_italic  = italic,  -- user's force-italic pref; per-line italic comes from the sub itself
    }
end

-- Walk sub-text-ass and split it into runs of plain text, each carrying the
-- italic state in effect at that point. Two responsibilities:
--   1. Track \i1/\i0/\rXxx toggles inside override blocks so we know which
--      runs are italic. (\r resets to default style — we assume non-italic;
--      we don't have access to other style definitions from the source file.)
--   2. Resolve ASS escape sequences outside override blocks into plain text:
--      \N and \n → real newline, \h → space, \{ and \} → literal braces,
--      unknown \X → just X (drop the backslash). This is critical: if we
--      leave \N as raw "\" + "N", the N glues onto the next word during
--      tokenization (donné\Nun → word "Nun"), and the bare backslash
--      collides with the highlight override block's "{" once it reaches
--      ass_escape (libass parses "\\{" as literal "\" + escaped "{",
--      breaking the override).
local function parse_sub_ass(s)
    local runs = {}
    local italic = false
    local current = {}

    local function flush()
        if #current > 0 then
            runs[#runs + 1] = { text = table.concat(current), italic = italic }
            current = {}
        end
    end

    local pos = 1
    while pos <= #s do
        local c = s:sub(pos, pos)
        if c == "{" then
            local close = s:find("}", pos, true)
            if not close then break end
            local block = s:sub(pos + 1, close - 1)
            local i = 1
            while i <= #block do
                local three = block:sub(i, i + 2)
                local two = block:sub(i, i + 1)
                if three == "\\i0" then flush(); italic = false; i = i + 3
                elseif three == "\\i1" then flush(); italic = true; i = i + 3
                elseif two == "\\r" then flush(); italic = false; i = i + 2
                else i = i + 1 end
            end
            pos = close + 1
        elseif c == "\\" and pos < #s then
            local nxt = s:sub(pos + 1, pos + 1)
            if nxt == "N" or nxt == "n" then
                current[#current + 1] = "\n"
            elseif nxt == "h" then
                current[#current + 1] = " "
            else
                current[#current + 1] = nxt  -- \{, \}, or unknown \X
            end
            pos = pos + 2
        else
            current[#current + 1] = c
            pos = pos + 1
        end
    end
    flush()
    return runs
end

-- ASS treats {, }, and \ as control chars; the sub line and definitions go in
-- as raw user text, so escape them to prevent accidental tag injection.
local function ass_escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("{", "\\{")
    s = s:gsub("}", "\\}")
    return s
end

-- h/l mirror LEFT/RIGHT during cycle mode. They normally seek -5/+5 sec
-- (see mpv module bindings); add_forced_key_binding shadows that while
-- cycle is active and remove_key_binding on cycle_end restores the seek.
local CYCLE_KEYS = {
    { key = "RIGHT", name = "frmine-cycle-next" },
    { key = "LEFT",  name = "frmine-cycle-prev" },
    { key = "l",     name = "frmine-cycle-next-l" },
    { key = "h",     name = "frmine-cycle-prev-h" },
    { key = "ENTER", name = "frmine-cycle-select" },
    { key = "ESC",   name = "frmine-cycle-cancel" },
}

local function cycle_sub_ass()
    local style = cycle_state.sub_style
    local out = { "{" .. style.prefix .. "}" }
    -- Track italic state so we only emit \iN when it changes. The prefix
    -- already set base_italic, so start there.
    local cur_italic = style.base_italic
    for _, sp in ipairs(cycle_state.spans) do
        if sp.italic ~= cur_italic then
            out[#out + 1] = "{\\i" .. (sp.italic and 1 or 0) .. "}"
            cur_italic = sp.italic
        end
        local esc = ass_escape(sp.text):gsub("\n", "\\N")
        if sp.kind == "word" and sp.word_idx == cycle_state.idx then
            -- Highlighted word: yellow + bold. Reset back to the sub's base
            -- color and bold state so the rest of the line stays seamless.
            -- (Italic is left alone by the highlight tags, so cur_italic
            -- doesn't change here.)
            out[#out + 1] = "{\\1c&H00FFFF&\\b1}" .. esc
                .. "{\\1c" .. style.base_color .. "\\b" .. style.base_bold .. "}"
        else
            out[#out + 1] = esc
        end
    end
    return table.concat(out)
end

local function cycle_info_ass(body, hint)
    local body_ass = ass_escape(body):gsub("\n", "\\N")
    local hint_ass = ass_escape(hint)
    return "{" .. INFO_STYLE .. "}" .. body_ass .. "\\N\\N{" .. HINT_STYLE .. "}" .. hint_ass
end

-- Live-fetch the highlighted word's dictionary entry on every step, render
-- sub + definition together, and speak the lemma. Lookup is local SQLite
-- (<10ms) so this stays snappy even when the user arrows quickly.
local function cycle_render()
    if not cycle_state then return end
    local current = cycle_state.words[cycle_state.idx]
    local data = http_get_json(FRDICT_URL .. "/lookup?word=" .. urlencode(current))
    local body
    if not data then
        body = "lookup failed (is frdict running?)"
    else
        local match = pick_match(data.matches)
        if not match then
            body = "(no dictionary match)"
        else
            body = format_lookup(match, #data.matches - 1)
            speak(match.lemma)
        end
    end
    local hint = "h/l or ←/→ next  •  Enter mine  •  Esc cancel"
    if sub_overlay then
        sub_overlay.data = cycle_sub_ass()
        sub_overlay:update()
    end
    if info_overlay then
        info_overlay.data = cycle_info_ass(body, hint)
        info_overlay:update()
    end
end

local function cycle_end()
    for _, b in ipairs(CYCLE_KEYS) do
        mp.remove_key_binding(b.name)
    end
    if sub_overlay then sub_overlay:remove(); sub_overlay = nil end
    if info_overlay then info_overlay:remove(); info_overlay = nil end
    if saved_sub_visibility ~= nil then
        mp.set_property_bool("sub-visibility", saved_sub_visibility)
        saved_sub_visibility = nil
    end
    if saved_osd_use_margins ~= nil then
        mp.set_property_bool("osd-use-margins", saved_osd_use_margins)
        saved_osd_use_margins = nil
    end
    cycle_state = nil
end

local function cycle_next()
    if not cycle_state then return end
    cycle_state.idx = (cycle_state.idx % #cycle_state.words) + 1
    cycle_render()
end

local function cycle_prev()
    if not cycle_state then return end
    cycle_state.idx = ((cycle_state.idx - 2) % #cycle_state.words) + 1
    cycle_render()
end

local function cycle_select()
    if not cycle_state then return end
    local word = cycle_state.words[cycle_state.idx]
    cycle_end()
    mine_and_enrich(word)
end

local function cycle_cancel()
    cycle_end()
    mp.osd_message("Cancelled", 1)
end

local CYCLE_HANDLERS = {
    ["frmine-cycle-next"]   = cycle_next,
    ["frmine-cycle-prev"]   = cycle_prev,
    ["frmine-cycle-next-l"] = cycle_next,
    ["frmine-cycle-prev-h"] = cycle_prev,
    ["frmine-cycle-select"] = cycle_select,
    ["frmine-cycle-cancel"] = cycle_cancel,
}

local function start_cycle()
    if cycle_state then return end
    local sub = mp.get_property("sub-text") or ""
    if trim(sub) == "" then
        mp.osd_message("frmine: no subtitle on screen", 2)
        return
    end
    -- Walk the sub once, building two parallel lists:
    --   words[]  - mineable tokens (drives cycling + /lookup)
    --   spans[]  - full coverage of the original sub (for verbatim render).
    -- Single ASCII letters (French elision residue: l', d', s', n', t', m',
    -- c', j') stay visible as literal spans but aren't mineable.
    --
    -- Italic is per-line state from the *sub itself* (e.g. {\i1}…{\i0} in
    -- ASS, or <i>…</i> in srt which mpv has converted to ASS). sub-text
    -- strips formatting, so we read sub-text-ass and parse the toggles into
    -- runs; if sub-text-ass is empty (rare), fall back to a single non-italic
    -- run from sub-text.
    local sub_ass = mp.get_property("sub-text-ass") or ""
    local runs = parse_sub_ass(sub_ass)
    if #runs == 0 then runs = { { text = sub, italic = false } } end
    local words = {}
    local spans = {}
    for _, run in ipairs(runs) do
        local text = run.text
        local i = 1
        while i <= #text do
            local ws, we = text:find("[^%s%p]+", i)
            if ws == i then
                local tok = text:sub(ws, we)
                if tok:match("^[%a]$") then
                    spans[#spans + 1] = { kind = "lit", text = tok, italic = run.italic }
                else
                    words[#words + 1] = tok
                    spans[#spans + 1] = { kind = "word", text = tok, word_idx = #words, italic = run.italic }
                end
                i = we + 1
            else
                spans[#spans + 1] = { kind = "lit", text = text:sub(i, i), italic = run.italic }
                i = i + 1
            end
        end
    end
    if #words == 0 then
        mp.osd_message("frmine: no mineable words in current sub", 2)
        return
    end
    cycle_state = { words = words, spans = spans, idx = 1, sub_style = build_sub_style() }
    mp.set_property_bool("pause", true)
    -- Hide the real sub so our overlay is the only sub-position text on screen.
    -- Saved here, restored in cycle_end so the user's preference survives a
    -- scrub session.
    saved_sub_visibility = mp.get_property_bool("sub-visibility")
    mp.set_property_bool("sub-visibility", false)
    -- mpv's OSD by default renders inside the video frame (osd-use-margins=no)
    -- while subs render in the full screen including letterbox bars. That
    -- offset makes the overlay sit slightly higher than where the real sub
    -- was. Toggling osd-use-margins=yes makes the OSD canvas screen-relative,
    -- so our \pos(x, ASS_RES_Y - sub-margin-y) lines up with the sub.
    saved_osd_use_margins = mp.get_property_bool("osd-use-margins")
    mp.set_property_bool("osd-use-margins", true)
    sub_overlay = mp.create_osd_overlay("ass-events")
    sub_overlay.res_x = ASS_RES_X
    sub_overlay.res_y = ASS_RES_Y
    info_overlay = mp.create_osd_overlay("ass-events")
    info_overlay.res_x = ASS_RES_X
    info_overlay.res_y = ASS_RES_Y
    for _, b in ipairs(CYCLE_KEYS) do
        mp.add_forced_key_binding(b.key, b.name, CYCLE_HANDLERS[b.name])
    end
    cycle_render()
end

mp.register_script_message("cycle", start_cycle)
