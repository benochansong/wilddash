# WILD DASH 3D — Release Candidate Checklist

Version: `0.9.0-rc1`
Branch: `release/wilddash-3d-rc1`
Target: Windows PC / offline single-player
Engine: Godot 4.7.1

## Release Candidate definition

RC1은 현재 Godot 3D 버전을 Windows에서 실행/배포 테스트할 수 있는 상태로 묶는 단계다.
Steam 출시나 최종 production art/audio 완성을 의미하지 않는다.

## Core Flow

자동 smoke flow:

```text
Launch
→ Lobby
→ Character Select
→ Race
→ Round 2
→ Round 3
→ Final
→ Result
→ Save
→ Restart
→ Save Load
```

- [x] Launch scene is Lobby
- [x] Lobby opens without auto-starting the campaign
- [x] Character Select supports Dog / Rabbit / Elephant / Cat
- [x] Difficulty selection supports Wild / Chaos / Nightmare
- [x] Round 1 loads and completes lifecycle
- [x] Round 2 loads and performs AI fruit pickup
- [x] Round 3 loads and advances floor-collapse phases
- [x] Final loads and performs AI body-check interaction
- [x] Result scene receives all four round results
- [x] Result writes campaign progress to local save
- [x] Fresh process restart loads the saved campaign/profile data

## Input

- [x] Keyboard support
- [x] Gamepad support through shared InputMap actions
- [x] Keyboard remapping UI
- [x] Keyboard binding persistence in Save v2
- [x] WASD / arrows defaults
- [x] Space jump
- [x] E skill
- [x] Q item
- [x] Esc / P pause
- [x] Left Stick / D-Pad movement
- [x] Gamepad A jump
- [x] Gamepad X skill
- [x] Gamepad B item
- [x] Gamepad Start pause

Before public RC distribution:

- [ ] Manual Xbox-compatible controller playtest on a physical Windows PC
- [ ] Manual controller disconnect/reconnect test

## Audio

- [x] Master Audio Bus
- [x] Music Audio Bus
- [x] SFX Audio Bus
- [x] Master volume setting
- [x] Music volume setting
- [x] SFX volume setting
- [x] Mute setting
- [x] Menu/race/arena/result BGM playback path
- [x] UI/jump/skill/item/hit/finish SFX path
- [x] SFX player pool avoids creating one permanent player per sound event

RC limitation:

- [ ] Replace procedural placeholder BGM/SFX with final licensed/original audio before final content release

## Graphics

- [x] 1280×720 option
- [x] 1600×900 option
- [x] 1920×1080 option
- [x] Windowed mode
- [x] Fullscreen mode
- [x] 30 FPS cap
- [x] 60 FPS cap
- [x] 120 FPS cap
- [x] Unlimited FPS option
- [x] Graphics settings persist in Save v2

Before public RC distribution:

- [ ] Manually verify window/fullscreen transitions on the target Windows PC
- [ ] Manually verify each resolution on at least one 1080p display

## Accessibility

- [x] Reduced Motion setting retained
- [x] Reduced Motion reduces camera look-ahead and stabilizes follow behavior
- [x] High Contrast setting retained
- [x] High Contrast menu/HUD treatment
- [x] Accessibility settings persist

## Save System

Save path:

```text
user://wild_dash_save.json
```

- [x] Versioned Save v2
- [x] Profile persistence
- [x] Settings persistence
- [x] Keyboard binding persistence
- [x] Last selected character persistence
- [x] Campaign result persistence
- [x] v1 → v2 settings migration
- [x] Corrupt JSON falls back safely
- [x] Future-version save is not overwritten by RC1
- [x] Restart/load test uses a second process

Before final release:

- [ ] Keep a backup fixture for at least one real v1 save and one v2 save for migration regression tests

## Pause / Lifecycle

- [x] Pause Manager is an autoload
- [x] Pause available during gameplay states
- [x] Resume
- [x] Return to Lobby
- [x] Quit Game saves before exit
- [x] RaceManager has explicit stop/clear lifecycle seams
- [x] Automated pause/resume state test

Manual Windows test:

- [ ] Alt+Tab while paused and while racing
- [ ] Close window from Lobby
- [ ] Close window from gameplay
- [ ] Repeat 3 full campaigns without restarting the app

## AI / Performance

Normal four-round campaign safety range:

```text
4 AI → 10 AI
```

Dedicated Grand Prix benchmark:

```text
10 racers → 25 racers → 50 racers
```

- [x] 4 AI full campaign lifecycle
- [x] 10 AI full campaign lifecycle
- [x] 10 racer benchmark baseline/optimized
- [x] 25 racer benchmark baseline/optimized
- [x] 50 racer benchmark baseline/optimized
- [x] AI distance LOD
- [x] AI update-frequency reduction
- [x] Animation update LOD seam
- [x] Far-racer collision simplification

50-racer promotion gate remains open:

- [ ] Rendered Windows 10-racer benchmark
- [ ] Rendered Windows 25-racer benchmark
- [ ] Rendered Windows 50-racer benchmark
- [ ] Production GLB/animation 50-racer GPU/Draw Call test

Do not raise the normal campaign cap to 50 until these rendered checks pass.

## Windows Export

Preset:

```text
Windows Desktop
```

Output:

```text
build/windows/WILD_DASH_3D.exe
```

- [x] Windows export preset committed
- [x] Godot 4.7.1 export templates installed in CI
- [x] Windows project import in CI
- [x] Windows x86_64 Release export in CI
- [x] `.exe` existence check
- [x] Exported executable smoke launch
- [x] Release Candidate artifact upload

Distribution limitations:

- [ ] Code signing certificate not configured
- [ ] No installer/MSIX packaging yet; current RC artifact is a Godot Windows executable
- [ ] Manual Windows Defender/SmartScreen observation required before wider public distribution

## Steam Boundary

- [x] Steam SDK is not part of RC1
- [x] Core GameManager/RaceManager/CharacterController do not depend on Steam
- [x] Save system is local and platform-independent at the game-rule level

Future Steam integration should live behind a platform/service adapter for achievements, cloud saves, overlay, ownership and Steam-specific lifecycle APIs.

## Content limitations that do not block technical RC

- Placeholder Capsule/low-poly visuals are still used in place of production animal GLBs.
- Current BGM/SFX are lightweight procedural placeholders.
- Item architecture exists, but production item presentation/effects are not final content.
- 50 racers are not yet enabled as the normal four-round campaign configuration.

These do not block a **technical Windows RC/playtest build**, but they do block calling this a content-complete final game.

## RC1 acceptance gate

Technical RC1 can be preserved when all of the following are true:

- [x] Godot project imports with no fatal script/scene errors
- [x] Release system smoke test passes
- [x] Launch → Result flow passes with 4 AI
- [x] Restart → Save Load passes
- [x] 10 AI campaign regression passes
- [x] 10/25/50 performance benchmark completes
- [x] Windows release export succeeds
- [x] Exported `.exe` starts and exits cleanly in smoke test
- [x] CI uploads Windows artifact

Recommended manual sign-off before handing the RC to other testers:

- [ ] 3 complete Windows playthroughs with keyboard
- [ ] 3 complete Windows playthroughs with an Xbox-compatible controller
- [ ] Pause/resume/Alt+Tab stress check
- [ ] Resolution/fullscreen check
- [ ] Audio volume/mute check with real speakers/headphones
- [ ] Save persistence after normal desktop exit/relaunch
- [ ] Rendered Windows 10-racer FPS baseline

## RC status

**Technical automation gate: PASS** at the implementation stage that produced a successful Godot 4.7.1 Linux validation and Windows export/smoke artifact.

**Human Windows playtest gate: PENDING.**

Do not label RC1 as final release or Steam-ready until the manual checks and final production content pass.
