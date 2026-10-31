-- Curated list of OpenRouter models that work well with ComputerCode.
-- The agent calls tools, so every model here supports OpenAI-compatible tool
-- calling.  ":free" tags hit OpenRouter's free tier (no charge, but heavily
-- rate-limited).
--
-- This list is just suggestions - the user can always type any OpenRouter
-- model id manually (e.g., "anthropic/claude-opus-4.1").

local M = {}

M.DEFAULT = "anthropic/claude-haiku-4.5"

M.presets = {
    { id = "anthropic/claude-haiku-4.5",            label = "Claude Haiku 4.5",            note = "fast + cheap, recommended default" },
    { id = "anthropic/claude-sonnet-4.5",           label = "Claude Sonnet 4.5",           note = "smarter, more expensive" },
    { id = "openai/gpt-4o-mini",                    label = "GPT-4o Mini",                 note = "cheap OpenAI" },
    { id = "openai/gpt-4o",                         label = "GPT-4o",                      note = "OpenAI flagship" },
    { id = "google/gemini-3-flash-preview",         label = "Gemini 3 Flash (preview)",    note = "Google, latest" },
    { id = "google/gemini-2.5-pro",                 label = "Gemini 2.5 Pro",              note = "Google, big context" },
    { id = "x-ai/grok-4-fast",                      label = "Grok 4 Fast",                 note = "xAI" },
    { id = "moonshotai/kimi-k2:free",               label = "Kimi K2 (free)",              note = "Moonshot, FREE tier" },
    { id = "deepseek/deepseek-chat-v3.1:free",      label = "DeepSeek Chat v3.1 (free)",   note = "FREE tier - good baseline" },
    { id = "qwen/qwen3-235b-a22b:free",             label = "Qwen3 235B (free)",           note = "Alibaba, FREE tier" },
}

---@param ref string|number  preset index OR model id
---@return string|nil id, string? errorMessage
function M.resolve(ref)
    if type(ref) == "number" then
        local p = M.presets[ref]
        if not p then return nil, "no preset #" .. ref end
        return p.id
    end
    if type(ref) ~= "string" then return nil, "expected number or string" end
    local n = tonumber(ref)
    if n and n >= 1 and n <= #M.presets then
        return M.presets[n].id
    end
    -- Treat as raw model id; sanity check that it has the "vendor/name" shape.
    if not ref:find("/", 1, true) then
        return nil, "model id should look like 'vendor/name' (got '" .. ref .. "')"
    end
    return ref
end

function M.menuLines(currentId)
    local lines = { "Pick a model by number, or type a custom id with `/model vendor/name`:", "" }
    for i, p in ipairs(M.presets) do
        local marker = (currentId and currentId == p.id) and " *" or "  "
        lines[#lines + 1] = string.format("%s%2d. %-32s - %s", marker, i, p.label, p.note)
        lines[#lines + 1] = string.format("       %s", p.id)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Type `/model <number>` (e.g. /model 3) or `/model <vendor/name>`."
    return lines
end

return M
