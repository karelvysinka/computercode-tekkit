-- Shared state for the ComputerCode agent: API messages + UI transcript + status.
-- Listeners (UI, monitor mirror) subscribe; mutators fire onChange.

local M = {}

local function newState()
    return {
        messages = {},      -- API-facing message list (system, user, assistant, tool)
        transcript = {},    -- UI-facing entries: { kind, ... }
        status = "idle",    -- "idle" | "thinking" | "tool:<name>"
        model = nil,
        sessionId = nil,
        dirty = false,      -- true when there is unsaved content (session autosave)
        _listeners = {},
    }
end

local Mt = {}
Mt.__index = Mt

function Mt:onChange(fn)
    self._listeners[#self._listeners + 1] = fn
    return fn
end

function Mt:_fire()
    for _, fn in ipairs(self._listeners) do
        local ok, err = pcall(fn, self)
        if not ok then
            -- Swallow listener errors so one broken listener doesn't kill the agent.
            io.stderr:write("[state listener] " .. tostring(err) .. "\n")
        end
    end
end

function Mt:setStatus(s)
    self.status = s or "idle"
    self:_fire()
end

function Mt:pushApi(msg)
    -- API-only message; not shown in transcript directly.
    self.messages[#self.messages + 1] = msg
    self.dirty = true
end

function Mt:pushEntry(entry)
    -- UI transcript entry: { kind="user"|"assistant"|"tool_call"|"tool_result"|"thinking"|"error", ... }
    entry.id = #self.transcript + 1
    entry.t = os.epoch and os.epoch("utc") or 0
    self.transcript[#self.transcript + 1] = entry
    self.dirty = true
    self:_fire()
end

function Mt:pushUser(text)
    self:pushApi({ role = "user", content = text })
    self:pushEntry({ kind = "user", text = text })
end

function Mt:pushAssistantText(text)
    if type(text) == "string" and text ~= "" then
        self:pushEntry({ kind = "assistant", text = text })
    end
end

function Mt:pushThinking(text)
    if type(text) == "string" and text ~= "" then
        self:pushEntry({ kind = "thinking", text = text, expanded = false })
    end
end

function Mt:pushToolCall(callId, name, args)
    self:pushEntry({ kind = "tool_call", callId = callId, name = name, args = args })
end

-- Transcript entries are persisted to disk and only ever shown as short
-- previews, so cap long strings here to keep session files small (CC
-- computers have a disk quota).
local TRIM_AT = 300
local function trimForTranscript(v)
    if type(v) == "string" then
        if #v > TRIM_AT then return v:sub(1, TRIM_AT) .. "...[trimmed]" end
        return v
    end
    if type(v) == "table" then
        local out = {}
        for k, val in pairs(v) do out[k] = trimForTranscript(val) end
        return out
    end
    return v
end

function Mt:pushToolResult(callId, name, ok, result)
    self:pushEntry({
        kind = "tool_result", callId = callId, name = name,
        ok = ok, result = trimForTranscript(result),
    })
end

function Mt:pushError(text)
    self:pushEntry({ kind = "error", text = text })
end

function Mt:clear()
    self.messages = {}
    self.transcript = {}
    self.status = "idle"
    self.dirty = true
    self:_fire()
end

function M.new()
    return setmetatable(newState(), Mt)
end

return M
