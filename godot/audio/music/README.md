# WILD DASH Music Assets

Place the main race BGM at:

`res://audio/music/wild_dash_race_theme.ogg`

`AudioManager` loads this file as the shared race theme for Grand Prix, Neon Harbor and Snowpeak. If the asset is absent or cannot be loaded, WILD DASH keeps the existing procedural race theme as a safe fallback.

Recommended source workflow:

1. Keep the original lossless WAV outside the runtime repository as the master.
2. Export an Ogg Vorbis runtime copy at 48 kHz stereo.
3. Name it `wild_dash_race_theme.ogg`.
4. Confirm looping and Music-bus volume in Godot before public release.
