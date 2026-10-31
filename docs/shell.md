# shell

The CraftOS shell. Available inside any program launched from the shell.

## Working directory
- `shell.dir()` -> current dir (string).
- `shell.setDir(path)` — change cwd.

## Path
- `shell.path()` -> ":-separated search path for programs.
- `shell.setPath(path)`.
- `shell.resolve(path)` -> absolute path (handles `..`, prefixes cwd).
- `shell.resolveProgram(name)` -> full path of a program in the search path, or nil.

## Running programs
- `shell.run(command, ...)` -> bool success. Concatenates args with spaces; runs as if typed. Output goes to current term.
- `shell.execute(programPath, ...)` -> bool — runs without parsing as shell command.
- `shell.openTab(command, ...)` -> tabId — open in a new multishell tab (only with multishell).
- `shell.switchTab(id)`.
- `shell.exit()` — quit the current shell.

## Aliases & completion
- `shell.aliases()` -> table.
- `shell.setAlias(alias, program)` / `shell.clearAlias(alias)`.
- `shell.programs([showHidden])` -> array of program names.
- `shell.complete(line)` / `shell.completeProgram(prefix)` — used by tab completion.

## Running program info
- `shell.getRunningProgram()` -> path of the currently running script.

## Pattern: capture another program's output
```lua
local w, h = term.getSize()
local buf = window.create(term.current(), 1, 1, w, h, false)
local prev = term.redirect(buf)
shell.run("ls")
term.redirect(prev)
for y = 1, h do print(buf.getLine(y)) end
```
