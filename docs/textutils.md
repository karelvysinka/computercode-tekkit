# textutils

Text/data formatting helpers.

## Display
- `textutils.slowWrite(text, rate?)` / `textutils.slowPrint(text, rate?)`.
- `textutils.pagedPrint(text, freeLines?)` - paginated; returns line count.
- `textutils.tabulate(...)` / `textutils.pagedTabulate(...)` - print arrays of strings as columns; pass color values to recolor.
- `textutils.formatTime(time, twentyFourHour?)` -> "12:34 PM".
- `textutils.complete(text, choices)` -> table of completions starting with `text`.

## Serialization
- `textutils.serialize(value [, opts])` / alias `textutils.serialise` -> Lua-source string. opts: `{ compact=true, allow_repetitions=true }`.
- `textutils.unserialize(s)` / alias `textutils.unserialise` -> value, or nil on error.
- `textutils.serializeJSON(value [, opts])` -> JSON string. opts: `{ nbt_style=true, unicode_strings=true, allow_repetitions=true }`.
- `textutils.unserializeJSON(s [, opts])` -> value, or nil. opts: `{ nbt_style=true, parse_null=true, parse_empty_array=false }`. Pass `parse_empty_array=false` so empty JSON `[]` becomes a real array.
- `textutils.urlEncode(s)` -> URL-safe string.

## JSON gotchas
- Lua tables with all-numeric keys serialize as JSON arrays only if 1..n contiguous; otherwise as objects.
- A literal `textutils.json_null` round-trips JSON `null`.
- A literal `textutils.empty_json_array` is a sentinel for `[]`.

## Pattern: send/receive JSON
```lua
local body = textutils.serializeJSON({ a = 1, b = "x" })
local resp = http.post(url, body, { ["Content-Type"] = "application/json" })
local data = textutils.unserializeJSON(resp.readAll())
```
