# pixelui (vendored, v0.1.0)

Widget framework on top of shrekbox. Loaded with `local pixelui = require("pixelui")`.

See also: `pixelui-widgets` (full widget reference), `pixelui-freedraw` (custom drawing + quirks).

## App lifecycle

```lua
local pixelui = require("pixelui")
local app = pixelui.create({ background = colors.black })  -- or no args
-- build widgets, app.root:addChild(...)
app:run()                                                   -- blocks until stop
```

### `pixelui.create(opts?)` -> `app`
Opts table (all optional):
- `window` - target window or term-like object.  If omitted, wraps `term.current()` in a fresh window covering the full screen.
- `background` - root bg color (default `colors.black`).
- `rootBorder` - `{ color, sides = {"top","right","bottom","left"}?, thickness? }`.
- `animationInterval` - animation tick in seconds (default 0.05).

### App methods
- `app.root` - root Frame (attach widgets with `app.root:addChild(w)`).
- `app.window` - underlying window.
- `app.box` - underlying ShrekBox.
- `app:getRoot()` / `app:setBackground(color)`.
- `app:getLayer()` - text layer.  `app:getPixelLayer()` - pixel layer.
- `app:run()` - blocking event loop.
- `app:stop()` - exit the loop.
- `app:render()` - force one frame render.
- `app:step(event, ...)` - process one event (used internally by run).
- `app:setFocus(widget)` / `app:getFocus()`.
- `app:animate(opts)` -> handle - see Animations.
- `app:spawnThread(fn, opts?)` -> handle - see Threads.
- Widget factories: `app:createFrame`, `:createWindow`, `:createDialog`, `:createMsgBox`, `:createButton`, `:createLabel`, `:createCheckBox`, `:createToggle`, `:createTextBox`, `:createComboBox`, `:createTabControl`, `:createContextMenu`, `:createList`, `:createTable`, `:createTreeView`, `:createChart`, `:createRadioButton`, `:createProgressBar`, `:createNotificationToast`, `:createLoadingRing`, `:createFreeDraw`, `:createSlider`.  Full reference in `pixelui-widgets`.

## Common widget config

Every widget accepts:

```lua
{
    x, y,           -- position (1-based) relative to parent
    width, height,  -- size in CHARACTERS (not pixels)
    bg, fg,         -- PixelUI.Color values from `colors` module
    visible,        -- bool (default true)
    focusable,      -- bool
    z,              -- order index within parent (higher = drawn last / on top)
    border = { color, sides = {"top","right","bottom","left"}?, thickness = 1 },
    constraints,    -- alignment/dimension constraints (optional, advanced)
}
```

Adding a widget: `parent:addChild(widget)`.  Parent is `app.root` or any Frame.

Widget methods common to all:
- `:setVisible(bool)`, `:isVisible()`.
- `:getAbsoluteRect()` -> `x, y, width, height` (absolute screen coords in chars).
- `:containsPoint(x, y)` -> bool.
- `:handleEvent(event, ...)` -> consumed:bool (override to customize).

## Animations

```lua
local handle = app:animate({
    duration = 1.0,
    easing   = "easeOutQuad",   -- or a function(t) -> t
    update   = function(progress, rawProgress)
        widget.x = 5 + math.floor(30 * progress)
    end,
    onComplete = function() print("done") end,
    onCancel   = function() end,
})
handle:cancel()   -- stop mid-way
```

Available easing names: `linear`, `easeInQuad`, `easeOutQuad`, `easeInOutQuad`, `easeOutCubic`, plus a dozen more (see `pixelui.easings`).

## Threads

Background coroutines that cooperate with the UI event loop.

```lua
local handle = app:spawnThread(function(ctx, app)
    for i = 1, 100 do
        if ctx:isCancelled() then return end
        ctx:setMetadata("progress", i / 100)
        ctx:sleep(0.1)
    end
end, { name = "worker" })
handle:cancel()
```

`ctx` (PixelUI.ThreadContext):
- `ctx:sleep(seconds)` - yield for `seconds`, then resume.
- `ctx:yield()` - yield immediately.
- `ctx:isCancelled()` / `ctx:checkCancelled()`.
- `ctx:setMetadata(key, value)`, `ctx:setStatus(text)`, `ctx:setDetail(text)`, `ctx:setProgress(0..1)`.
- `ctx:getHandle()` -> handle.

`handle` (PixelUI.ThreadHandle):
- `:getStatus()` -> `"running"|"completed"|"error"|"cancelled"`.
- `:isRunning()`, `:isFinished()`, `:isCancelled()`.
- `:cancel()`.
- `:getResult()` (blocks), `:getResults()` (array), `:getError()`.
- `:setName(s)`, `:getName()`, `:getId()`.
- `:getMetadata(k)`, `:setMetadata(k, v)`, `:getAllMetadata()`.
- `:onStatusChange(cb)`, `:onMetadataChange(cb)`.

**Caveat**: threads resume on the UI's animation timer, not arbitrary `os.pullEvent`.  Don't call `os.pullEvent` inside a thread - you'll steal events from the event loop.  Use `ctx:sleep` and poll state instead.

## Focus and input events

- `key`, `key_up`, `char`, `paste` - routed to the focused widget first.
- `mouse_click`, `mouse_up`, `mouse_drag`, `mouse_scroll`, `monitor_touch` - dispatched through the widget tree (top-most matching widget first, reverse z-order).
- Root handles the event if no child consumed it.
- Clicking outside the focused widget clears focus.

To override on a custom widget:
```lua
local prev = widget.handleEvent
function widget:handleEvent(event, ...)
    if event == "mouse_click" then ... return true end
    return prev(self, event, ...)
end
```

Use `widget:containsPoint(x, y)` + `widget:getAbsoluteRect()` to translate absolute mouse coords to widget-local.

## Visual aspect ratio

CC character cells are ~2:3 (width:height) in screen pixels.  For a visually square cell, use `width = round(height * 1.5)`.  This matters for tic-tac-toe grids, whack-a-mole buttons, etc.

## Minimal example

```lua
local pixelui = require("pixelui")
local app = pixelui.create({ background = colors.black })

app.root:addChild(app:createLabel({
    x = 2, y = 2, width = 20, height = 1,
    text = "Hello PixelUI!", fg = colors.yellow,
}))

app.root:addChild(app:createButton({
    x = 2, y = 4, width = 14, height = 3,
    label = "Quit", bg = colors.red, fg = colors.white,
    onClick = function() app:stop() end,
}))

app:run()
```

## Monitor output

To render on a monitor instead of the computer terminal, redirect the term first:

```lua
local m = peripheral.find("monitor")
m.setTextScale(0.5)
local prev = term.redirect(m)
local app = pixelui.create({ background = colors.black })
-- ...
app:run()
term.redirect(prev)
```

Touch events (`monitor_touch`) are dispatched to widgets exactly like `mouse_click`.
