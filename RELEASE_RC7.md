# WILD DASH 3D RC7 Release Candidate

RC7 consolidates the previously separate RC7 production-art work, track-specific Suno BGM integration, and campaign result/ranking finish into one release-candidate line.

## Candidate branch

`release/rc7-candidate`

## Included from RC6 baseline

- 10 / 15 / 18-racer difficulty fields
- RC6 AI pack tactics, passing, recovery and completion stabilization
- 5-round campaign flow
- items, skills, shortcuts, obstacles and race-environment collision hardening

## RC7 presentation

- production-proxy visual polish for all 12 racer species
- second-pass identity details for Dog, Rabbit, Cat and Elephant
- shared NPC production-polish system for Bear, Panda, Fox, Deer, Wolf, Monkey, Boar and Raccoon
- visual-only production dressing for Wild World Grand Prix, Neon Harbor and Snowpeak
- production art bible, authored-asset manifest and stylized proxy shader

This remains a production proxy bridge. Final Blender/Maya-authored, rigged and animated GLB characters and final environment kits are not yet complete.

## RC7 music

Runtime Ogg Vorbis assets are committed under `godot/audio/music/`:

- `wild_dash_race_theme.ogg` — Wild World Grand Prix
- `wild_dash_fruit_collection_theme.ogg` — Fruit Collection
- `wild_dash_race_theme_alt.ogg` — Neon Harbor Night Race
- `wild_dash_arena_theme_alt.ogg` — Push Out
- `wild_dash_snowpeak_theme.ogg` — Snowpeak Winter Rally
- `wild_dash_result_theme.ogg` — Result screen

`AudioManager` keeps procedural fallback music when an external track cannot be loaded. Menu / Round Break / Floor Collapse Free Play remain on procedural music for RC7.

## RC7 campaign finish

The Result screen now includes:

- final campaign score
- clears summary
- per-round results
- player-name entry
- local score registration
- local rank and Top 5 leaderboard
- persistent local ranking data through the existing save system

## Release metadata

- Godot project version: `0.9.0-rc7`
- Windows export: `build/windows/WILD_DASH_3D_RC7.exe`
- Windows file/product version: `0.9.0.7`

## Superseded work

This candidate supersedes the split work in:

- PR #30 — track-specific Suno BGM integration
- PR #31 — RC7 production art pass

Neither split PR should be merged independently once this candidate is under review.

## Validation already observed

- RC6 manual AI smoke: 15/15 and 18/18 racers finish without permanent stalls
- PR #30 repository CI: passed on its head
- PR #31 repository CI: passed on its head
- manual local playtest of the integrated art + committed music path reported working and visibly improved

## Validation required before merge to `main`

1. Pull `release/rc7-candidate` on a clean working tree.
2. Open with Godot 4.7.1 and allow full import to finish.
3. Run Lobby → Character Select → all five campaign rounds → Result.
4. Confirm each campaign round switches to its intended OGG track and Result uses its own track.
5. Confirm Result player-name entry, score registration, local rank, Top 5 display and persistence after restart.
6. Check 1600×900 UI clipping, chase-camera readability and 15/18-racer visual clutter.
7. Export Windows Desktop and smoke-test `WILD_DASH_3D_RC7.exe`.
8. Run the normal repository CI once on the unified RC7 PR.

Do not merge this release candidate until the unified manual Godot playtest and Windows export smoke pass.
