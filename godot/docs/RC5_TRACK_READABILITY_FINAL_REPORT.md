# RC5 Grand Prix Track Readability Final Report

## Scope and safety

This pass integrates the previously completed road, direction-guide, and special-section readability work on top of `feature/rc5-environment-pass-3`. It does not change track length, route points, AI paths, checkpoints, shortcut logic, item boxes, obstacle timing, jump physics, finish detection, racer stats, or player finish flow.

The runtime track remains 2467.7 m long with 30 route points and 11 checkpoints. Visual guidance is built under `DecorationGeometry`; it has no collision and no `_process()` callbacks.

## Modified and added files

Modified:

- `tracks/grand_prix_track.gd`
- `tracks/environment_material_library.gd`
- `tests/grand_prix_track_smoke.gd`

Added:

- `tracks/track_guide_factory.gd`
- `tracks/track_guide_factory.gd.uid`
- `tests/track_readability_visual_audit.gd`
- `tests/track_readability_visual_audit.gd.uid`
- `tests/track_readability_visual_audit.tscn`
- `docs/RC5_TRACK_READABILITY_FINAL_REPORT.md`

## Visual audit

An actual OpenGL Compatibility render audit captured 11 third-person approach views: meadow/first bend, forest/uphill, jump/bridge, canyon S-curve, river bridge, Shortcut A/obstacles, wide hairpin, multi-jump/Shortcut B, tunnel, final chicane, and finish approach.

Results:

- The neutral dark road separates immediately from dirt, grass, rock, bridge, tunnel, and water surroundings.
- Continuous bright edge paint, zone-specific shoulders, curbs, fences, rock borders, and structural rails make both road boundaries traceable.
- Ordinary straights rely on road shape and edge continuity; they do not contain direction arrows.
- Road arrows and trackside markers appear only before direction decisions, sharp turns, bridges, jumps, obstacles, shortcuts, tunnel entry, and the final technical section.
- The main route uses continuous road edges and stronger structural guidance. Shortcuts use dirt, worn patches, broken fence rhythm, and restrained signs.
- No guide was removed during the final audit: the existing sparse placement did not read as over-marked in the 11 approach captures.

The render captures are generated into `outputs/readability-audit` and are intentionally not committed.

## Road readability

- Shared asphalt is darker and more neutral than terrain.
- White edge lines and restrained center dashes establish road continuity without neon coloration.
- Forest hierarchy reads as road, dirt shoulder, grass, then vegetation.
- Canyon hierarchy reads as road, dusty shoulder, warm warning edge, then rock border.
- Bridges narrow through approach paint into structural edges and rail starts.
- Tunnel approach paint narrows into the portal, with internal edge markings and guide lights continuing toward a brighter exit.

## Arrow and chevron systems

`WildDashTrackGuideFactory` creates shared static meshes for both road-surface arrows and trackside direction markers. Placement remains authored by the track script, avoiding a gameplay/environment God object.

- Road direction arrows: 34 transforms in one `MultiMeshInstance3D`.
- Trackside direction markers and chevrons: 38 transforms in one `MultiMeshInstance3D`.
- Shared material palette: warm white/yellow accent over dark backing.
- Collision: none.
- Per-frame processing: none.
- Visibility ranges: 360 m for road arrows and 420 m for trackside guides, with fade margins.

## Special-section guidance

- Shortcut A/B: quieter dirt surface, 10 worn-path marks, broken fence rhythm, small signs, and natural rock openings; the main route remains stronger.
- Jump: centered road arrows, ramp warning pattern, edge structure, and landing continuation marks.
- Bridge: narrowing edge lines, approach bands, arrows, rail starts, and compact bridge plaques.
- Tunnel: narrowing approach, entry marker, edge continuity, portal framing, interior lights, and exit glow.
- Obstacles: repeated road arrows plus side/overhead continuation structures; moving timing is unchanged.
- Final/finish: stronger warm edges, repeated final arrows, flags, checkered accents, and a distant gantry. The visible finish gate metadata is aligned with the existing finish detection point.

## Performance and collision

- Runtime track node count: 179, under the 180-node validation budget.
- Repeated road paint and structural detail use static MultiMesh batches.
- Both guide types use shared meshes/materials and two static MultiMesh nodes total.
- Guide and decorative geometry has no gameplay collision.
- Existing simple road, wall, rail, bridge-edge, and obstacle collision remains unchanged.

Headless benchmark results on the local Windows test host:

| Profile | Racers | FPS | Process ms | Physics ms | CPU budget | AI ms/frame | Memory peak |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline | 10 | 60.00 | 0.657 | 2.696 | 20.11% | 1.428 | 31.17 MB |
| Optimized | 10 | 60.00 | 0.859 | 3.322 | 25.08% | 1.644 | 31.17 MB |
| Baseline | 25 | 60.00 | 1.140 | 6.187 | 43.97% | 3.984 | 35.50 MB |
| Optimized | 25 | 60.00 | 1.636 | 7.190 | 52.95% | 4.365 | 35.48 MB |
| Baseline | 50 | 60.00 | 2.586 | 14.876 | 104.77% | 10.260 | 42.69 MB |
| Optimized | 50 | 60.00 | 2.550 | 15.145 | 106.17% | 9.172 | 42.69 MB |

The optimized profile reduced 50-racer AI time and AI update/raycast counts, but total CPU/physics budget was effectively unchanged and was worse in the single 10/25-racer samples. No performance improvement is claimed from this run. Headless benchmarks use the Dummy renderer, so draw calls, GPU cost, visual LOD quality, and real rendered frame rate are not measured.

## Regression results

| Validation | Result |
|---|---|
| Godot 4.7.1 project import | PASS |
| Grand Prix track smoke/validation | PASS |
| Character Select + Chimera save | PASS |
| Chimera head/body/tail system | PASS |
| Four character skills | PASS |
| Base item flow | PASS |
| Twelve-item expansion | PASS, 12 items / 5 roles |
| RC system smoke | PASS |
| Normal target, 15 racers | PASS, 15/15 finished, 3/3 shortcuts, 72.11 s field complete, 59.2 headless FPS |
| Hard target, 18 racers | PASS, 18/18 finished, 3/3 shortcuts, 69.89 s field complete, 59.1 headless FPS |
| Four-round campaign, 15 racers | PASS, 4 rounds, Grand Prix 15/15 finished, result save succeeded |
| AI route/checkpoints | PASS |
| Shortcut A/B | PASS |
| Jump and moving obstacles | PASS through full-race probes |
| Real finish crossing | PASS |
| Player finish flow | PASS through 15-racer four-round campaign |
| Windows x64 release export | PASS, unsigned internal candidate |
| Exported EXE smoke launch | PASS, Launch to Lobby, exit code 0 |

Windows internal candidate:

- `outputs/WILD_DASH_RC5_TRACK_READABILITY_INTERNAL.exe`
- Size: 109,518,248 bytes
- SHA-256: `2A51185D7B878EE485826CD0A5B341F20F3E10DDC5A95FB403379433883E0F83`
- This unsigned binary is a local internal test artifact and is not committed or published as a public release.

The only recurring host warning was failure to read the Windows root certificate store in the restricted test environment. It did not affect imports, gameplay tests, export, or launch.

## Manual play checks still required

- First-time-player one-second route recognition with the real racer, HUD, item effects, and a crowded 15/18-racer pack.
- Chevron legibility at speed through the canyon S-curve, river bridge turn, wide hairpin, and final chicane.
- Shortcut discovery rate: visible enough to reward exploration without competing with the main route.
- Tunnel entry/exit exposure transition and guide visibility on the shipping Windows renderer.
- Jump landing continuity at different camera settings and aspect ratios.
- Finish gantry recognition distance during actual gameplay.
- Rendered GPU frame time, draw calls, and visibility-range popping on minimum-spec hardware. Headless results cannot answer these questions.
