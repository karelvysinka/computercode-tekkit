# keys

Key-code constants for `key` / `key_up` events.

```lua
local _, code, isHeld = os.pullEvent("key")
if code == keys.q then break end
```

## Common
- letters: `keys.a` .. `keys.z`
- digits (top row): `keys.zero` .. `keys.nine`
- numpad: `keys.numPad0` .. `keys.numPad9`, `keys.numPadAdd`, `keys.numPadSubtract`, `keys.numPadEnter`, `keys.numPadDecimal`
- arrows: `keys.up`, `keys.down`, `keys.left`, `keys.right`
- modifiers: `keys.leftCtrl`, `keys.rightCtrl`, `keys.leftShift`, `keys.rightShift`, `keys.leftAlt`, `keys.rightAlt`
- whitespace: `keys.space`, `keys.tab`, `keys.enter`, `keys.backspace`, `keys.delete`
- nav: `keys.home`, `keys.end`, `keys.pageUp`, `keys.pageDown`, `keys.insert`
- function: `keys.f1` .. `keys.f12`
- punctuation: `keys.minus`, `keys.equals`, `keys.leftBracket`, `keys.rightBracket`, `keys.semicolon`, `keys.apostrophe`, `keys.grave`, `keys.backslash`, `keys.comma`, `keys.period`, `keys.slash`
- special: `keys.escape`, `keys.capsLock`, `keys.scrollLock`, `keys.numLock`, `keys.printScreen`, `keys.pause`

Reverse lookup: `keys.getName(code)` -> string.
