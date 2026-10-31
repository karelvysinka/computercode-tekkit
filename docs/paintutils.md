# paintutils

Simple shape-drawing helpers on top of `term`. Coordinates are character cells. Each "pixel" is one character cell (use `term.blit` or PixelUI for finer control).

- `paintutils.drawPixel(x, y, color?)` — sets the cell to a colored space.
- `paintutils.drawLine(x1, y1, x2, y2, color?)` — Bresenham line.
- `paintutils.drawBox(x1, y1, x2, y2, color?)` — outlined rectangle.
- `paintutils.drawFilledBox(x1, y1, x2, y2, color?)` — filled rectangle.
- `paintutils.parseImage(text)` -> image — parses `paint`-format string (each char is a hex color digit; rows separated by newlines).
- `paintutils.loadImage(path)` -> image (or nil).
- `paintutils.drawImage(image, x, y)` — draws a parsed image at top-left.

If `color` is omitted on draw functions, the current `term.getBackgroundColor()` is used.

## Pattern: full-screen background
```lua
local w, h = term.getSize()
paintutils.drawFilledBox(1, 1, w, h, colors.blue)
```

## Pattern: draw a saved .nfp image
```lua
local img = paintutils.loadImage("logo.nfp")
paintutils.drawImage(img, 1, 1)
```

`.nfp` files are the format produced by the built-in `paint` program.
