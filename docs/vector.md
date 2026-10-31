# vector

3D vector math, useful with `gps.locate()` and turtle navigation.

- `vector.new(x, y, z)` -> vector.

Vector methods (call with `:`):
- `:add(other)` / `:sub(other)` / `:mul(scalar)` / `:div(scalar)` / `:unm()` (negate).
- `:dot(other)` / `:cross(other)`.
- `:length()` -> number.
- `:normalize()` -> unit vector.
- `:round([tolerance])` -> rounded vector.
- `:tostring()` -> "x, y, z".

Operator overloads work too: `a + b`, `a - b`, `a * 2`, `-a`, `a == b`, `tostring(a)`.

Fields: `.x`, `.y`, `.z`.

## Pattern
```lua
local home = vector.new(gps.locate(2))
local dest = vector.new(100, 64, 200)
local delta = (dest - home):round()
print("travel: " .. delta:length() .. " blocks")
```
