# settings

Persistent computer-wide key/value storage. Saved to `.settings` in the computer root.

## Read / write
- `settings.set(name, value)` — value can be string, number, bool, table, or nil.
- `settings.get(name [, default])` -> value.
- `settings.unset(name)` — remove a value (reverts to default).
- `settings.clear()` — wipe all values.
- `settings.getNames()` -> array.

## Define & describe
- `settings.define(name, options)` — options: `{ description?, default?, type? }`. Used by the `set` shell command for completion + validation.
- `settings.undefine(name)`.
- `settings.getDetails(name)` -> `{ value, default, description, type }`.

## Persistence
- `settings.load([path])` -> bool — defaults to `.settings`.
- `settings.save([path])` -> bool.

Settings are loaded automatically on startup. Call `save()` after `set` if you want the change to survive a reboot (CC does this for you for `.settings`).

## Common built-in settings
- `shell.allow_disk_startup`, `shell.allow_startup`
- `motd.enable`, `motd.path`
- `bios.use_multishell`
- `lua.autocomplete`

## Pattern
```lua
settings.define("myapp.theme", { default = "dark", type = "string" })
settings.set("myapp.theme", "light")
settings.save()
local theme = settings.get("myapp.theme")
```
