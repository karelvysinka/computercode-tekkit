# peripheral

Peripherals are blocks attached to a computer (sides: top/bottom/left/right/front/back) or via a wired modem (string names like `"monitor_0"`).

## Discovery
- `peripheral.getNames()` -> table of peripheral names (sides + modem-attached names).
- `peripheral.getType(name)` -> string like "monitor", "modem", "minecraft:chest", "drive", "speaker", "printer", "turtle".
- `peripheral.isPresent(name)` -> bool.
- `peripheral.getMethods(name)` -> table of method-name strings the peripheral exposes.
- `peripheral.find(type [, filter])` -> first matching wrapped peripheral, or nil. `peripheral.find("monitor")` returns the wrapped monitor.
- `peripheral.wrap(name)` -> table of methods (call as `wrapped.foo(args)`).
- `peripheral.call(name, method, ...)` -> direct call without wrapping.

## Common types and key methods
- **monitor**: term-like API + `setTextScale(scale)`, scales 0.5..5. See `monitor` doc.
- **modem**: `open(channel)`, `close(channel)`, `transmit(channel, replyChannel, message)`, `isOpen(channel)`. Wireless modems for radio, wired modems for connecting blocks.
- **chest / barrel** (and any inventory): `size()`, `list()` -> map of slot -> {name,count,nbt}, `getItemDetail(slot)`, `getItemLimit(slot)`, `pushItems(toName, slot, limit?, toSlot?)`, `pullItems(fromName, slot, limit?, toSlot?)`.
- **speaker**: `playNote(name, volume?, pitch?)`, `playSound(name, volume?, pitch?)`, `playAudio(buffer)` for DFPWM.
- **drive** (disk drive): `isDiskPresent()`, `getDiskLabel()`, `getMountPath()`, `playAudio()`, `stopAudio()`.
- **printer**: `newPage()`, `endPage()`, `write(text)`, `setCursorPos(x,y)`, `setPageTitle(title)`, `getPaperLevel()`.
- **computer / turtle**: `turnOn()`, `shutdown()`, `reboot()`, `getID()`, `getLabel()`, `isOn()`.

## Pattern: find any monitor and use it
```lua
local m = peripheral.find("monitor")
if m then m.setTextScale(0.5); term.redirect(m) end
```
