# parallel

Run multiple coroutines concurrently. Each function gets its own coroutine; the API pumps events to all of them.

- `parallel.waitForAny(...funcs)` - returns when ANY function returns or errors. Returns the index of the finishing function.
- `parallel.waitForAll(...funcs)` - returns when ALL functions return.

Each function may yield (e.g., `os.pullEvent`, `sleep`, `read`, http handles). Errors in any function propagate.

## Pattern: animation loop + input
```lua
local function tick()
    while true do redraw(); sleep(0.1) end
end
local function input()
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.q then return end
    end
end
parallel.waitForAny(tick, input)
```

## Pattern: HTTP + spinner
```lua
local result
local function fetch() result = http.get(url) end
local function spinner()
    while result == nil do io.write("."); sleep(0.2) end
end
parallel.waitForAll(fetch, spinner)
```
