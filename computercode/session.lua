local json = require("computercode.json")
-- Session persistence: every chat is saved as one JSON file under
-- .computercode/sessions/ (OpenCode-style), so context survives reboots.
-- A small index.json caches {title, updated, entries} per session so listing
-- doesn't have to parse every session file.

local M = {}

local SESS_DIR   = ".computercode/sessions"
local INDEX_PATH = SESS_DIR .. "/index.json"

-- Save at most every SAVE_INTERVAL_MS mid-turn; always save when idle.
local SAVE_INTERVAL_MS = 2000

-- Keep at most this many sessions on disk.  CC computers have a ~1MB quota
-- and session files are the only thing here that grows forever; a full disk
-- kills autosave entirely (and the atomic .tmp swap needs headroom too).
local MAX_SESSIONS = 12

-- ----------------------------------------------------------------------------
-- JSON file helpers
-- ----------------------------------------------------------------------------

local function readJSON(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local raw = f.readAll()
    f.close()
    local ok, data = pcall(json.decode, raw, { parse_null = true })
    if ok and type(data) == "table" then return data end
    return nil
end

-- Atomic-ish write: the payload goes to a .tmp file first and only replaces
-- the real file once it's fully on disk.  Opening the target directly in "w"
-- truncates it immediately, so a reboot or a full disk mid-write would
-- destroy the previous save (this exact failure ate a real session once).
local function writeJSON(path, value)
    local ok, encoded = pcall(json.encode, value, { unicode_strings = true })
    if not ok then return false, tostring(encoded) end
    local tmp = path .. ".tmp"
    local f = fs.open(tmp, "w")
    if not f then return false, "cannot open " .. tmp end
    local okW, wErr = pcall(f.write, encoded)
    pcall(f.close)
    if not okW then
        pcall(fs.delete, tmp)
        return false, "write failed (disk full?): " .. tostring(wErr)
    end
    if fs.getSize(tmp) < #encoded then
        pcall(fs.delete, tmp)
        return false, "short write (disk full?)"
    end
    if fs.exists(path) then fs.delete(path) end
    fs.move(tmp, path)
    return true
end

local function ensureDir()
    if not fs.exists(SESS_DIR) then fs.makeDir(SESS_DIR) end
end

local function sessionPath(id) return SESS_DIR .. "/" .. id .. ".json" end

local function loadIndex() return readJSON(INDEX_PATH) or {} end
local function saveIndex(ix) ensureDir(); writeJSON(INDEX_PATH, ix) end

-- ----------------------------------------------------------------------------
-- Session identity + metadata
-- ----------------------------------------------------------------------------

function M.newId()
    return "s" .. tostring(os.epoch("utc"))
end

local function titleFromTranscript(transcript)
    for _, e in ipairs(transcript or {}) do
        -- Slash commands are echoed as user entries; they make terrible titles.
        if e.kind == "user" and type(e.text) == "string" and e.text ~= ""
            and e.text:sub(1, 1) ~= "/" then
            local t = e.text:gsub("%s+", " ")
            if #t > 36 then t = t:sub(1, 33) .. "..." end
            return t
        end
    end
    return "(empty session)"
end

-- ----------------------------------------------------------------------------
-- Save / load / list
-- ----------------------------------------------------------------------------

-- Delete the oldest sessions beyond MAX_SESSIONS (never the one being kept).
-- Mutates ix; caller saves the index afterwards.
local function pruneOldSessions(ix, keepId)
    local order = {}
    for id, meta in pairs(ix) do
        order[#order + 1] = { id = id, updated = meta.updated or 0 }
    end
    table.sort(order, function(a, b) return a.updated > b.updated end)
    for i = MAX_SESSIONS + 1, #order do
        local id = order[i].id
        if id ~= keepId then
            pcall(fs.delete, sessionPath(id))
            pcall(fs.delete, sessionPath(id) .. ".tmp")
            ix[id] = nil
        end
    end
end

function M.save(state)
    if not state.sessionId then return false, "no session id" end
    ensureDir()
    local data = {
        id         = state.sessionId,
        model      = state.model,
        title      = titleFromTranscript(state.transcript),
        updated    = os.epoch("utc"),
        messages   = state.messages,
        transcript = state.transcript,
    }
    local ok, err = writeJSON(sessionPath(state.sessionId), data)
    if ok then
        local ix = loadIndex()
        ix[state.sessionId] = {
            title = data.title, updated = data.updated, entries = #state.transcript,
        }
        pruneOldSessions(ix, state.sessionId)
        saveIndex(ix)
    end
    return ok, err
end

-- If the computer restarted mid-turn, the saved message list may end with an
-- assistant tool_calls message whose tool results never arrived.  The API
-- rejects that, so patch in synthetic error results for any dangling call ids.
local function repairMessages(messages)
    local pending = {}   -- call id -> tool name
    for _, m in ipairs(messages) do
        if m.role == "assistant" and type(m.tool_calls) == "table" then
            for _, c in ipairs(m.tool_calls) do
                if type(c) == "table" and c.id then
                    pending[c.id] = (type(c["function"]) == "table" and c["function"].name) or "?"
                end
            end
        elseif m.role == "tool" and m.tool_call_id then
            pending[m.tool_call_id] = nil
        end
    end
    for id, name in pairs(pending) do
        messages[#messages + 1] = {
            role = "tool", tool_call_id = id, name = name,
            content = "ERROR: interrupted - the computer restarted before this tool ran.",
        }
    end
end

---@return table|nil data, string? err
function M.load(state, id)
    local data = readJSON(sessionPath(id))
    if not data or type(data.messages) ~= "table" then
        return nil, "cannot load session: " .. tostring(id)
    end
    repairMessages(data.messages)
    state.messages   = data.messages
    state.transcript = type(data.transcript) == "table" and data.transcript or {}
    state.sessionId  = id
    state.status     = "idle"
    state.dirty      = false
    state:_fire()
    return data
end

-- Point state at a brand-new empty session (does not touch old session files).
function M.start(state)
    state.messages   = {}
    state.transcript = {}
    state.sessionId  = M.newId()
    state.status     = "idle"
    state.dirty      = false
    return state.sessionId
end

-- Returns an array of {id, title, updated, entries}, newest first.
function M.list()
    local ix = loadIndex()
    -- Pick up any session files the index doesn't know about (e.g. copied in).
    if fs.exists(SESS_DIR) then
        for _, name in ipairs(fs.list(SESS_DIR)) do
            -- A crash between write and move leaves a .tmp behind; it's dead
            -- weight against the disk quota, so sweep it.
            if name:match("%.tmp$") then
                pcall(fs.delete, SESS_DIR .. "/" .. name)
            end
            local id = name:match("^(s%d+)%.json$")
            if id and not ix[id] then
                local data = readJSON(sessionPath(id))
                if data then
                    ix[id] = {
                        title = data.title or "(untitled)",
                        updated = data.updated or 0,
                        entries = type(data.transcript) == "table" and #data.transcript or 0,
                    }
                end
            end
        end
    end
    local out = {}
    for id, meta in pairs(ix) do
        local p = sessionPath(id)
        if fs.exists(p) then
            out[#out + 1] = {
                id = id,
                title = meta.title or "(untitled)",
                updated = meta.updated or 0,
                entries = meta.entries or 0,
                -- Empty file = a save died mid-write; it can never be resumed.
                corrupt = fs.getSize(p) == 0,
            }
        end
    end
    table.sort(out, function(a, b) return a.updated > b.updated end)
    return out
end

function M.latestId()
    local all = M.list()
    return all[1] and all[1].id or nil
end

function M.delete(id)
    if fs.exists(sessionPath(id)) then fs.delete(sessionPath(id)) end
    local ix = loadIndex()
    if ix[id] then
        ix[id] = nil
        saveIndex(ix)
    end
end

-- ----------------------------------------------------------------------------
-- Autosave: subscribe to state changes, persist whenever there's new content.
-- Mid-turn saves are throttled; the idle transition at end of turn always
-- flushes, so a crash loses at most ~2s of tool chatter.
-- ----------------------------------------------------------------------------

function M.attach(state)
    local lastSave = 0
    local saving = false   -- re-entrancy guard: pushError below re-fires listeners
    local warned = false   -- only warn once per failure streak
    state:onChange(function()
        if saving or not state.dirty then return end
        local now = os.epoch("utc")
        if state.status ~= "idle" and (now - lastSave) < SAVE_INTERVAL_MS then return end
        state.dirty = false
        lastSave = now
        saving = true
        local okCall, okSave, saveErr = pcall(M.save, state)
        local failMsg
        if not okCall then
            failMsg = tostring(okSave)
        elseif okSave == false then
            failMsg = tostring(saveErr)
        end
        if failMsg then
            if not warned then
                warned = true
                state:pushError("session autosave failing: " .. failMsg ..
                    "  (chat still works, but history may not survive a reboot - try freeing disk space)")
            end
        else
            warned = false
        end
        saving = false
    end)
end

return M
