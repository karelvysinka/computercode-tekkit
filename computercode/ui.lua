-- PixelUI chat window for the ComputerCode agent.

local pixelui = require("pixelui")
local tools   = require("computercode.tools")

local M = {}

-- ----------------------------------------------------------------------------
-- Text helpers
-- ----------------------------------------------------------------------------

local function splitLines(s)
    local out = {}
    if s == nil or s == "" then out[1] = ""; return out end
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end

local function wrap(text, width, fg, prefix, indent)
    local lines = {}
    prefix = prefix or ""
    indent = indent or string.rep(" ", #prefix)
    if width < 4 then width = 4 end
    for _, para in ipairs(splitLines(text)) do
        if para == "" then
            lines[#lines + 1] = { text = prefix, fg = fg }
            prefix = indent
        else
            local rem = para
            while #rem > 0 do
                local maxW = width - #prefix
                if maxW < 1 then maxW = 1 end
                local chunk
                if #rem <= maxW then
                    chunk = rem
                    rem = ""
                else
                    chunk = rem:sub(1, maxW)
                    local sp = chunk:match(".*()%s")
                    if sp and sp > math.floor(maxW * 0.4) then
                        chunk = rem:sub(1, sp - 1)
                        rem = rem:sub(sp + 1)
                    else
                        rem = rem:sub(maxW + 1)
                    end
                end
                lines[#lines + 1] = { text = prefix .. chunk, fg = fg }
                prefix = indent
            end
        end
    end
    return lines
end

local function summarizeResultPreview(result)
    if result == nil then return "" end
    if type(result) == "string" then
        local s = result:gsub("\n", " ")
        if #s > 60 then s = s:sub(1, 57) .. "..." end
        return s
    end
    if type(result) == "table" then
        if result.path and result.bytes_written then
            return result.path .. "  (" .. result.bytes_written .. " B)"
        end
        if result.path and result.replacements then
            return result.path .. "  (" .. result.replacements .. " edit" ..
                   (result.replacements == 1 and "" or "s") .. ")"
        end
        if result.path and result.content then
            return result.path .. "  (" .. (result.size or #result.content) .. " B)"
        end
        if result.entries then
            return result.path .. "  (" .. #result.entries .. " entries)"
        end
        if result.values then
            local s = table.concat(result.values, ", ")
            if result.output and result.output ~= "" then
                local out = result.output:gsub("\n", " | ")
                s = (s ~= "" and (s .. "  ") or "") .. out
            end
            if s == "" then s = "ok (no output)" end
            if #s > 60 then s = s:sub(1, 57) .. "..." end
            return s
        end
        if result.matches then
            return #result.matches .. " match" .. (#result.matches == 1 and "" or "es") ..
                   (result.truncated and " (truncated)" or "")
        end
        if result.files then
            return #result.files .. " file" .. (#result.files == 1 and "" or "s") ..
                   (result.truncated and " (truncated)" or "")
        end
        if result.command then
            local out = (result.output or ""):gsub("\n", " | ")
            if #out > 60 then out = out:sub(1, 57) .. "..." end
            return result.command .. " -> " .. (result.ok and "ok" or "fail") ..
                   (out ~= "" and "  " .. out or "")
        end
        local n = 0; for _ in pairs(result) do n = n + 1 end
        return "{" .. n .. " keys}"
    end
    return tostring(result)
end

-- ----------------------------------------------------------------------------
-- Transcript -> flat lines
-- ----------------------------------------------------------------------------

-- Compact transcript: no role banner lines, no filler blanks.  Users get a
-- cyan "> " prefix, the assistant is plain white, tool call+result are two
-- adjacent one-liners.  A single blank line separates conversation groups.
local function renderTranscript(state, width)
    local lines = {}
    local function header(prefix, label, color)
        lines[#lines + 1] = { text = prefix .. label, fg = color }
    end
    -- Blank separator, but never doubled and never as the very first line.
    local function blank()
        if #lines > 0 and lines[#lines].text ~= "" then
            lines[#lines + 1] = { text = "", fg = colors.white }
        end
    end
    local function append(list)
        for _, ln in ipairs(list) do lines[#lines + 1] = ln end
    end

    for _, e in ipairs(state.transcript) do
        if e.kind == "user" then
            blank()
            append(wrap(e.text, width, colors.cyan, "> ", "  "))
        elseif e.kind == "assistant" then
            blank()
            append(wrap(e.text, width, colors.white, ""))
        elseif e.kind == "tool_call" then
            local summary = "-> " .. e.name .. "(" .. tools.summarizeArgs(e.args) .. ")"
            append(wrap(summary, width, colors.yellow, "", "   "))
        elseif e.kind == "tool_result" then
            local prefix = e.ok and "<- " or "<- ERROR: "
            local body
            if e.ok then
                body = summarizeResultPreview(e.result)
            else
                body = tostring(e.result)
            end
            append(wrap(prefix .. body, width, e.ok and colors.lightGray or colors.red, "", "   "))
        elseif e.kind == "thinking" then
            local wrapped = wrap(e.text, width, colors.gray, "~ ", "  ")
            local MAX_LINES = 2
            for i = 1, math.min(MAX_LINES, #wrapped) do
                lines[#lines + 1] = wrapped[i]
            end
            if #wrapped > MAX_LINES then
                lines[#lines + 1] = {
                    text = "  ...(+" .. (#wrapped - MAX_LINES) .. " thinking lines)",
                    fg = colors.gray,
                }
            end
        elseif e.kind == "plan" then
            blank()
            local p = e.plan or {}
            header("", "* PLAN: " .. (p.title or ""), colors.magenta)
            if p.summary and p.summary ~= "" then
                append(wrap(p.summary, width, colors.white, "  "))
            end
            for i, s in ipairs(p.steps or {}) do
                append(wrap(tostring(s), width, colors.white, "  " .. i .. ". "))
            end
            for _, f in ipairs(p.files_to_create or {}) do
                append(wrap("+ " .. tostring(f), width, colors.lime, "  "))
            end
            for _, f in ipairs(p.files_to_edit or {}) do
                append(wrap("~ " .. tostring(f), width, colors.orange, "  "))
            end
            header("", "  reply `approve` or give feedback", colors.lightGray)
        elseif e.kind == "question" then
            blank()
            header("", "? QUESTIONS", colors.yellow)
            for qi, q in ipairs(e.questions or {}) do
                append(wrap(qi .. ". " .. q.question, width, colors.white, "  "))
                local optCount = #(q.options or {})
                for oi, opt in ipairs(q.options or {}) do
                    local letter = string.char(96 + oi)  -- 'a', 'b', 'c', 'd'
                    local line = letter .. ") " .. opt.label
                    if opt.description and opt.description ~= "" then
                        line = line .. " - " .. opt.description
                    end
                    append(wrap(line, width, colors.white, "     "))
                end
                append(wrap(string.char(96 + optCount + 1) .. ") talk about this instead",
                    width, colors.lightGray, "     "))
            end
            header("", "  reply e.g. `1a 2c` or free-form", colors.lightGray)
        elseif e.kind == "error" then
            append(wrap("ERROR: " .. tostring(e.text), width, colors.red, "", "  "))
        end
    end
    return lines
end

-- ----------------------------------------------------------------------------
-- UI construction
-- ----------------------------------------------------------------------------

---@param state any
---@param agent any
function M.new(state, agent)
    local app = pixelui.create({ background = colors.black })
    local W, H = app.window.getSize()

    -- Compact layout: 1-line header, 2-line input, everything else transcript.
    local headerH = 1
    local inputH = 2
    local trY = headerH + 1
    local trH = H - headerH - inputH
    local sendBtnW = 6

    -- Header
    local header = app:createLabel({
        x = 1, y = 1, width = W, height = headerH,
        text = " ComputerCode  -  " .. (state.model or "model?"),
        align = "left",
        bg = colors.blue, fg = colors.white,
    })
    app.root:addChild(header)

    local statusLabel = app:createLabel({
        x = math.floor(W / 2), y = 1, width = math.ceil(W / 2),
        height = headerH,
        text = "idle ",
        align = "right",
        bg = colors.blue, fg = colors.lightGray,
    })
    app.root:addChild(statusLabel)

    -- Transcript scroll state (lines from bottom; 0 = pinned to latest)
    local scrollLines = 0

    local transcript = app:createFreeDraw({
        x = 1, y = trY, width = W, height = trH,
        bg = colors.black,
        onDraw = function(self, ctx)
            ctx.fill(colors.black)
            local lines = renderTranscript(state, ctx.width)
            local total = #lines
            local h = ctx.height
            local maxScroll = math.max(0, total - h)
            if scrollLines > maxScroll then scrollLines = maxScroll end
            if scrollLines < 0 then scrollLines = 0 end
            local lastVisible = total - scrollLines
            local firstVisible = math.max(1, lastVisible - h + 1)
            local row = 1
            for i = firstVisible, lastVisible do
                local L = lines[i]
                if L then
                    local text = L.text
                    if #text > ctx.width then text = text:sub(1, ctx.width) end
                    ctx.write(1, row, text, L.fg or colors.white, colors.black)
                end
                row = row + 1
            end
            -- Scroll indicator
            if scrollLines > 0 then
                ctx.write(ctx.width, ctx.height,
                    "v", colors.yellow, colors.black)
            end
        end,
    })
    -- Mouse-scroll inside the transcript region.
    function transcript:handleEvent(event, a, b, c)
        if event == "mouse_scroll" then
            local dir, x, y = a, b, c
            if self:containsPoint(x, y) then
                scrollLines = math.max(0, scrollLines - dir)
                return true
            end
        end
        return false
    end
    app.root:addChild(transcript)

    -- Input row
    local inputY = H - inputH + 1
    local textbox = app:createTextBox({
        x = 1, y = inputY, width = W - sendBtnW - 1, height = inputH,
        text = "",
        placeholder = "message (Enter sends, Ctrl+Enter = newline)",
        multiline = true,
        bg = colors.gray, fg = colors.white,
    })
    app.root:addChild(textbox)

    local busy = false
    local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

    local function doSend()
        if busy then return end
        local text = trim(textbox:getText())
        if text == "" then return end
        textbox:setText("")
        scrollLines = 0
        busy = true
        agent:send(text)
        busy = false
        app:setFocus(textbox)
    end

    local sendBtn = app:createButton({
        x = W - sendBtnW + 1, y = inputY, width = sendBtnW, height = inputH,
        label = "Send", bg = colors.green, fg = colors.white,
        onClick = doSend,
    })
    app.root:addChild(sendBtn)

    -- Render synchronously every time the state changes. This is what makes
    -- tool calls visible AS they happen rather than after the whole turn.
    state:onChange(function()
        statusLabel.text = (state.status or "idle") .. " "
        scrollLines = 0  -- snap to bottom on new content
        local ok, err = pcall(function() app:render() end)
        if not ok then
            io.stderr:write("[ui render] " .. tostring(err) .. "\n")
        end
    end)

    -- Wrap the textbox handleEvent so plain Enter SENDS the message
    -- (Ctrl+Enter inserts a newline) and PageUp/PageDown scroll the
    -- transcript.  The textbox sees `key` events first (App:step routes to
    -- the focused widget), so we hook there instead of the root frame.
    local ctrlDown = false
    local prevTextboxHandle = textbox.handleEvent
    function textbox:handleEvent(event, ...)
        if event == "key" then
            local code = ...
            if code == keys.leftCtrl or code == keys.rightCtrl then
                ctrlDown = true
            elseif (code == keys.enter or code == keys.numPadEnter) and not ctrlDown then
                doSend()
                return true
            elseif code == keys.pageUp then
                scrollLines = scrollLines + 5
                app:render()
                return true
            elseif code == keys.pageDown then
                scrollLines = math.max(0, scrollLines - 5)
                app:render()
                return true
            end
        elseif event == "key_up" then
            local code = ...
            if code == keys.leftCtrl or code == keys.rightCtrl then
                ctrlDown = false
            end
        end
        return prevTextboxHandle(self, event, ...)
    end

    app:setFocus(textbox)

    return {
        app = app,
        run = function() app:run() end,
        stop = function() app:stop() end,
    }
end

return M
