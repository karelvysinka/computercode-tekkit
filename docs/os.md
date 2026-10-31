# os

Computer-level OS API.

## Events
- `os.pullEvent([filter])` -> `event, ...` - blocks until event matching filter.
- `os.pullEventRaw([filter])` - same but doesn't translate `terminate` to an error.
- `os.queueEvent(name, ...)` - queue a custom event.

Common events:
- `key`, `key_up` (keyCode, isHeld)
- `char` (character)
- `mouse_click`, `mouse_up`, `mouse_drag`, `mouse_scroll` (button/dir, x, y) - advanced computers/monitors only.
- `monitor_touch` (side, x, y)
- `monitor_resize` (side)
- `term_resize`
- `timer` (id), `alarm` (id)
- `redstone`
- `peripheral`, `peripheral_detach` (side)
- `disk`, `disk_eject` (side)
- `rednet_message` (sender, message, protocol)
- `http_success`, `http_failure`, `websocket_message`, etc.
- `terminate` (Ctrl+T)

## Timing
- `os.sleep(seconds)` (alias `sleep`).
- `os.startTimer(seconds)` -> id (fires `timer` event).
- `os.cancelTimer(id)`.
- `os.setAlarm(time)` -> id (fires `alarm` at in-game time, 0..24).
- `os.clock()` -> seconds since computer started.
- `os.epoch("utc"|"local"|"ingame"|"nano")` -> ms (or ns) timestamp.
- `os.day([type])`, `os.time([type])`, `os.date([format[, time]])`.

## Computer info
- `os.getComputerID()`.
- `os.getComputerLabel()` / `os.setComputerLabel(s)`.
- `os.shutdown()`, `os.reboot()`.
- `os.version()`.

## Loading
- `os.loadAPI(path)` (legacy); prefer `require` for modern code.
