# redstone (alias rs)

Read and emit redstone signals on each side ("top", "bottom", "left", "right", "front", "back").

## Digital
- `redstone.getInput(side)` -> bool.
- `redstone.setOutput(side, on)`.
- `redstone.getOutput(side)` -> bool.
- `redstone.getSides()` -> array of side names.

## Analog (signal strength 0..15)
- `redstone.getAnalogInput(side)`.
- `redstone.setAnalogOutput(side, n)` (0..15).
- `redstone.getAnalogOutput(side)`.

## Bundled cables (mod-dependent)
- `redstone.getBundledInput(side)` -> bitmask.
- `redstone.setBundledOutput(side, bitmask)`.
- `redstone.testBundledInput(side, color)` -> bool.

## Event
A `redstone` event fires whenever any input changes; it has no parameters - poll with `getInput`.

## Pattern: blink top
```lua
while true do
    rs.setOutput("top", true);  sleep(0.5)
    rs.setOutput("top", false); sleep(0.5)
end
```
