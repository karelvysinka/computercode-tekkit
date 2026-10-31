# Available docs

Use `read_doc({ topic = "<name>" })` to fetch any of these.

## Computer APIs
- `os` - events (pullEvent, queueEvent), timers, computer info, time/date
- `fs` - filesystem: open/read/write, list, exists, makeDir, copy, move, delete
- `shell` - cwd, run/execute, programs, aliases, tab completion
- `term` - terminal: write, blit, colors, cursor, redirect, sizing
- `colors` - color constants and combine/subtract helpers, toBlit
- `keys` - key code constants for `key` events
- `textutils` - serialize/unserialize, JSON, slowWrite, pagedPrint, formatTime
- `window` - in-memory virtual terminal windows
- `paintutils` - drawPixel/Line/Box, parse/load/draw .nfp images
- `parallel` - parallel.waitForAny / waitForAll for concurrent coroutines
- `multishell` - tabbed program runner
- `settings` - persistent computer-wide key/value storage
- `vector` - 3D vector math
- `http` - HTTP requests (get/post/request), websocket
- `redstone` / `rs` - reading and setting redstone signals on each side

## Peripherals
- `peripheral` - generic discovery/wrap/call (always start here)
- `modem` - wireless + wired networking, channels, modem_message events
- `monitor` - monitor peripheral (term-like) + setTextScale
- `speaker` - playNote / playSound / playAudio (DFPWM)
- `disk` - disk drive: mount, audio, eject

## Turtle / robotics
- `turtle` - movement, dig/place, inventory, fuel, inspect

## Networking
- `rednet` - high-level networking on top of modems
- `gps` - locate yourself via gps hosts

## UI
- `pixelui` - PixelUI framework overview: app lifecycle, common config, animations, threads, event flow
- `pixelui-widgets` - every widget reference (Frame, Window, Dialog, MsgBox, Button, Label, CheckBox, Toggle, RadioButton, TextBox, ComboBox, List, Table, TreeView, Chart, Slider, ProgressBar, NotificationToast, LoadingRing, TabControl, ContextMenu, FreeDraw)
- `pixelui-freedraw` - custom drawing on the pixel layer, the ctx.pixel bug workaround, ready-to-paste helper functions
