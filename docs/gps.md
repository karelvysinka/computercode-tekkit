# gps

Locate a computer's coordinates by triangulating signals from at least 4 GPS host computers.

- `gps.locate([timeout [, debug]])` -> `x, y, z` or `nil` if not enough hosts in range. Default timeout 2s.
- `gps.host(x, y, z)` - typically called once on a host computer with a wireless modem at known coords.
- `gps.CHANNEL_GPS = 65534` - the channel.

GPS hosts must use wireless modems and be placed at high y so signals travel far. The `gps host` shell program does this for you.

## Pattern: locate self
```lua
local x, y, z = gps.locate(2)
if x then print(("at %d, %d, %d"):format(x, y, z)) else print("no GPS fix") end
```
