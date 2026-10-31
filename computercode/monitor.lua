-- Read-only monitor mirror of the chat transcript.
-- Subscribes to state.onChange and redraws the monitor with role-coded card
-- frames.  Tool call + result get merged into a single two-section card so the
-- pairing is visually obvious.  The footer shows an animated funny status
-- label while the agent is busy.

local tools = require("computercode.tools")

local M = {}

-- Prefer a monitor on the top of the computer (the convention this repo uses).
local function findPreferredMonitor()
    for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
        if peripheral.getType(side) == "monitor" then
            return peripheral.wrap(side), side
        end
    end
    -- peripheral.find returns wrapped peripherals (its 2nd value is a SECOND
    -- monitor, not a name), so resolve the network name explicitly.
    local m = peripheral.find("monitor")
    if m then return m, peripheral.getName(m) end
    return nil, nil
end

-- ----------------------------------------------------------------------------
-- ASCII frame chars (kept simple for font portability)
-- ----------------------------------------------------------------------------

local TL, TR, BL, BR = "+", "+", "+", "+"
local H_, V_         = "-", "|"
local LJ, RJ         = "+", "+"   -- left/right T-junctions for section dividers

local function rep(ch, n) return string.rep(ch, math.max(0, n)) end

-- ----------------------------------------------------------------------------
-- Wrap helper
-- ----------------------------------------------------------------------------

local function splitLines(s)
    local out = {}
    if s == nil or s == "" then out[1] = ""; return out end
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end

local function wrap(text, width)
    if type(text) ~= "string" then text = tostring(text or "") end
    local out = {}
    if width < 4 then width = 4 end
    for _, para in ipairs(splitLines(text)) do
        if para == "" then
            out[#out + 1] = ""
        else
            local rem = para
            while #rem > 0 do
                if #rem <= width then
                    out[#out + 1] = rem; rem = ""
                else
                    local chunk = rem:sub(1, width)
                    local sp = chunk:match(".*()%s")
                    if sp and sp > math.floor(width * 0.4) then
                        out[#out + 1] = rem:sub(1, sp - 1)
                        rem = rem:sub(sp + 1)
                    else
                        out[#out + 1] = chunk
                        rem = rem:sub(width + 1)
                    end
                end
            end
        end
    end
    return out
end

-- ----------------------------------------------------------------------------
-- Result preview helpers
-- ----------------------------------------------------------------------------

local function summarizeResultPreview(result)
    if result == nil then return "" end
    if type(result) == "string" then
        local s = result:gsub("\n", " ")
        if #s > 80 then s = s:sub(1, 77) .. "..." end
        return s
    end
    if type(result) == "table" then
        if result.path and result.bytes_written then
            return result.path .. "  (" .. result.bytes_written .. " B written)"
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
            if #s > 80 then s = s:sub(1, 77) .. "..." end
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
            if #out > 80 then out = out:sub(1, 77) .. "..." end
            return result.command .. " -> " .. (result.ok and "ok" or "fail") ..
                   (out ~= "" and "  " .. out or "")
        end
        local n = 0; for _ in pairs(result) do n = n + 1 end
        return "{" .. n .. " keys}"
    end
    return tostring(result)
end

-- ----------------------------------------------------------------------------
-- Cards.  A card is { borderColor, sections = { { label, labelBg, fg, lines } } }
-- For ordinary entries there's exactly one section.  Tool call + result are
-- combined into one card with two sections joined by a divider.
-- ----------------------------------------------------------------------------

local function singleSection(label, labelBg, fg, lines)
    return { label = label, labelBg = labelBg, fg = fg, lines = lines }
end

local function buildCards(state, innerWidth)
    local cards = {}
    local i = 1
    local entries = state.transcript
    while i <= #entries do
        local e = entries[i]
        if e.kind == "user" then
            cards[#cards + 1] = {
                borderColor = colors.cyan, anchor = "right",
                sections = { singleSection("YOU", colors.cyan, colors.white, wrap(e.text, innerWidth)) },
            }
            i = i + 1
        elseif e.kind == "assistant" then
            cards[#cards + 1] = {
                borderColor = colors.white, anchor = "left",
                sections = { singleSection("AI", colors.white, colors.white, wrap(e.text, innerWidth)) },
            }
            i = i + 1
        elseif e.kind == "thinking" then
            local wrapped = wrap(e.text, innerWidth)
            local MAX_LINES = 5
            if #wrapped > MAX_LINES then
                local dropped = #wrapped - MAX_LINES
                local trimmed = {}
                for i2 = 1, MAX_LINES do trimmed[i2] = wrapped[i2] end
                trimmed[#trimmed + 1] = "...(" .. dropped .. " more lines, " .. #e.text .. " chars total)"
                wrapped = trimmed
            end
            cards[#cards + 1] = {
                borderColor = colors.purple, anchor = "left",
                sections = { singleSection("THINKING", colors.purple, colors.lightGray, wrapped) },
            }
            i = i + 1
        elseif e.kind == "plan" then
            local p = e.plan or {}
            local sections = {}
            sections[#sections + 1] = singleSection(
                "PLAN: " .. (p.title or ""), colors.magenta, colors.white,
                wrap(p.summary or "", innerWidth))
            if type(p.steps) == "table" and #p.steps > 0 then
                local stepLines = {}
                for idx, s in ipairs(p.steps) do
                    for _, w in ipairs(wrap(idx .. ". " .. tostring(s), innerWidth)) do
                        stepLines[#stepLines + 1] = w
                    end
                end
                sections[#sections + 1] = singleSection("STEPS", colors.magenta, colors.white, stepLines)
            end
            local function addFileSection(label, paths, color)
                if type(paths) == "table" and #paths > 0 then
                    local fl = {}
                    for _, f in ipairs(paths) do
                        for _, w in ipairs(wrap("- " .. tostring(f), innerWidth)) do
                            fl[#fl + 1] = w
                        end
                    end
                    sections[#sections + 1] = singleSection(label, color, colors.white, fl)
                end
            end
            addFileSection("CREATE", p.files_to_create, colors.lime)
            addFileSection("EDIT",   p.files_to_edit,   colors.orange)
            sections[#sections + 1] = singleSection(
                "AWAITING APPROVAL", colors.yellow, colors.lightGray,
                wrap("Reply with 'approve' or feedback.", innerWidth))
            cards[#cards + 1] = { borderColor = colors.magenta, anchor = "left", sections = sections }
            i = i + 1
        elseif e.kind == "question" then
            local sections = {}
            for qi, q in ipairs(e.questions or {}) do
                local ql = {}
                for _, w in ipairs(wrap(q.question, innerWidth)) do ql[#ql + 1] = w end
                ql[#ql + 1] = ""
                for oi, opt in ipairs(q.options or {}) do
                    local letter = string.char(96 + oi)
                    local line = "  " .. letter .. ") " .. opt.label
                    if opt.description and opt.description ~= "" then
                        line = line .. "  -  " .. opt.description
                    end
                    for _, w in ipairs(wrap(line, innerWidth)) do ql[#ql + 1] = w end
                end
                local dl = string.char(96 + #(q.options or {}) + 1)
                ql[#ql + 1] = "  " .. dl .. ") talk about this instead"
                sections[#sections + 1] = singleSection(
                    "Q" .. qi, colors.yellow, colors.white, ql)
            end
            sections[#sections + 1] = singleSection(
                "REPLY LIKE '1a 2c' OR FREE-FORM", colors.gray, colors.lightGray, { "" })
            cards[#cards + 1] = { borderColor = colors.yellow, anchor = "left", sections = sections }
            i = i + 1
        elseif e.kind == "error" then
            cards[#cards + 1] = {
                borderColor = colors.red, anchor = "left",
                sections = { singleSection("ERROR", colors.red, colors.red, wrap(tostring(e.text), innerWidth)) },
            }
            i = i + 1
        elseif e.kind == "tool_call" then
            local callBody = "-> " .. e.name .. "(" .. tools.summarizeArgs(e.args) .. ")"
            local nextE = entries[i + 1]
            if nextE and nextE.kind == "tool_result" and nextE.callId == e.callId then
                local resBody
                if nextE.ok then
                    resBody = "<- " .. summarizeResultPreview(nextE.result)
                else
                    resBody = "<- ERROR: " .. tostring(nextE.result)
                end
                cards[#cards + 1] = {
                    borderColor = nextE.ok and colors.yellow or colors.red,
                    anchor = "left",
                    sections = {
                        singleSection("TOOL", colors.yellow, colors.yellow, wrap(callBody, innerWidth)),
                        singleSection(
                            nextE.ok and "RESULT" or "ERROR",
                            nextE.ok and colors.gray or colors.red,
                            nextE.ok and colors.lightGray or colors.red,
                            wrap(resBody, innerWidth)),
                    },
                }
                i = i + 2
            else
                -- Result hasn't arrived yet (still mid-flight).
                cards[#cards + 1] = {
                    borderColor = colors.yellow, anchor = "left",
                    sections = { singleSection("TOOL", colors.yellow, colors.yellow, wrap(callBody, innerWidth)) },
                }
                i = i + 1
            end
        elseif e.kind == "tool_result" then
            -- Orphan result (no preceding call) - render solo.
            local resBody
            if e.ok then
                resBody = "<- " .. summarizeResultPreview(e.result)
            else
                resBody = "<- ERROR: " .. tostring(e.result)
            end
            cards[#cards + 1] = {
                borderColor = e.ok and colors.gray or colors.red,
                anchor = "left",
                sections = {
                    singleSection(e.ok and "RESULT" or "ERROR",
                        e.ok and colors.gray or colors.red,
                        e.ok and colors.lightGray or colors.red,
                        wrap(resBody, innerWidth)),
                },
            }
            i = i + 1
        else
            i = i + 1
        end
    end
    return cards
end

-- A card occupies: 1 (top border) + sum(#section.lines + 1 divider per extra section) + 1 (bottom border).
-- Plus 1 trailing gap row.
local function cardHeight(card)
    local h = 2  -- top + bottom borders
    for idx, s in ipairs(card.sections) do
        h = h + #s.lines
        if idx > 1 then h = h + 1 end  -- divider above this section
    end
    return h + 1  -- trailing gap
end

-- ----------------------------------------------------------------------------
-- Drawing primitives
-- ----------------------------------------------------------------------------

local function fillLine(mon, y, w, color)
    mon.setCursorPos(1, y)
    mon.setBackgroundColor(color)
    mon.setTextColor(colors.white)
    mon.write(string.rep(" ", w))
end

local function writeAt(mon, screenW, screenH, x, y, text, fg, bg)
    if y < 1 or y > screenH then return end
    if x < 1 then text = text:sub(2 - x); x = 1 end
    if x > screenW then return end
    if x + #text - 1 > screenW then text = text:sub(1, screenW - x + 1) end
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(bg or colors.black)
    mon.setTextColor(fg or colors.white)
    mon.write(text)
end

local function drawCard(mon, card, x0, y0, cardW, screenW, screenH)
    local borderFg = card.borderColor

    -- Top border with first section label
    local top = TL .. rep(H_, cardW - 2) .. TR
    writeAt(mon, screenW, screenH, x0, y0, top, borderFg, colors.black)
    local firstLabel = " " .. card.sections[1].label .. " "
    writeAt(mon, screenW, screenH, x0 + 2, y0,
        firstLabel, colors.black, card.sections[1].labelBg)

    local y = y0 + 1
    for idx, sec in ipairs(card.sections) do
        if idx > 1 then
            -- Section divider with this section's label
            local div = LJ .. rep(H_, cardW - 2) .. RJ
            writeAt(mon, screenW, screenH, x0, y, div, borderFg, colors.black)
            local lab = " " .. sec.label .. " "
            writeAt(mon, screenW, screenH, x0 + 2, y, lab, colors.black, sec.labelBg)
            y = y + 1
        end
        for _, line in ipairs(sec.lines) do
            writeAt(mon, screenW, screenH, x0, y, V_, borderFg, colors.black)
            writeAt(mon, screenW, screenH, x0 + cardW - 1, y, V_, borderFg, colors.black)
            writeAt(mon, screenW, screenH, x0 + 2, y, line, sec.fg, colors.black)
            y = y + 1
        end
    end

    local bottom = BL .. rep(H_, cardW - 2) .. BR
    writeAt(mon, screenW, screenH, x0, y, bottom, borderFg, colors.black)
end

local function drawHeader(mon, w, modelName)
    fillLine(mon, 1, w, colors.purple)
    local left = " COMPUTERCODE  -  " .. (modelName or "?")
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.purple); mon.setTextColor(colors.white)
    mon.write(left:sub(1, w))
end

-- ----------------------------------------------------------------------------
-- Animated footer ("Pondering...", spinner, etc.)
-- ----------------------------------------------------------------------------

local SPINNER = { "|", "/", "-", "\\" }
local LABELS = {
    "Thinking", "Pondering", "Cogitating", "Ruminating", "Mulling",
    "Brewing thoughts", "Consulting the elders", "Asking the void",
    "Questioning reality", "Pondering the laws of the universe",
    "Calculating", "Computing", "Wondering", "Daydreaming",
    "Synthesizing", "Plotting", "Conjuring", "Crafting", "Hatching plans",
    "Untangling", "Spelunking the docs", "Rolling for initiative",
    "Reticulating splines", "Defragmenting neurons", "Polishing pixels",
    "Brewing coffee", "Procrastinating productively",
}

local function drawFooter(mon, w, h, status, ctx)
    fillLine(mon, h, w, colors.gray)

    if status == "idle" or not status then
        local txt = " type on the computer  -  monitor is read-only "
        writeAt(mon, w, h, 1, h, txt:sub(1, w), colors.lightGray, colors.gray)
        return
    end

    -- Pick a new funny label whenever we transition idle -> busy.
    if ctx.lastStatus == "idle" or not ctx.label then
        ctx.label = LABELS[math.random(#LABELS)]
    end
    ctx.phase = (ctx.phase or 0) + 1
    local sp = SPINNER[(ctx.phase - 1) % #SPINNER + 1]
    local detail = ""
    if status:sub(1, 5) == "tool:" then
        detail = "  (" .. status:sub(6):gsub("^%s+", "") .. ")"
    end
    local txt = "  " .. sp .. "  " .. ctx.label .. "..." .. detail
    writeAt(mon, w, h, 1, h, txt:sub(1, w), colors.yellow, colors.gray)
end

-- ----------------------------------------------------------------------------
-- Public: attach to a monitor (or no-op if none)
-- ----------------------------------------------------------------------------

function M.attach(state, opts)
    opts = opts or {}
    local mon, monName = findPreferredMonitor()
    if not mon then return { active = false } end

    if mon.setTextScale then mon.setTextScale(opts.textScale or 0.5) end
    mon.setBackgroundColor(colors.black)
    mon.clear()

    local ctx = { phase = 0, lastStatus = "idle", label = nil }

    local function redraw()
        local w, h = mon.getSize()
        if w < 20 or h < 6 then
            mon.setBackgroundColor(colors.black); mon.clear()
            mon.setCursorPos(1, 1); mon.setTextColor(colors.red)
            mon.write("monitor too small")
            return
        end

        mon.setBackgroundColor(colors.black); mon.clear()
        drawHeader(mon, w, state.model)

        local cardX = 2
        local cardW = w - 2
        local innerW = cardW - 4
        local cards = buildCards(state, innerW)

        local available = h - 3   -- header(1) + footer(1) + 1 gap
        local visible = {}
        local used = 0
        for i = #cards, 1, -1 do
            local ch = cardHeight(cards[i])
            if used + ch > available then break end
            table.insert(visible, 1, cards[i])
            used = used + ch
        end

        local y = 3 + (available - used)
        for _, c in ipairs(visible) do
            drawCard(mon, c, cardX, y, cardW, w, h)
            y = y + cardHeight(c)
        end

        drawFooter(mon, w, h, state.status, ctx)
        ctx.lastStatus = state.status or "idle"
    end

    state:onChange(redraw)
    redraw()

    return {
        active = true,
        redraw = redraw,
        monitor = mon,
        side = monName,
    }
end

return M
