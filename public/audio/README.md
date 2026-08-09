# WILD DASH audio assets

Place packaged game audio here so Vite/Electron can load it from the bundled `dist/audio/` directory.

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

For the offline Electron build, prefer relative URLs such as `./audio/sfx/jump.ogg` rather than absolute `/audio/...` URLs.

Use OGG for compact packaged assets and WAV when lossless source quality is useful. Register files through `game/audio/AudioManager.ts` with `registerSfx()` or `registerMusic()` and play them through `playSfx()` / `playMusic()`.

Do not create `AudioContext` instances inside React components.
