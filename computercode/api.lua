local json = require("computercode.json")
-- OpenRouter chat completions client.

local M = {}

local URL = "https://openrouter.ai/api/v1/chat/completions"

local function jsonEncode(v)
    return json.encode(v, { unicode_strings = true })
end

local function jsonDecode(s)
    return json.decode(s, { parse_null = true, parse_empty_array = true })
end

---@param opts { apiKey:string, model:string, messages:table, tools?:table, reasoning?:table, onTick?:fun(), onRetry?:fun(), timeoutSec?:number }
---@return table|nil message, string? errorMessage, table? usage
function M.chat(opts)
    assert(opts.apiKey, "api: apiKey required")
    assert(opts.model,  "api: model required")
    assert(opts.messages, "api: messages required")

    local body = {
        model = opts.model,
        messages = opts.messages,
    }
    if opts.tools and #opts.tools > 0 then
        body.tools = opts.tools
        body.tool_choice = opts.tool_choice or "auto"
    end
    if opts.reasoning then
        body.reasoning = opts.reasoning
    end
    if opts.temperature then body.temperature = opts.temperature end

    local headers = {
        ["Authorization"] = "Bearer " .. opts.apiKey,
        ["Content-Type"]  = "application/json",
        ["HTTP-Referer"]  = "https://github.com/karelvysinka/computercode-tekkit",
        ["X-Title"]       = "ComputerCode",
    }

    local payload = jsonEncode(body)

    local function once()
        local resp, err, errorResponse = http.post({
            url = URL,
            body = payload,
            headers = headers,
        })
        resp = resp or errorResponse
        if not resp then
            return nil, "http error: " .. tostring(err)
        end
        local raw = resp.readAll()
        local code = resp.getResponseCode and resp.getResponseCode() or 200
        resp.close()
        if code >= 400 then
            return nil, "openrouter " .. code .. ": " .. (raw or "")
        end
        local data = jsonDecode(raw)
        if not data then
            return nil, "could not parse response: " .. (raw or ""):sub(1, 300)
        end
        if data.error then
            local msg = type(data.error) == "table" and data.error.message or tostring(data.error)
            return nil, "openrouter: " .. tostring(msg)
        end
        if not data.choices or not data.choices[1] then
            return nil, "no choices in response"
        end
        return data.choices[1].message, nil, data.usage
    end

    -- Race the http call against a ticker that (a) animates UI spinners via
    -- opts.onTick, and (b) acts as a watchdog: CC's http.post has no
    -- response timeout, so a stalled provider would otherwise hang forever.
    -- http.post internally yields via os.pullEvent, so this schedules fine.
    -- Ctrl+T lands here as a Terminated error - treated as a user cancel,
    -- not a crash (the abandoned request finishes server-side and is ignored).
    local TIMEOUT_SEC = tonumber(opts.timeoutSec) or 180
    local function runWithTicks()
        local msg, err, usage
        local done = false
        local timedOut = false
        local okP, perr = pcall(parallel.waitForAny,
            function()
                msg, err, usage = once()
                done = true
            end,
            function()
                local t0 = os.epoch("utc")
                while not done do
                    if (os.epoch("utc") - t0) / 1000 >= TIMEOUT_SEC then
                        timedOut = true
                        return
                    end
                    if opts.onTick then pcall(opts.onTick) end
                    sleep(0.15)
                end
            end
        )
        if not okP then
            if tostring(perr):find("Terminated") then return nil, "cancelled" end
            return nil, "harness: " .. tostring(perr)
        end
        if timedOut and not done then
            return nil, "timeout: no response after " .. TIMEOUT_SEC ..
                "s - the model/provider may be overloaded. The request was abandoned; try again or /model to switch."
        end
        return msg, err, usage
    end

    local msg, err, usage = runWithTicks()
    if msg then return msg, nil, usage end
    -- Single retry on quick transient failures.  Never retry a user cancel,
    -- and never a watchdog timeout (that would silently double a long wait).
    if err and err:match("^http error") then
        if opts.onRetry then pcall(opts.onRetry) end
        sleep(0.5)
        msg, err, usage = runWithTicks()
        if msg then return msg, nil, usage end
    end
    return nil, err
end

return M
