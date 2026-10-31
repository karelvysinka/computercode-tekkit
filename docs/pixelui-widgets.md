# pixelui-widgets (complete reference)

Every widget is created via `app:createX(config)` and attached with `parent:addChild(widget)`.  All widgets accept the common fields (`x`, `y`, `width`, `height`, `bg`, `fg`, `visible`, `focusable`, `z`, `border`) - only type-specific fields are listed below.

## Frame

Container.  Fills both layers with `bg`, draws children on top.

```lua
local f = app:createFrame({
    x=2, y=2, width=30, height=10,
    bg=colors.black,
    title="Optional title",         -- shown inside top border
    border={ color=colors.gray, sides={"top","right","bottom","left"} },
})
app.root:addChild(f)
f:addChild(innerWidget)
```

Fields: `title`, plus all common.

Methods: `:addChild(w)`, `:removeChild(w)`, `:clearChildren()`, `:getChildren()`, `:handleEvent(event, ...)`.

## Window

Draggable/resizable floating window extending Frame.

```lua
local w = app:createWindow({
    x=5, y=5, width=30, height=12,
    title = "Console",
    draggable = true,
    resizable = true,
    closable = true,
    maximizable = true,
    minimizable = true,
    hideBorderWhenMaximized = true,
    titleBar = { ... },             -- advanced, see source
    minimizedHeight = 2,
    onMinimize = function(win, isMin) end,
})
```

Methods: `:close()`, `:toggleMaximize()`, `:toggleMinimize()`, `:isMaximized()`, `:isMinimized()`.

## Dialog

Modal window; blocks interaction with widgets behind it.

```lua
local d = app:createDialog({
    x=10, y=5, width=30, height=10,
    modal = true,
    backdropColor = colors.black,    -- text-layer backdrop fill behind dialog
    backdropPixelColor = colors.gray,
    closeOnBackdrop = true,
    closeOnEscape = true,
    title = "Confirm",
})
```

Methods: same as Window.

## MsgBox

Dialog preloaded with a message and buttons.

```lua
app:createMsgBox({
    x=10, y=5, width=28, height=8,
    title = "Delete?",
    message = "Are you sure?",
    buttons = {
        { id="yes", label="Yes", onSelect=function() ... end },
        { id="no",  label="No", bg=colors.red },
    },
    buttonAlign = "center",   -- "left" | "center" | "right"
    autoClose = true,         -- close automatically after button press
})
```

## Button

Clickable.  Fires onClick on release after a press inside the widget.

```lua
app:createButton({
    x=2, y=2, width=12, height=3,
    label = "Click me",
    bg = colors.blue, fg = colors.white,
    clickEffect = true,                          -- bg/fg swap while pressed
    onPress   = function(self, button, x, y) end,
    onRelease = function(self, button, x, y) end,
    onClick   = function(self, button, x, y) end,
})
```

Methods: `:setLabel(text)`, `:setOnClick(fn)`.

## Label

Static text.  Handles wrapping + alignment.

```lua
app:createLabel({
    x=2, y=2, width=30, height=3,
    text = "Long text that\nwraps nicely",
    align = "center",         -- "left"|"center"|"right"
    verticalAlign = "middle", -- "top"|"middle"|"bottom"
    wrap = true,
    fg = colors.yellow, bg = colors.black,
})
```

Methods: `:setText(text)`.

Mutating `.text`, `.fg`, or `.bg` directly also works; change shows up on next render.

## CheckBox

```lua
app:createCheckBox({
    x=2, y=2, width=20, height=1,
    label = "Enable logs",
    checked = false,
    indeterminate = false,
    allowIndeterminate = false,
    focusBg = colors.lightGray, focusFg = colors.black,
    onChange = function(self, checked, indeterminate) end,
})
```

Methods: `:setChecked(bool)`, `:toggle()`, `:setIndeterminate(bool)`.

## Toggle

Animated on/off switch.

```lua
app:createToggle({
    x=2, y=2, width=16, height=1,
    value = false,
    labelOn = "ON", labelOff = "OFF",
    trackColorOn = colors.lime, trackColorOff = colors.gray,
    thumbColor = colors.white,
    showLabel = true,
    disabled = false,
    transitionDuration = 0.2,
    onChange = function(self, value) end,
})
```

Methods: `:setValue(bool)`, `:toggle()`, `:setDisabled(bool)`.

## RadioButton

Exclusive-choice button.  Group members share `group` string.

```lua
for i, opt in ipairs({"red","green","blue"}) do
    app.root:addChild(app:createRadioButton({
        x=2, y=i+1, width=14, height=1,
        label = opt, group = "color", value = opt,
        selected = (i == 1),
        onChange = function(self, selected, value) end,
    }))
end
```

Methods: `:select()` (picks this one in its group).

## TextBox

Text editor - single-line or multiline.  Supports autocomplete, syntax highlighting, scrolling.

```lua
local tb = app:createTextBox({
    x=2, y=2, width=40, height=8,
    text = "",
    placeholder = "type here...",
    multiline = true,
    maxLength = 1000,
    autocomplete = { "foo", "bar", "baz" },
    autocompleteMaxItems = 5,
    autocompleteGhostColor = colors.gray,
    syntax = { ... },         -- optional, see source
    onChange    = function(self, text) end,
    onCursorMove = function(self, line, col) end,
})
```

Methods:
- `:getText()`, `:setText(s)`.
- `:setOnChange(fn)`.
- `:insertText(s)`, `:setCursor(line, col)`, `:getCursor()`.
- `:clear()`.

## ComboBox

Dropdown select.

```lua
app:createComboBox({
    x=2, y=2, width=20, height=1,
    items = {"Small", "Medium", "Large"},
    selectedIndex = 1,
    placeholder = "pick one",
    dropdownBg = colors.gray, dropdownFg = colors.white,
    highlightBg = colors.blue, highlightFg = colors.white,
    onChange = function(self, item, index) end,
})
```

## List

Scrollable selectable list.

```lua
app:createList({
    x=2, y=2, width=20, height=8,
    items = { "Alpha", "Beta", "Gamma" },
    selectedIndex = 1,
    highlightBg = colors.blue, highlightFg = colors.white,
    placeholder = "(empty)",
    scrollbar = { enabled = true },
    onSelect = function(self, item, index) end,
})
```

Methods: `:setItems(items)`, `:addItem(s)`, `:removeItem(index)`, `:clear()`, `:getSelected()`, `:setSelectedIndex(i)`.

## Table

Data table with column definitions, sortable, selectable rows.

```lua
app:createTable({
    x=2, y=2, width=40, height=10,
    columns = {
        { id="name",  title="Name",  key="name",  width=12, sortable=true },
        { id="count", title="Count", accessor=function(r) return r.items end, align="right" },
    },
    data = {
        { name = "Alice", items = 3 },
        { name = "Bob",   items = 7 },
    },
    sortColumn = "count", sortDirection = "desc",
    allowRowSelection = true,
    onSelect = function(self, row, index) end,
    onSort   = function(self, columnId, dir) end,
})
```

Column fields: `id`, `title`, `key` OR `accessor`, `width`, `align`, `sortable`, `format(value,row,col)`, `comparator(a,b,aRow,bRow,col)`.

## TreeView

Hierarchical tree.  Nodes are `{ label, data?, children? = {...}, expanded? }`.

```lua
app:createTreeView({
    x=2, y=2, width=24, height=10,
    nodes = {
        { label = "src", expanded = true, children = {
            { label = "main.lua" },
            { label = "util",   children = { { label="log.lua" } } },
        }},
        { label = "docs" },
    },
    indentWidth = 2,
    highlightBg = colors.blue, highlightFg = colors.white,
    onSelect = function(self, node, index) end,
    onToggle = function(self, node, expanded) end,
})
```

## Chart

Bar or line chart.

```lua
app:createChart({
    x=2, y=2, width=40, height=10,
    chartType = "bar",              -- "bar" | "line"
    data = { 3, 7, 1, 5, 9 },
    labels = { "Mon","Tue","Wed","Thu","Fri" },
    minValue = 0, maxValue = 10,    -- auto if nil
    showAxis = true, showLabels = true,
    barColor = colors.blue,
    highlightColor = colors.yellow,
    axisColor = colors.gray,
    selectable = true,
    onSelect = function(self, index, value) end,
})
```

## Slider

Single or range slider.

```lua
app:createSlider({
    x=2, y=2, width=20, height=1,
    min=0, max=100, value=50, step=1,
    showValue = true,
    onChange = function(self, v) end,
    formatValue = function(self, v) return v .. "%" end,
})

-- Range mode:
app:createSlider({
    x=2, y=4, width=20, height=1,
    range = true,
    min=0, max=100, lowerValue=20, upperValue=80,
    onChange = function(self, lo, hi) end,
})
```

## ProgressBar

```lua
local pb = app:createProgressBar({
    x=2, y=2, width=30, height=1,
    min=0, max=1, value=0,
    label = "Downloading",
    showPercent = true,
    trackColor = colors.gray, fillColor = colors.lime, textColor = colors.white,
    indeterminate = false,    -- animated sweep if true
})
pb.value = 0.6  -- update; next render reflects it
```

## NotificationToast

Self-dismissing toast for temporary messages.

```lua
app.root:addChild(app:createNotificationToast({
    x=2, y=2, width=30, height=3,
    title = "Saved",
    message = "hello.lua written",
    severity = "success",    -- "info"|"success"|"warning"|"error"
    autoHide = true,
    duration = 3,
    dismissOnClick = true,
}))
```

## LoadingRing

Animated rotating segmented ring.

```lua
app:createLoadingRing({
    x=10, y=5, width=5, height=3,
    segmentCount = 8,
    thickness = 1,
    color = colors.cyan,
    secondaryColor = colors.lightBlue,
    trailColor = colors.gray,
    speed = 1.0,
    direction = 1,           -- 1 or -1
    radiusPixels = nil,      -- auto
    fadeSteps = 4,
    autoStart = true,
})
```

Methods: `:start()`, `:stop()`.

## TabControl

Tabs with a body area below.

```lua
app:createTabControl({
    x=2, y=2, width=40, height=10,
    tabs = {
        { id="h", label="Home",   content = "Welcome!" },
        { id="s", label="Settings" },
        { id="a", label="About",  disabled = true },
    },
    selectedIndex = 1,
    tabSpacing = 1, tabPadding = 2, tabHeight = 1,
    tabBg = colors.gray, tabFg = colors.white,
    activeTabBg = colors.blue, activeTabFg = colors.white,
    hoverTabBg = colors.lightGray,
    tabCloseButton = { enabled=true, char="x", spacing=1 },
    onSelect  = function(self, tab, index) end,
    onCloseTab = function(self, tab, index) return true end,
    bodyRenderer = function(self, tab, textLayer, pixelLayer, area)
        -- custom draw for the body
    end,
    emptyText = "no tabs",
})
```

Methods: `:addTab(tab)`, `:removeTab(index)`, `:setSelectedIndex(i)`, `:getSelectedTab()`.

## ContextMenu

Popup menu with optional submenus.

```lua
local m = app:createContextMenu({
    items = {
        { label="Open",  shortcut="Ctrl+O", value="open" },
        { label="Save",  shortcut="Ctrl+S", value="save", onSelect=function(menu, item) end },
        { separator = true },
        { label="Nested", submenu = {
            { label="Child 1", value="c1" },
            { label="Child 2", value="c2", disabled=true },
        }},
    },
    onSelect = function(self, item) end,
    maxWidth = 24,
})
m:openAt(x, y)   -- popup at screen coords
m:close()
```

## FreeDraw

Custom rendering surface.  See `pixelui-freedraw` for the full story (the widget has a known quirk with `ctx.pixel` you must work around).

```lua
app:createFreeDraw({
    x=2, y=2, width=20, height=8,
    bg = colors.black,
    clear = true,        -- whether to clear the text layer before onDraw
    onDraw = function(self, ctx)
        ctx.fill(colors.black)
        ctx.write(1, 1, "Hello", colors.white, colors.black)
    end,
})
```
