# fs (filesystem)

Paths are forward-slash, root is `/`. Programs typically use relative paths in the current shell dir.

## Listing / inspection
- `fs.list(path)` -> array of file names (no directory prefix). Errors if path doesn't exist.
- `fs.exists(path)` -> bool.
- `fs.isDir(path)` -> bool.
- `fs.isReadOnly(path)` -> bool.
- `fs.getSize(path)` -> number of bytes.
- `fs.getDrive(path)` -> "hdd", "rom", "disk_0", etc.
- `fs.getFreeSpace(path)` / `fs.getCapacity(path)`.
- `fs.find(wildcardPath)` -> matches with `*`.
- `fs.getDir(path)` / `fs.getName(path)` - dirname / basename.
- `fs.combine(base, ...)` - safe join (handles `..`).
- `fs.attributes(path)` -> `{ size, isDir, isReadOnly, created, modified }`.

## Mutation
- `fs.makeDir(path)` - creates parents too.
- `fs.move(from, to)` / `fs.copy(from, to)`.
- `fs.delete(path)` - recursive.

## Open
- `fs.open(path, mode)` -> handle, or nil + reason.
  Modes: `"r"` (read text), `"w"` (write text, truncates), `"a"` (append text), `"rb"`/`"wb"`/`"ab"` (binary).
- Read handle: `:readLine()`, `:readAll()`, `:read(count?)`, `:close()`.
- Write/append handle: `:write(text)`, `:writeLine(text)`, `:flush()`, `:close()`.

## Pattern: read + write
```lua
local f = fs.open("data.txt", "r"); local s = f.readAll(); f.close()
local g = fs.open("data.txt", "w"); g.write(s:upper()); g.close()
```
