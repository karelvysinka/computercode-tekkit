# colors (alias colours)

16 fixed-palette colors used by term/monitor/PixelUI.

Each color is a power of 2 so they can be OR'd into bitmasks (used by bundled redstone, etc.).

| name | value |
|---|---|
| white | 1 |
| orange | 2 |
| magenta | 4 |
| lightBlue | 8 |
| yellow | 16 |
| lime | 32 |
| pink | 64 |
| gray | 128 |
| lightGray | 256 |
| cyan | 512 |
| purple | 1024 |
| blue | 2048 |
| brown | 4096 |
| green | 8192 |
| red | 16384 |
| black | 32768 |

## Helpers
- `colors.combine(a, b, ...)` -> bitmask.
- `colors.subtract(mask, c, ...)`.
- `colors.test(mask, c)` -> bool.
- `colors.toBlit(c)` -> single hex char ("0".."f") for `term.blit`.
- `colors.fromBlit("a")` -> color value.
- `colors.packRGB(r,g,b)` / `colors.unpackRGB(rgb)` - 0..1 floats.
- `colors.rgb8(r,g,b)` / equivalent.

Note: in CC, basic computers have only black/white/grays. Use `term.isColor()` to check.
