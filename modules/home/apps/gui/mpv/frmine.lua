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

-- Speak a French word via espeak-ng. Async so the audio doesn't block the
-- OSD render. Robotic but phonemically correct — the IPA tells you what's
-- supposed to come out, this lets you hear it.
--
-- Cancels any in-flight pronunciation before starting a new one so fast
-- cycling through words doesn't pile up overlapping playback.
local active_speak = nil
local function speak(word)
    if active_speak then
        mp.abort_async_command(active_speak)
        active_speak = nil
    end
    active_speak = mp.command_native_async({
        name = "subprocess",
        args = { "espeak-ng", "-v", "fr-fr", "-s", "140", word },
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

local cycle_state = nil  -- { words, idx } when active, nil otherwise

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

local function cycle_sub_line()
    local parts = {}
    for i, w in ipairs(cycle_state.words) do
        if i == cycle_state.idx then
            parts[i] = "[" .. w .. "]"
        else
            parts[i] = w
        end
    end
    return table.concat(parts, " ")
end

-- Live-fetch the highlighted word's dictionary entry on every step, render
-- sub + definition together, and speak the lemma. Lookup is local SQLite
-- (<10ms) so this stays snappy even when the user arrows quickly.
local function cycle_render()
    if not cycle_state then return end
    local sub_line = cycle_sub_line()
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
    mp.osd_message(sub_line .. "\n\n" .. body .. "\n\n" .. hint, 99999)
end

local function cycle_end()
    for _, b in ipairs(CYCLE_KEYS) do
        mp.remove_key_binding(b.name)
    end
    cycle_state = nil
    mp.osd_message("", 0)
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
    local words = {}
    -- Tokenize on whitespace + punctuation. Skip ASCII single letters
    -- (residue of French elision: l', d', s', n', etc).
    for w in sub:gmatch("[^%s%p]+") do
        if not w:match("^[%a]$") then
            table.insert(words, w)
        end
    end
    if #words == 0 then
        mp.osd_message("frmine: no mineable words in current sub", 2)
        return
    end
    cycle_state = { words = words, idx = 1 }
    mp.set_property_bool("pause", true)
    for _, b in ipairs(CYCLE_KEYS) do
        mp.add_forced_key_binding(b.key, b.name, CYCLE_HANDLERS[b.name])
    end
    cycle_render()
end

mp.register_script_message("cycle", start_cycle)
