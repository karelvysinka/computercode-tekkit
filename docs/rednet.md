# rednet

High-level networking layered on top of modems.

- `rednet.open(side)` - opens the modem on that side.
- `rednet.close(side?)`.
- `rednet.isOpen(side?)`.
- `rednet.send(recipientId, message, protocol?)`.
- `rednet.broadcast(message, protocol?)`.
- `rednet.receive([protocol][, timeout])` -> `senderId, message, protocol?`. Returns nil on timeout.
- `rednet.host(protocol, hostname)` - register so others can find you.
- `rednet.unhost(protocol)`.
- `rednet.lookup(protocol, hostname?)` -> id, or array of ids if hostname omitted.

Each computer has a unique `os.getComputerID()`; rednet uses it.

Messages can be any serializable value (numbers, strings, tables).

## Pattern: ping/pong
```lua
rednet.open("back")
-- server
rednet.host("ping", "server1")
while true do
    local id, msg = rednet.receive("ping")
    rednet.send(id, "pong", "ping")
end
-- client
local id = rednet.lookup("ping", "server1")
rednet.send(id, "hello", "ping")
local _, reply = rednet.receive("ping", 2)
```
