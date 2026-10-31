# multishell

Tabbed program runner. Available only when `bios.use_multishell` is true (default on advanced computers).

- `multishell.getCurrent()` -> id of the current tab.
- `multishell.getCount()` -> number of tabs.
- `multishell.getTitle(id)` / `multishell.setTitle(id, title)`.
- `multishell.getFocus()` -> id of the focused tab.
- `multishell.setFocus(id)` -> bool.
- `multishell.launch(env, programPath, ...)` -> tabId — start a new tab. `env` is an environment table (use `_ENV` or build your own).

## Pattern: launch a side task
```lua
if multishell then
    multishell.launch({}, "/rom/programs/clock")
end
```

`shell.openTab(command)` is a higher-level wrapper that uses `multishell.launch` and parses the command.
