# disk

Interact with disk drives (a peripheral that holds a floppy disk).

Functions take a disk drive's `side` ("left", "top", etc.) or its peripheral name.

- `disk.isPresent(side)` -> bool — is a disk inserted?
- `disk.hasData(side)` -> bool — data disk?
- `disk.getMountPath(side)` -> "/disk", "/disk2", etc. — fs path where the disk is mounted.
- `disk.getLabel(side)` / `disk.setLabel(side, label)`.
- `disk.getID(side)` -> number — unique disk id.
- `disk.hasAudio(side)` -> bool — music disc?
- `disk.getAudioTitle(side)` -> string.
- `disk.playAudio(side)` / `disk.stopAudio(side)`.
- `disk.eject(side)` — pop the disk.

Events:
- `disk` — fires with `side` when a disk is inserted.
- `disk_eject` — fires when a disk is removed.

## Pattern: read disk root on insertion
```lua
while true do
    local _, side = os.pullEvent("disk")
    if disk.hasData(side) then
        local path = disk.getMountPath(side)
        for _, file in ipairs(fs.list(path)) do print(file) end
    end
end
```
