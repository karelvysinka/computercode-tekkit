# modem (peripheral)

Modems come in two flavors:
- **Wireless modems** — for radio communication on channels (limited range; full range with ender modem).
- **Wired modems** — connect computers and inventories via networking cable. Each block on the network appears as a peripheral with a string name like `"monitor_0"`.

Get one with `peripheral.wrap("left")` or `peripheral.find("modem")` (returns one wrapped + its name).

## Channels (wireless / radio)
- `modem.open(channel)` — listen on a channel (0..65535).
- `modem.close(channel)` / `modem.closeAll()`.
- `modem.isOpen(channel)` -> bool.
- `modem.transmit(channel, replyChannel, message)` — sends to anyone on that channel.
- `modem.isWireless()` -> bool.

Receiving: a `modem_message` event fires when an open channel gets a message:
```lua
local _, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
```

`distance` is in blocks for wireless modems, nil for wired.

## Wired networks (peripheral discovery)
On wired modems only:
- `modem.getNamesRemote()` -> array of peripheral names connected via the network.
- `modem.getTypeRemote(name)` -> string type.
- `modem.getMethodsRemote(name)` -> array of methods.
- `modem.callRemote(name, method, ...)` -> direct call on a remote peripheral.
- `modem.isPresentRemote(name)` -> bool.
- `modem.getNameLocal()` -> the wired modem's own name on the network.

Note: `peripheral.getNames()` and `peripheral.wrap(name)` work transparently across wired modems too — usually you don't need the `Remote` variants.

## Common patterns

### Wireless ping
```lua
local m = peripheral.find("modem")
m.open(42)
m.transmit(42, 42, "ping")
local _, _, ch, _, msg = os.pullEvent("modem_message")
print(("ch %d -> %s"):format(ch, tostring(msg)))
```

### Inventory transfer over wired modem
```lua
local chest = peripheral.wrap("minecraft:chest_0")
chest.pushItems("minecraft:barrel_1", 1, 64)  -- move 64 from slot 1 to barrel
```

Higher-level networking on top of modems is in the `rednet` API.
