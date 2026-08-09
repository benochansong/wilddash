# WILD DASH audio assets

Place packaged game audio here so Vite/Electron can load it with stable `/audio/...` URLs.

Recommended layout:

```text
public/audio/
  sfx/
    jump.ogg
    skill.ogg
    item.ogg
  music/
    lobby.ogg
    race.ogg
```

Use OGG for compact packaged assets and WAV when lossless source quality is useful. Register files through `game/audio/AudioManager.ts` with `registerSfx()` or `registerMusic()` and play them through `playSfx()` / `playMusic()`.

Do not create `AudioContext` instances inside React components.
