-- Park scene with moving people for a 5x3 combined monitor.
-- Press Q on the computer keyboard to stop.

-- Prefer a monitor on top of the computer; fall back to any side / network-attached.
local function findPreferredMonitor()
    for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
        if peripheral.getType(side) == "monitor" then
            return peripheral.wrap(side)
        end
    end
    return peripheral.find("monitor")
end
local monitor = findPreferredMonitor()
if not monitor then
    error("No monitor peripheral found. Attach or `monitor combine` a 5x3 array.", 0)
end

monitor.setTextScale(0.5)
local prevTerm = term.redirect(monitor)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()

local W, H = term.getSize()

local BLIT = {
    [colors.white]     = "0", [colors.orange]    = "1",
    [colors.magenta]   = "2", [colors.lightBlue] = "3",
    [colors.yellow]    = "4", [colors.lime]      = "5",
    [colors.pink]      = "6", [colors.gray]      = "7",
    [colors.lightGray] = "8", [colors.cyan]      = "9",
    [colors.purple]    = "a", [colors.blue]      = "b",
    [colors.brown]     = "c", [colors.green]     = "d",
    [colors.red]       = "e", [colors.black]     = "f",
}
local function toBlit(c) return BLIT[c] or "f" end

local fbText, fbFG, fbBG = {}, {}, {}

local function clearFB(bgColor)
    local bg = toBlit(bgColor)
    local tRow = string.rep(" ", W)
    local fRow = string.rep("0", W)
    local bRow = string.rep(bg, W)
    for y = 1, H do
        fbText[y] = tRow
        fbFG[y]   = fRow
        fbBG[y]   = bRow
    end
end

local function setCell(x, y, ch, fg, bg)
    x = math.floor(x); y = math.floor(y)
    if x < 1 or x > W or y < 1 or y > H then return end
    local f = toBlit(fg)
    local b = toBlit(bg)
    fbText[y] = fbText[y]:sub(1, x - 1) .. ch .. fbText[y]:sub(x + 1)
    fbFG[y]   = fbFG[y]:sub(1,   x - 1) .. f  .. fbFG[y]:sub(x + 1)
    fbBG[y]   = fbBG[y]:sub(1,   x - 1) .. b  .. fbBG[y]:sub(x + 1)
end

local function setPixel(x, y, color)
    setCell(x, y, " ", color, color)
end

local function fillRect(x1, y1, x2, y2, color)
    x1 = math.max(1, math.floor(x1))
    x2 = math.min(W, math.floor(x2))
    y1 = math.max(1, math.floor(y1))
    y2 = math.min(H, math.floor(y2))
    if x1 > x2 or y1 > y2 then return end
    local bg = toBlit(color)
    local width = x2 - x1 + 1
    local spaces = string.rep(" ", width)
    local bgRow  = string.rep(bg, width)
    local fgRow  = string.rep("0", width)
    for y = y1, y2 do
        fbText[y] = fbText[y]:sub(1, x1 - 1) .. spaces .. fbText[y]:sub(x2 + 1)
        fbFG[y]   = fbFG[y]:sub(1,   x1 - 1) .. fgRow  .. fbFG[y]:sub(x2 + 1)
        fbBG[y]   = fbBG[y]:sub(1,   x1 - 1) .. bgRow  .. fbBG[y]:sub(x2 + 1)
    end
end

local function fillCircle(cx, cy, r, color)
    for y = -r, r do
        local span = math.floor(math.sqrt(r * r - y * y) + 0.5)
        fillRect(cx - span, cy + y, cx + span, cy + y, color)
    end
end

local function writeText(x, y, text, fg, bg)
    for i = 1, #text do
        setCell(x + i - 1, y, text:sub(i, i), fg, bg)
    end
end

local function flush()
    for y = 1, H do
        term.setCursorPos(1, y)
        term.blit(fbText[y], fbFG[y], fbBG[y])
    end
end

local HORIZON  = math.floor(H * 0.55)
local PATH_TOP = math.floor(H * 0.72)
local PATH_BOT = math.floor(H * 0.83)

local function rand(a, b) return a + math.random() * (b - a) end

local shirtColors = { colors.red, colors.blue, colors.purple, colors.magenta,
                      colors.cyan, colors.lime, colors.orange, colors.lightBlue }
local pantsColors = { colors.blue, colors.gray, colors.brown, colors.black }
local skinColors  = { colors.orange, colors.yellow, colors.pink, colors.white }

math.randomseed(os.epoch("utc"))

local people = {}
for i = 1, 10 do
    people[#people + 1] = {
        x = rand(1, W),
        y = rand(PATH_TOP, PATH_BOT - 2),
        dir = math.random() < 0.5 and 1 or -1,
        speed = rand(0.15, 0.35),
        step = rand(0, 10),
        shirt = shirtColors[math.random(#shirtColors)],
        pants = pantsColors[math.random(#pantsColors)],
        skin  = skinColors[math.random(#skinColors)],
        hat   = math.random() < 0.4 and shirtColors[math.random(#shirtColors)] or nil,
    }
end

local clouds = {}
for i = 1, 5 do
    clouds[#clouds + 1] = {
        x = rand(1, W),
        y = rand(2, math.max(3, HORIZON - 6)),
        w = math.random(4, 7),
        speed = rand(0.05, 0.12),
    }
end

local trees = {}
for i, rel in ipairs({ 0.08, 0.22, 0.65, 0.88 }) do
    trees[i] = {
        x = math.max(3, math.floor(W * rel)),
        baseY = PATH_TOP - 1,
        leafR = math.random(2, 3),
    }
end

local function drawSky()
    for y = 1, HORIZON do
        local color = colors.lightBlue
        if y <= math.floor(HORIZON * 0.35) then color = colors.cyan end
        fillRect(1, y, W, y, color)
    end
end

local function drawGround()
    fillRect(1, HORIZON + 1, W, H, colors.green)
    fillRect(1, math.floor((HORIZON + H) / 2), W, H, colors.lime)
    fillRect(1, PATH_TOP, W, PATH_BOT, colors.brown)
    for x = 2, W, 4 do
        setPixel(x, math.floor((PATH_TOP + PATH_BOT) / 2), colors.yellow)
    end
end

local function drawSun()
    fillCircle(W - 6, 3, 2, colors.yellow)
    setPixel(W - 6, 3, colors.orange)
end

local function drawCloud(c)
    local cx, cy = math.floor(c.x), math.floor(c.y)
    fillRect(cx - c.w,     cy,     cx + c.w, cy, colors.white)
    fillRect(cx - c.w + 1, cy - 1, cx + c.w - 1, cy - 1, colors.white)
    fillRect(cx - c.w + 2, cy + 1, cx + c.w - 2, cy + 1, colors.white)
end

local function drawTree(t)
    setPixel(t.x,     t.baseY,     colors.brown)
    setPixel(t.x,     t.baseY - 1, colors.brown)
    setPixel(t.x + 1, t.baseY,     colors.brown)
    setPixel(t.x + 1, t.baseY - 1, colors.brown)
    fillCircle(t.x,     t.baseY - 2 - t.leafR, t.leafR, colors.green)
    fillCircle(t.x + 1, t.baseY - 2 - t.leafR, t.leafR, colors.green)
    setPixel(t.x, t.baseY - 3 - t.leafR, colors.lime)
end

local function drawPerson(p)
    local x, y = math.floor(p.x), math.floor(p.y)
    if p.hat then
        setPixel(x,     y - 1, p.hat)
        setPixel(x + 1, y - 1, p.hat)
    end
    setPixel(x,     y, p.skin)
    setPixel(x + 1, y, p.skin)
    setPixel(x,     y + 1, p.shirt)
    setPixel(x + 1, y + 1, p.shirt)
    local phase = math.floor(p.step) % 2
    if phase == 0 then
        setPixel(x,     y + 2, p.pants)
    else
        setPixel(x + 1, y + 2, p.pants)
    end
end

local function render()
    clearFB(colors.black)
    drawSky()
    drawSun()
    for _, c in ipairs(clouds) do drawCloud(c) end
    drawGround()
    for _, t in ipairs(trees) do drawTree(t) end
    table.sort(people, function(a, b) return a.y < b.y end)
    for _, p in ipairs(people) do drawPerson(p) end
    writeText(2, 1, " Central Park - Press Q to quit ", colors.white, colors.gray)
    flush()
end

local running = true

local function animLoop()
    while running do
        for _, p in ipairs(people) do
            p.x = p.x + p.dir * p.speed
            p.step = p.step + p.speed
            if p.x < -3         then p.x = W + 2; p.dir =  1 end
            if p.x > W + 3      then p.x = -2;    p.dir = -1 end
        end
        for _, c in ipairs(clouds) do
            c.x = c.x + c.speed
            if c.x - c.w > W then c.x = -c.w end
        end
        render()
        sleep(0.1)
    end
end

local function inputLoop()
    while running do
        local event, key = os.pullEvent()
        if event == "key" and key == keys.q then
            running = false
            return
        elseif event == "terminate" then
            running = false
            return
        end
    end
end

local ok, err = pcall(parallel.waitForAny, animLoop, inputLoop)

if prevTerm then term.redirect(prevTerm) end
monitor.setBackgroundColor(colors.black)
monitor.clear()
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Park closed.")
if not ok then printError(err) end
