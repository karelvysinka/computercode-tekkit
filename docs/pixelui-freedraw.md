# pixelui-freedraw (custom drawing + helpers)

FreeDraw is a raw rendering surface.  Use it when:
- Built-in widgets aren't flexible enough (games, scenes, custom charts, etc.).
- You need sub-character resolution (2 wide x 3 tall pixels per character cell).

## Basic usage

```lua
local fd = app:createFreeDraw({
    x=2, y=2, width=20, height=8,
    bg = colors.black,
    onDraw = function(self, ctx)
        ctx.fill(colors.gray)
        ctx.write(1, 1, "title", colors.white, colors.gray)
    end,
})
app.root:addChild(fd)
```

The `ctx` object is passed fresh to every render call.  Fields:

| field | description |
|---|---|
| `ctx.app` | owning App |
| `ctx.box` | underlying ShrekBox |
| `ctx.textLayer` | shared text layer |
| `ctx.pixelLayer` | shared pixel layer (2x3 per char) |
| `ctx.x`, `ctx.y` | absolute character position of the widget |
| `ctx.width`, `ctx.height` | widget size in characters |
| `ctx.fill(color)` | fill the widget region with `color` (writes to text layer) |
| `ctx.write(x, y, text, fg?, bg?)` | 1-based widget-local character coords |
| `ctx.pixel(x, y, color)` | **DO NOT USE** - see gotcha below |

## IMPORTANT: `ctx.pixel` is buggy in 0.1.0

The library claims `ctx.pixel(x, y, color)` sets a high-resolution subpixel (2 per char wide, 3 per char tall), but internally it clips against `width`/`height` which are in CHARACTER units and passes the coords unconverted to the pixel layer.  The effect: almost every pixel call gets clipped, and the few that don't land in wildly wrong positions.  Results look like "weird squiggles" in the top-left of the widget.

**Bypass it** and write directly to `ctx.pixelLayer.pixel(absX, absY, color)` with correct conversions.

## Text layer covers pixel layer

Another gotcha: the text layer renders ABOVE the pixel layer, and the parent Frame fills its text-layer region with a solid color before children draw.  So any pixels you draw will be hidden behind the text layer unless you clear those cells to transparent.

To clear a text-layer cell, call `ctx.textLayer.pixel(x, y, shrekbox.transparent)` where `shrekbox.transparent == 0`.

Also: set `clear = false` in the FreeDraw config, otherwise PixelUI will re-fill the text layer with the widget's bg every frame (re-hiding the pixels).

## Correct pixel-drawing helpers

Copy these into your script (used in `infopad.lua` and `computercode/monitor.lua`):

```lua
local shrekbox = require("shrekbox")
local TRANSPARENT = shrekbox.transparent   -- 0

-- Clear the text layer covering this FreeDraw (so pixel layer shows through)
-- and fill the pixel layer with bg.
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

-- Set a single pixel at widget-local pixel coords (1..ctx.width*2, 1..ctx.height*3).
local function pxSet(ctx, x, y, color)
    local pw, ph = ctx.width * 2, ctx.height * 3
    if x < 1 or x > pw or y < 1 or y > ph then return end
    ctx.pixelLayer.pixel((ctx.x - 1) * 2 + x, (ctx.y - 1) * 3 + y, color)
end

-- Filled circle (disk) at (cx, cy) with radius r, in widget-local pixel space.
-- Subpixels are square in SCREEN space, so equal rx/ry gives a true circle.
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

-- Hollow ring with given thickness.
local function pxRing(ctx, cx, cy, r, thickness, color)
    local rOut2 = r * r
    local rIn2  = (r - thickness) * (r - thickness)
    for py = math.floor(cy - r), math.ceil(cy + r) do
        for px = math.floor(cx - r), math.ceil(cx + r) do
            local dx, dy = px - cx, py - cy
            local d2 = dx * dx + dy * dy
            if d2 <= rOut2 and d2 >= rIn2 then
                pxSet(ctx, px, py, color)
            end
        end
    end
end

-- Filled rectangle in pixel space.
local function pxRect(ctx, x, y, w, h, color)
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            pxSet(ctx, x + dx, y + dy, color)
        end
    end
end

-- Bresenham-style line.
local function pxLine(ctx, x1, y1, x2, y2, color)
    local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
    if steps == 0 then pxSet(ctx, x1, y1, color); return end
    for i = 0, steps do
        local t = i / steps
        pxSet(ctx, math.floor(x1 + (x2 - x1) * t + 0.5),
                   math.floor(y1 + (y2 - y1) * t + 0.5),
                   color)
    end
end
```

## Full example: drawing a big red X

```lua
local shrekbox = require("shrekbox")
local TRANSPARENT = shrekbox.transparent
-- ... (paste pxBegin, pxSet, pxLine helpers above)

local fd = app:createFreeDraw({
    x = 5, y = 3, width = 9, height = 6,
    bg = colors.white,
    clear = false,                      -- MUST disable auto-clear
    onDraw = function(self, ctx)
        pxBegin(ctx, colors.white)      -- clear text, paint white bg
        local pw, ph = ctx.width * 2, ctx.height * 3
        local m = 2
        pxLine(ctx, m, m, pw - m, ph - m, colors.red)
        pxLine(ctx, pw - m, m, m, ph - m, colors.red)
    end,
})
app.root:addChild(fd)
```

## Custom click handling

FreeDraws don't react to clicks by default.  Override `handleEvent` to respond:

```lua
function fd:handleEvent(event, _a, px, py)
    if event == "mouse_click" or event == "monitor_touch" then
        if not self:containsPoint(px, py) then return false end
        local ax, ay = self:getAbsoluteRect()
        local cellX = px - ax + 1          -- widget-local character coords
        local cellY = py - ay + 1
        -- ... do something, trigger a redraw
        self.app:render()
        return true
    end
    return false
end
```

## Subpixel <-> character conversion cheat sheet

Widget at character position `(ctx.x, ctx.y)`, size `(ctx.width, ctx.height)` chars:

| what | formula |
|---|---|
| first pixel x (absolute) | `(ctx.x - 1) * 2 + 1` |
| first pixel y (absolute) | `(ctx.y - 1) * 3 + 1` |
| pixel grid width | `ctx.width * 2` |
| pixel grid height | `ctx.height * 3` |
| pixel -> character (x) | `math.ceil(px / 2)` |
| pixel -> character (y) | `math.ceil(py / 3)` |

Characters are visually taller than wide (~2:3 in screen pixels), but subpixels themselves are SQUARE in screen space (each is ~3x3 screen pixels).  So an ellipse drawn with equal `rx` and `ry` in pixel space looks like a circle on screen.
