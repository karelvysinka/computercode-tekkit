-- infopad.lua - Touch arcade built with PixelUI.
-- Main menu -> Info / Life / Tic-Tac-Toe / Magic 8-Ball / Whack-a-Mole.
-- Auto-uses an attached monitor if present; works with monitor_touch AND
-- mouse_click on advanced computers.

local pixelui = require("pixelui")
local shrekbox = require("shrekbox")

-- Prefer a monitor on top, then any other side, then any network-attached one.
local function findPreferredMonitor()
    for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
        if peripheral.getType(side) == "monitor" then
            return peripheral.wrap(side)
        end
    end
    return peripheral.find("monitor")
end
local monitor = findPreferredMonitor()
local prevTerm
if monitor then
    monitor.setTextScale(0.5)
    prevTerm = term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    term.clear()
end

local app = pixelui.create({ background = colors.black })
local W, H = app.window.getSize()

math.randomseed(os.epoch("utc"))
local function pick(list) return list[math.random(#list)] end

-- Character cells are visually taller than wide (~2:3).  Multiplying a desired
-- height in chars by 1.5 produces a visually square block on screen.
local CHAR_ASPECT = 1.5
local function squareW(heightChars) return math.max(1, math.floor(heightChars * CHAR_ASPECT + 0.5)) end

-- PixelUI's ctx.pixel is broken (it uses char-space coords but maps them to
-- pixel-space), so we hit the shrekbox layers directly.  Each character cell
-- holds a 2x3 pixel subgrid.  We also clear the text layer covering the
-- widget so the pixel layer is visible underneath it.
local TRANSPARENT = shrekbox.transparent
local function pxBegin(ctx, bgColor)
    for dy = 0, ctx.height - 1 do
        for dx = 0, ctx.width - 1 do
            ctx.textLayer.pixel(ctx.x + dx, ctx.y + dy, TRANSPARENT)
        end
    end
    if bgColor then
        local px0 = (ctx.x - 1) * 2 + 1
        local py0 = (ctx.y - 1) * 3 + 1
        local pw = ctx.width * 2
        local ph = ctx.height * 3
        for dy = 0, ph - 1 do
            for dx = 0, pw - 1 do
                ctx.pixelLayer.pixel(px0 + dx, py0 + dy, bgColor)
            end
        end
    end
end

local function pxSet(ctx, x, y, color)
    local pw, ph = ctx.width * 2, ctx.height * 3
    if x < 1 or x > pw or y < 1 or y > ph then return end
    ctx.pixelLayer.pixel((ctx.x - 1) * 2 + x, (ctx.y - 1) * 3 + y, color)
end

local function pxDisk(ctx, cx, cy, r, color)
    local r2 = r * r
    local pw, ph = ctx.width * 2, ctx.height * 3
    local y0 = math.max(1, math.floor(cy - r))
    local y1 = math.min(ph, math.ceil(cy + r))
    local x0 = math.max(1, math.floor(cx - r))
    local x1 = math.min(pw, math.ceil(cx + r))
    for py = y0, y1 do
        for px = x0, x1 do
            local dx, dy = px - cx, py - cy
            if dx * dx + dy * dy <= r2 then
                pxSet(ctx, px, py, color)
            end
        end
    end
end

local function pxRing(ctx, cx, cy, r, thickness, color)
    local rOuter2 = r * r
    local rInner2 = (r - thickness) * (r - thickness)
    local pw, ph = ctx.width * 2, ctx.height * 3
    local y0 = math.max(1, math.floor(cy - r))
    local y1 = math.min(ph, math.ceil(cy + r))
    local x0 = math.max(1, math.floor(cx - r))
    local x1 = math.min(pw, math.ceil(cx + r))
    for py = y0, y1 do
        for px = x0, x1 do
            local dx, dy = px - cx, py - cy
            local d2 = dx * dx + dy * dy
            if d2 <= rOuter2 and d2 >= rInner2 then
                pxSet(ctx, px, py, color)
            end
        end
    end
end

--------------------------------------------------------------------
-- Panel plumbing
--------------------------------------------------------------------
local panels = {}
local currentPanel
local function showPanel(name)
    if currentPanel and panels[currentPanel] then
        panels[currentPanel].frame.visible = false
        if panels[currentPanel].onHide then panels[currentPanel].onHide() end
    end
    currentPanel = name
    local p = panels[name]
    p.frame.visible = true
    if p.onShow then p.onShow() end
end

local function makePanel(name, title, titleBg)
    local frame = app:createFrame({
        x = 1, y = 1, width = W, height = H,
        bg = colors.black, visible = false,
    })
    app.root:addChild(frame)

    local header = app:createLabel({
        x = 1, y = 1, width = W, height = 1,
        text = " " .. title, align = "left",
        bg = titleBg or colors.blue, fg = colors.white,
    })
    frame:addChild(header)

    local backBtn = app:createButton({
        x = W - 9, y = 1, width = 10, height = 1,
        label = " Menu ", bg = colors.gray, fg = colors.white,
        clickEffect = true,
        onClick = function() showPanel("menu") end,
    })
    frame:addChild(backBtn)

    panels[name] = { frame = frame, header = header }
    return panels[name]
end

--------------------------------------------------------------------
-- MAIN MENU  (2 cols x 3 rows - wider & taller tiles)
--------------------------------------------------------------------
local menuFrame = app:createFrame({
    x = 1, y = 1, width = W, height = H,
    bg = colors.black,
})
app.root:addChild(menuFrame)

local menuTitle = app:createLabel({
    x = 1, y = 1, width = W, height = 1,
    text = " ARCADE  -  touch a tile to play ",
    align = "center",
    bg = colors.purple, fg = colors.white,
})
menuFrame:addChild(menuTitle)

local menuSubtitle = app:createLabel({
    x = 1, y = 2, width = W, height = 1,
    text = "",
    align = "center",
    bg = colors.black, fg = colors.lightGray,
})
menuFrame:addChild(menuSubtitle)

local menuVisits = 0
local function bumpVisits(name)
    menuVisits = menuVisits + 1
    menuSubtitle.text = "last opened: " .. name .. "   -   total opens: " .. menuVisits
end

local menuTiles = {
    { name = "info",  label = "Info",          bg = colors.cyan,    fg = colors.white },
    { name = "life",  label = "Game of Life",  bg = colors.lime,    fg = colors.black },
    { name = "ttt",   label = "Tic-Tac-Toe",   bg = colors.red,     fg = colors.white },
    { name = "ball",  label = "Magic 8-Ball",  bg = colors.blue,    fg = colors.white },
    { name = "mole",  label = "Whack-a-Mole",  bg = colors.orange,  fg = colors.black },
    { name = "exit",  label = "Exit",          bg = colors.gray,    fg = colors.white },
}

local mCols, mRows = 2, 3
local mTileAreaY = 3
local mTileAreaH = H - mTileAreaY
local mGapX, mGapY = 2, 1
local mTileW = math.floor((W - (mCols + 1) * mGapX) / mCols)
local mTileH = math.max(5, math.floor((mTileAreaH - (mRows + 1) * mGapY) / mRows))

for i, t in ipairs(menuTiles) do
    local col = (i - 1) % mCols
    local row = math.floor((i - 1) / mCols)
    local tx = mGapX + col * (mTileW + mGapX) + 1
    local ty = mTileAreaY + mGapY + row * (mTileH + mGapY)
    local tile = app:createButton({
        x = tx, y = ty, width = mTileW, height = mTileH,
        label = t.label, bg = t.bg, fg = t.fg,
        onClick = function()
            if t.name == "exit" then
                app:stop()
            else
                bumpVisits(t.label)
                showPanel(t.name)
            end
        end,
    })
    menuFrame:addChild(tile)
end

menuSubtitle.text = "tap a tile to open -  screen " .. W .. "x" .. H
panels.menu = { frame = menuFrame }

--------------------------------------------------------------------
-- INFO PANEL (taller buttons)
--------------------------------------------------------------------
do
    local p = makePanel("info", "INFO  -  random trivia & quotes", colors.cyan)

    local quotes = {
        "The best way to predict the future is to invent it.",
        "Simplicity is the ultimate sophistication.",
        "Code is read more often than it is written.",
        "Make it work, make it right, make it fast.",
        "Talk is cheap. Show me the code.",
        "Premature optimization is the root of all evil.",
    }
    local facts = {
        "A group of flamingos is called a 'flamboyance'.",
        "Octopuses have three hearts and blue blood.",
        "Honey never spoils - 3000-year-old honey is still edible.",
        "Bananas are berries, but strawberries are not.",
        "A day on Venus is longer than its year.",
        "Sharks existed before trees did.",
        "Wombat poop is cube-shaped.",
    }
    local jokes = {
        "Why do programmers prefer dark mode?  Light attracts bugs.",
        "A SQL query walks into a bar, sees two tables: 'can I join you?'",
        "I would tell you a UDP joke, but you might not get it.",
        "!false - it's funny because it's true.",
    }
    local clr = {
        colors.red, colors.orange, colors.yellow, colors.lime, colors.green,
        colors.cyan, colors.lightBlue, colors.blue, colors.purple,
        colors.magenta, colors.pink, colors.white,
    }
    local clrNames = {
        [colors.red]="Red",[colors.orange]="Orange",[colors.yellow]="Yellow",
        [colors.lime]="Lime",[colors.green]="Green",[colors.cyan]="Cyan",
        [colors.lightBlue]="Sky Blue",[colors.blue]="Blue",
        [colors.purple]="Purple",[colors.magenta]="Magenta",
        [colors.pink]="Pink",[colors.white]="White",
    }

    local pad = 2
    local buttonH = math.max(5, math.floor(H * 0.25))
    local buttonY = H - buttonH - pad + 2
    local cardY = 3
    local cardH = buttonY - cardY - 1

    local card = app:createFrame({
        x = pad, y = cardY, width = W - pad * 2 + 2, height = cardH,
        bg = colors.gray,
        border = { color = colors.lightGray, sides = { "top","right","bottom","left" } },
    })
    p.frame:addChild(card)

    local categoryLabel = app:createLabel({
        x = 2, y = 2, width = W - pad * 2, height = 1,
        text = "WELCOME", align = "center",
        bg = colors.gray, fg = colors.yellow,
    })
    card:addChild(categoryLabel)

    local swatch = app:createFrame({
        x = 2, y = 3, width = W - pad * 2, height = 1,
        bg = colors.gray,
    })
    card:addChild(swatch)

    local infoLabel = app:createLabel({
        x = 2, y = 5, width = W - pad * 2, height = math.max(1, cardH - 5),
        text = "Touch a button below for random info.",
        align = "center", verticalAlign = "middle", wrap = true,
        bg = colors.gray, fg = colors.white,
    })
    card:addChild(infoLabel)

    local function showInfo(cat, text, textColor, swatchColor)
        categoryLabel.text = " " .. cat .. " "
        infoLabel.text = text
        infoLabel.fg = textColor or colors.white
        swatch.bg = swatchColor or colors.gray
    end

    local actions = {
        { label = "Quote",  bg = colors.purple, fn = function()
            showInfo("QUOTE", '"' .. pick(quotes) .. '"', colors.yellow, colors.purple) end },
        { label = "Dice",   bg = colors.red,    fn = function()
            local a, b = math.random(6), math.random(6)
            showInfo("DICE", "You rolled " .. a .. " + " .. b .. " = " .. (a+b),
                colors.white, colors.red) end },
        { label = "Number", bg = colors.orange, fn = function()
            showInfo("NUMBER", tostring(math.random(9999)), colors.lime, colors.orange) end },
        { label = "Color",  bg = colors.green,  fn = function()
            local c = pick(clr); showInfo("COLOR", clrNames[c], c, c) end },
        { label = "Fact",   bg = colors.cyan,   fn = function()
            showInfo("FACT", pick(facts), colors.white, colors.cyan) end },
        { label = "Joke",   bg = colors.pink,   fn = function()
            showInfo("JOKE", pick(jokes), colors.white, colors.pink) end },
    }
    local gap = 1
    local bw = math.max(6, math.floor((W - pad * 2 + 2 - (#actions - 1) * gap) / #actions))
    local bx = pad
    for i, a in ipairs(actions) do
        local w = bw
        if i == #actions then w = W - pad + 1 - bx end
        local btn = app:createButton({
            x = bx, y = buttonY, width = w, height = buttonH,
            label = a.label, bg = a.bg, fg = colors.white,
            onClick = a.fn,
        })
        p.frame:addChild(btn)
        bx = bx + w + gap
    end
end

--------------------------------------------------------------------
-- GAME OF LIFE
--------------------------------------------------------------------
do
    local p = makePanel("life", "CONWAY'S GAME OF LIFE", colors.lime)

    local boardAreaY = 3
    local controlsH = math.max(5, math.floor(H * 0.22))
    local boardH = H - boardAreaY - controlsH - 1
    local boardW = W - 2
    local gridW = math.max(10, boardW)
    local gridH = math.max(6, boardH)

    local grid = {}
    local nextGrid = {}
    local function newGrid()
        for y = 1, gridH do
            grid[y] = grid[y] or {}
            nextGrid[y] = nextGrid[y] or {}
            for x = 1, gridW do
                grid[y][x] = false
                nextGrid[y][x] = false
            end
        end
    end
    newGrid()

    local function randomize()
        for y = 1, gridH do
            for x = 1, gridW do
                grid[y][x] = math.random() < 0.22
            end
        end
    end

    local function stepGrid()
        for y = 1, gridH do
            for x = 1, gridW do
                local n = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then
                            local ny = ((y - 1 + dy) % gridH) + 1
                            local nx = ((x - 1 + dx) % gridW) + 1
                            if grid[ny][nx] then n = n + 1 end
                        end
                    end
                end
                local alive = grid[y][x]
                if alive and (n == 2 or n == 3) then
                    nextGrid[y][x] = true
                elseif not alive and n == 3 then
                    nextGrid[y][x] = true
                else
                    nextGrid[y][x] = false
                end
            end
        end
        grid, nextGrid = nextGrid, grid
    end

    local board = app:createFreeDraw({
        x = 2, y = boardAreaY, width = gridW, height = gridH,
        bg = colors.black,
        onDraw = function(self, ctx)
            for y = 1, gridH do
                for x = 1, gridW do
                    if grid[y][x] then
                        ctx.write(x, y, " ", colors.black, colors.lime)
                    else
                        ctx.write(x, y, " ", colors.black, colors.gray)
                    end
                end
            end
        end,
    })
    p.frame:addChild(board)

    function board:handleEvent(event, _a, b, c)
        if event == "monitor_touch" or event == "mouse_click" then
            local px, py = b, c
            local ax, ay = self:getAbsoluteRect()
            if not self:containsPoint(px, py) then return false end
            local cx = px - ax + 1
            local cy = py - ay + 1
            if grid[cy] and grid[cy][cx] ~= nil then
                grid[cy][cx] = not grid[cy][cx]
                return true
            end
        end
        return false
    end

    local statusLabel = app:createLabel({
        x = 1, y = boardAreaY + gridH, width = W, height = 1,
        text = "Tap cells to toggle.  Press Play to animate.",
        align = "center",
        bg = colors.black, fg = colors.lightGray,
    })
    p.frame:addChild(statusLabel)

    local playing = false
    local generation = 0

    local function setStatus()
        statusLabel.text = (playing and "[PLAYING] " or "[PAUSED] ") ..
            "generation " .. generation
    end

    local ctrlY = H - controlsH + 1
    local ctrls = {
        { label = "Play/Pause", bg = colors.lime, fn = function()
            playing = not playing; setStatus() end },
        { label = "Step",       bg = colors.yellow, fn = function()
            stepGrid(); generation = generation + 1; setStatus() end },
        { label = "Random",     bg = colors.magenta, fn = function()
            randomize(); generation = 0; setStatus() end },
        { label = "Clear",      bg = colors.red, fn = function()
            newGrid(); generation = 0; setStatus() end },
        { label = "Glider",     bg = colors.cyan, fn = function()
            newGrid()
            local cx, cy = math.floor(gridW / 2), math.floor(gridH / 2)
            local pattern = { {2,1},{3,2},{1,3},{2,3},{3,3} }
            for _, q in ipairs(pattern) do
                local x, y = cx + q[1], cy + q[2]
                if grid[y] and grid[y][x] ~= nil then grid[y][x] = true end
            end
            generation = 0; setStatus()
        end },
    }
    local bgap = 1
    local bw = math.max(8, math.floor((W - 2 - (#ctrls - 1) * bgap) / #ctrls))
    local bx = 2
    for i, c in ipairs(ctrls) do
        local w = bw
        if i == #ctrls then w = W - bx end
        local btn = app:createButton({
            x = bx, y = ctrlY, width = w, height = controlsH,
            label = c.label, bg = c.bg, fg = colors.black,
            onClick = c.fn,
        })
        p.frame:addChild(btn)
        bx = bx + w + bgap
    end

    setStatus()

    app:spawnThread(function(ctx)
        while not ctx:isCancelled() do
            if playing and currentPanel == "life" then
                stepGrid()
                generation = generation + 1
                setStatus()
            end
            ctx:sleep(0.25)
        end
    end, { name = "life-tick" })
end

--------------------------------------------------------------------
-- TIC-TAC-TOE  (FreeDraw cells kept square, drawn X and O shapes)
--------------------------------------------------------------------
do
    local p = makePanel("ttt", "TIC-TAC-TOE", colors.red)

    local board = { "", "", "", "", "", "", "", "", "" }
    local current = "X"
    local wins = { X = 0, O = 0, D = 0 }
    local gameOver = false
    local winLine

    local statusLabel = app:createLabel({
        x = 1, y = 3, width = W, height = 1,
        text = "Player X's turn",
        align = "center",
        bg = colors.black, fg = colors.yellow,
    })
    p.frame:addChild(statusLabel)

    local scoreLabel = app:createLabel({
        x = 1, y = 4, width = W, height = 1,
        text = "X: 0    O: 0    Draws: 0",
        align = "center",
        bg = colors.black, fg = colors.lightGray,
    })
    p.frame:addChild(scoreLabel)

    local resetH = math.max(3, math.floor(H * 0.18))
    local gridAreaY = 6
    local gridAreaBottom = H - resetH - 1
    local gridAreaH = gridAreaBottom - gridAreaY + 1
    local gridAreaW = W - 4

    -- Square cells: pick the larger cellH that keeps cellW = 1.5 * cellH fitting.
    local maxCellH = math.floor(gridAreaH / 3)
    local maxCellW = math.floor(gridAreaW / 3)
    local cellH, cellW
    if maxCellW >= squareW(maxCellH) then
        cellH = maxCellH
        cellW = squareW(cellH)
    else
        cellW = maxCellW
        cellH = math.max(2, math.floor(cellW / CHAR_ASPECT + 0.5))
    end
    local gridW = cellW * 3 + 2
    local gridH = cellH * 3 + 2
    local gridX = math.floor((W - gridW) / 2) + 1
    local gridY = gridAreaY + math.floor((gridAreaH - gridH) / 2)

    local function drawX(ctx, color)
        local pw, ph = ctx.width * 2, ctx.height * 3
        local margin = math.max(2, math.floor(math.min(pw, ph) * 0.18))
        local span = math.max(pw, ph)
        for i = 0, span do
            local t = i / span
            local lx = margin + (pw - 2 * margin) * t
            local ly = margin + (ph - 2 * margin) * t
            local ax = math.floor(lx + 0.5)
            local ay = math.floor(ly + 0.5)
            local bx = math.floor(pw - margin - (pw - 2 * margin) * t + 0.5)
            for ox = 0, 1 do
                for oy = 0, 1 do
                    pxSet(ctx, ax + ox, ay + oy, color)
                    pxSet(ctx, bx + ox, ay + oy, color)
                end
            end
        end
    end

    local function drawO(ctx, color)
        local pw, ph = ctx.width * 2, ctx.height * 3
        local cx = pw / 2 + 0.5
        local cy = ph / 2 + 0.5
        local r = math.max(3, math.min(pw, ph) / 2 - 1.5)
        pxRing(ctx, cx, cy, r, 2, color)
    end

    local cellDraws = {}

    local function refreshScore()
        scoreLabel.text = "X: " .. wins.X .. "    O: " .. wins.O ..
            "    Draws: " .. wins.D
    end

    local function checkWinner()
        local lines = {
            {1,2,3},{4,5,6},{7,8,9},
            {1,4,7},{2,5,8},{3,6,9},
            {1,5,9},{3,5,7},
        }
        for _, ln in ipairs(lines) do
            local a,b,c = ln[1], ln[2], ln[3]
            if board[a] ~= "" and board[a] == board[b] and board[b] == board[c] then
                return board[a], ln
            end
        end
        for i = 1, 9 do if board[i] == "" then return nil end end
        return "D"
    end

    local function resetBoard()
        for i = 1, 9 do board[i] = "" end
        current = "X"
        gameOver = false
        winLine = nil
        statusLabel.text = "Player X's turn"
    end

    local function makeCellDraw(idx, col, row)
        local cx = gridX + col * (cellW + 1)
        local cy = gridY + row * (cellH + 1)
        local fd = app:createFreeDraw({
            x = cx, y = cy, width = cellW, height = cellH,
            bg = colors.white,
            clear = false,
            onDraw = function(self, ctx)
                local bg = colors.white
                if winLine then
                    for _, wi in ipairs(winLine) do
                        if wi == idx then bg = colors.yellow end
                    end
                end
                pxBegin(ctx, bg)
                local mark = board[idx]
                if mark == "X" then
                    drawX(ctx, colors.red)
                elseif mark == "O" then
                    drawO(ctx, colors.blue)
                end
            end,
        })
        function fd:handleEvent(event, _a, px, py)
            if event == "monitor_touch" or event == "mouse_click" then
                if not self:containsPoint(px, py) then return false end
                if gameOver or board[idx] ~= "" then return true end
                board[idx] = current
                local winner, line = checkWinner()
                if winner == "X" or winner == "O" then
                    gameOver = true
                    wins[winner] = wins[winner] + 1
                    winLine = line
                    statusLabel.text = "Player " .. winner .. " wins!"
                    refreshScore()
                elseif winner == "D" then
                    gameOver = true
                    wins.D = wins.D + 1
                    statusLabel.text = "Draw! Tap Reset to play again."
                    refreshScore()
                else
                    current = current == "X" and "O" or "X"
                    statusLabel.text = "Player " .. current .. "'s turn"
                end
                return true
            end
            return false
        end
        p.frame:addChild(fd)
        return fd
    end

    for row = 0, 2 do
        for col = 0, 2 do
            local idx = row * 3 + col + 1
            cellDraws[idx] = makeCellDraw(idx, col, row)
        end
    end

    local resetBtn = app:createButton({
        x = math.floor(W / 2) - 10, y = H - resetH + 1,
        width = 20, height = resetH,
        label = "Reset Round", bg = colors.orange, fg = colors.black,
        onClick = resetBoard,
    })
    p.frame:addChild(resetBtn)
end

--------------------------------------------------------------------
-- MAGIC 8-BALL
--------------------------------------------------------------------
do
    local p = makePanel("ball", "MAGIC 8-BALL", colors.blue)

    local answers = {
        "It is certain.",
        "Without a doubt.",
        "Yes, definitely.",
        "You may rely on it.",
        "As I see it, yes.",
        "Most likely.",
        "Signs point to yes.",
        "Reply hazy, try again.",
        "Ask again later.",
        "Cannot predict now.",
        "Don't count on it.",
        "My reply is no.",
        "Very doubtful.",
        "Outlook not so good.",
    }

    local shakeH = math.max(5, math.floor(H * 0.22))
    local ballH = H - 3 - shakeH - 1
    local ballArea = app:createFrame({
        x = 2, y = 3, width = W - 2, height = ballH,
        bg = colors.black,
    })
    p.frame:addChild(ballArea)

    local ballDrawH = math.max(3, ballH - 5)
    local ball = app:createFreeDraw({
        x = 1, y = 1, width = W - 2, height = ballDrawH,
        bg = colors.black,
        clear = false,
        onDraw = function(self, ctx)
            pxBegin(ctx, colors.black)
            local pw, ph = ctx.width * 2, ctx.height * 3
            local cx, cy = pw / 2 + 0.5, ph / 2 + 0.5
            local r = math.max(4, math.min(pw, ph) / 2 - 1)
            pxDisk(ctx, cx, cy, r, colors.black)
            pxRing(ctx, cx, cy, r, 2, colors.gray)
            local innerR = math.max(2, r * 0.45)
            pxDisk(ctx, cx, cy, innerR, colors.white)
            -- "8" etched in the center window, drawn as pixels so it stays on
            -- the pixel layer alongside the ball.
            local eightR = math.max(1, innerR * 0.55)
            pxRing(ctx, cx, cy - eightR * 0.55, eightR * 0.85, 1, colors.black)
            pxRing(ctx, cx, cy + eightR * 0.55, eightR * 0.85, 1, colors.black)
        end,
    })
    ballArea:addChild(ball)

    local answerLabel = app:createLabel({
        x = 1, y = ballDrawH + 1, width = W - 2, height = math.max(2, ballH - ballDrawH),
        text = "Ask a yes/no question, then tap Shake.",
        align = "center", verticalAlign = "middle", wrap = true,
        bg = colors.black, fg = colors.lightBlue,
    })
    ballArea:addChild(answerLabel)

    local shakeBtn = app:createButton({
        x = math.floor(W / 2) - 12, y = H - shakeH,
        width = 24, height = shakeH,
        label = "Shake the Ball",
        bg = colors.blue, fg = colors.white,
        onClick = function()
            answerLabel.text = "shaking..."
            answerLabel.fg = colors.yellow
            app:animate({
                duration = 0.5,
                easing = "linear",
                update = function() end,
                onComplete = function()
                    answerLabel.text = pick(answers)
                    answerLabel.fg = colors.lightBlue
                end,
            })
        end,
    })
    p.frame:addChild(shakeBtn)
end

--------------------------------------------------------------------
-- WHACK-A-MOLE  (3x3 square grid)
--------------------------------------------------------------------
do
    local p = makePanel("mole", "WHACK-A-MOLE  -  tap the red tile!", colors.orange)

    local score = 0
    local timeLeft = 0
    local active = -1
    local running = false
    local gridCols, gridRows = 3, 3

    local scoreLabel = app:createLabel({
        x = 1, y = 3, width = W, height = 1,
        text = "Score: 0",
        align = "center",
        bg = colors.black, fg = colors.yellow,
    })
    p.frame:addChild(scoreLabel)

    local timeLabel = app:createLabel({
        x = 1, y = 4, width = W, height = 1,
        text = "Press Start to play a 20-second round.",
        align = "center",
        bg = colors.black, fg = colors.lightGray,
    })
    p.frame:addChild(timeLabel)

    local startH = math.max(3, math.floor(H * 0.18))
    local gridAreaY = 6
    local gridAreaBottom = H - startH - 1
    local gridAreaH = gridAreaBottom - gridAreaY + 1
    local gridAreaW = W - 4

    local maxCellH = math.floor(gridAreaH / gridRows)
    local maxCellW = math.floor(gridAreaW / gridCols)
    local cellH, cellW
    if maxCellW >= squareW(maxCellH) then
        cellH = maxCellH
        cellW = squareW(cellH)
    else
        cellW = maxCellW
        cellH = math.max(2, math.floor(cellW / CHAR_ASPECT + 0.5))
    end
    local gridW = cellW * gridCols + (gridCols - 1)
    local gridH = cellH * gridRows + (gridRows - 1)
    local gx0 = math.floor((W - gridW) / 2) + 1
    local gy0 = gridAreaY + math.floor((gridAreaH - gridH) / 2)

    local tiles = {}

    local function drawMoleTile(ctx, isActive)
        local pw, ph = ctx.width * 2, ctx.height * 3
        local cx, cy = pw / 2 + 0.5, ph / 2 + 0.5
        local r = math.max(3, math.min(pw, ph) / 2 - 1)
        if isActive then
            pxBegin(ctx, colors.red)
            pxDisk(ctx, cx, cy, r, colors.brown)
            local eyeR = math.max(1, math.floor(r * 0.18))
            local offX = math.max(2, math.floor(r * 0.35))
            local offY = math.max(1, math.floor(r * 0.2))
            pxDisk(ctx, cx - offX, cy - offY, eyeR, colors.white)
            pxDisk(ctx, cx + offX, cy - offY, eyeR, colors.white)
            pxDisk(ctx, cx - offX, cy - offY, math.max(1, eyeR - 1), colors.black)
            pxDisk(ctx, cx + offX, cy - offY, math.max(1, eyeR - 1), colors.black)
            -- Tiny snout dot
            pxDisk(ctx, cx, cy + math.floor(r * 0.1), math.max(1, math.floor(r * 0.12)), colors.pink)
        else
            pxBegin(ctx, colors.lightGray)
            pxRing(ctx, cx, cy, r, 1, colors.gray)
            pxDisk(ctx, cx, cy, math.max(2, r * 0.35), colors.gray)
        end
    end

    local function makeMoleTile(idx, col, row)
        local tx = gx0 + col * (cellW + 1)
        local ty = gy0 + row * (cellH + 1)
        local fd = app:createFreeDraw({
            x = tx, y = ty, width = cellW, height = cellH,
            bg = colors.lightGray,
            clear = false,
            onDraw = function(self, ctx)
                drawMoleTile(ctx, active == idx)
            end,
        })
        function fd:handleEvent(event, _a, px, py)
            if event == "monitor_touch" or event == "mouse_click" then
                if not self:containsPoint(px, py) then return false end
                if not running then return true end
                if active == idx then
                    score = score + 1
                    active = math.random(gridCols * gridRows)
                else
                    score = math.max(0, score - 1)
                end
                scoreLabel.text = "Score: " .. score
                return true
            end
            return false
        end
        p.frame:addChild(fd)
        return fd
    end

    for row = 0, gridRows - 1 do
        for col = 0, gridCols - 1 do
            local idx = row * gridCols + col + 1
            tiles[idx] = makeMoleTile(idx, col, row)
        end
    end

    local startBtn = app:createButton({
        x = math.floor(W / 2) - 12, y = H - startH + 1,
        width = 24, height = startH,
        label = "Start Round", bg = colors.lime, fg = colors.black,
        onClick = function()
            if running then return end
            score = 0
            timeLeft = 20
            running = true
            active = math.random(gridCols * gridRows)
            scoreLabel.text = "Score: 0"
            timeLabel.text = "Time left: " .. timeLeft .. "s"
            timeLabel.fg = colors.white
        end,
    })
    p.frame:addChild(startBtn)

    app:spawnThread(function(ctx)
        while not ctx:isCancelled() do
            if running and currentPanel == "mole" then
                timeLeft = timeLeft - 1
                if timeLeft <= 0 then
                    running = false
                    active = -1
                    timeLabel.text = "Round over! Final score: " .. score
                    timeLabel.fg = colors.yellow
                else
                    if math.random() < 0.55 then
                        active = math.random(gridCols * gridRows)
                    end
                    timeLabel.text = "Time left: " .. timeLeft .. "s"
                    timeLabel.fg = timeLeft <= 5 and colors.red or colors.white
                end
            end
            ctx:sleep(1.0)
        end
    end, { name = "mole-tick" })
end

--------------------------------------------------------------------
-- START
--------------------------------------------------------------------
showPanel("menu")

local ok, err = pcall(function() app:run() end)

if prevTerm then term.redirect(prevTerm) end
if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Arcade closed.")
if not ok then printError(err) end
