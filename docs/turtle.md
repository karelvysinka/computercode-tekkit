# turtle

Turtles are programmable robots. All movement/dig calls return `success, reason?`.

## Movement
- `turtle.forward()` / `turtle.back()` / `turtle.up()` / `turtle.down()`
- `turtle.turnLeft()` / `turtle.turnRight()`

## Digging
- `turtle.dig(side?)` / `turtle.digUp()` / `turtle.digDown()` - `side` optionally the tool side ("left"/"right") for crafty turtles.

## Placing
- `turtle.place(text?)` / `turtle.placeUp(text?)` / `turtle.placeDown(text?)` - places item from selected slot. `text` is sign text.

## Detection / Inspect
- `turtle.detect()` / `turtle.detectUp()` / `turtle.detectDown()` - bool: solid block in front?
- `turtle.inspect()` / `turtle.inspectUp()` / `turtle.inspectDown()` - returns `success, info` where info is `{ name = "minecraft:stone", state = {...}, tags = {...} }`.
- `turtle.compare()` / `turtle.compareUp()` / `turtle.compareDown()` - matches block to selected slot.

## Inventory
- `turtle.select(slot)` - 1..16
- `turtle.getSelectedSlot()`
- `turtle.getItemCount(slot?)` / `turtle.getItemSpace(slot?)` / `turtle.getItemDetail(slot?, detailed?)`
- `turtle.transferTo(slot, count?)` - move from selected to `slot`.
- `turtle.equipLeft()` / `turtle.equipRight()` - swap selected item with equipped tool.
- `turtle.suck(count?)` / `turtle.suckUp(count?)` / `turtle.suckDown(count?)` - pick up items.
- `turtle.drop(count?)` / `turtle.dropUp(count?)` / `turtle.dropDown(count?)`

## Fuel
- `turtle.refuel(count?)` - burns selected slot items as fuel.
- `turtle.getFuelLevel()` -> number or "unlimited".
- `turtle.getFuelLimit()`.

## Crafting (crafty turtles only)
- `turtle.craft(limit?)` - uses 3x3 in inventory slots 1-3, 5-7, 9-11.

## Attack
- `turtle.attack(side?)` / `turtle.attackUp(side?)` / `turtle.attackDown(side?)`

## Pattern: safe forward with retry
```lua
while not turtle.forward() do
    if turtle.detect() then turtle.dig() else turtle.attack() end
    sleep(0.1)
end
```
