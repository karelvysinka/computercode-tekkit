# speaker (peripheral)

Plays sounds, notes, and arbitrary DFPWM audio.

Get one with `peripheral.find("speaker")`.

## Notes
- `speaker.playNote(name, volume?, pitch?)`
  - `name`: "harp", "basedrum", "snare", "hat", "bass", "flute", "bell", "guitar", "chime", "xylophone", "iron_xylophone", "cow_bell", "didgeridoo", "bit", "banjo", "pling".
  - `volume`: 0..3 (default 1).
  - `pitch`: 0..24 (default 12; 12 = F#).

## Sound events
- `speaker.playSound(name, volume?, pitch?)` -> bool.
  - `name`: any Minecraft sound id, e.g. `"minecraft:entity.experience_orb.pickup"`, `"minecraft:block.note_block.pling"`, `"minecraft:ui.button.click"`.
  - `volume`: 0..3.
  - `pitch`: 0.5..2.

## Audio (DFPWM streaming)
- `speaker.playAudio(buffer, volume?)` -> bool — accepts an array of 8-bit signed samples (an audio buffer chunk). Returns false if the speaker's queue is full; in that case wait for `speaker_audio_empty` event for the same speaker.
- `speaker.stop()`.

Use the `cc.audio.dfpwm` module to encode/decode DFPWM:
```lua
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()
for chunk in io.lines("song.dfpwm", 16 * 1024) do
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end
```
