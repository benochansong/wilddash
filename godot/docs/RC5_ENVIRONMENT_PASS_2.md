# RC5 Grand Prix Environment Pass 2

## Scope and baseline

This stacked pass builds on `feature/rc5-environment-pass-1` and changes only Water/River, obstacle visuals, moving-gate visuals, jump-ramp visuals, shortcut visual language, the final/finish area, and lightweight trackside props.

Baseline findings:

- Both rivers used one flat-color standard material with no motion or depth variation.
- Static obstacles and multi-jump hurdles were visible collision-enabled CSG boxes.
- Dynamic sweepers and gates rendered as one plain `BoxMesh` each.
- Moving gates had no stationary frame, guide rail, warning stripe, or warning light language.
- The main ramp was one sloped box and the multi-jump section repeated plain boxes.
- Shortcut surfaces were separate CSG visuals without discovery cues at their entrances.
- The finish area used a ground stripe but no finish gate, event barriers, flags, or approach rhythm.
- Trackside event props did not yet communicate zone transitions.

## Implementation

### Water and river

- Added a lightweight animated spatial shader using fragment wave motion, shallow/deep color variation, specular glints, roughness variation, and perturbed normals.
- No SSR, reflection probe, dynamic light, water physics, or water collision was added.
- Added dirt banks, low-cost reeds, wet-rock accents, and preserved bridge approach safety rail visuals.

### Obstacles and moving gates

- Kept every original static CSG collision size and position, but hid those collision meshes.
- Rebuilt static obstacle readability with collision-free wood, metal, warning, and irregular rock batches.
- Replaced each dynamic obstacle's single box visual with one compound `ArrayMesh` containing body, metal/guide pieces, and warning-stripe surfaces.
- Kept the same `WildDashDynamicObstacle` bodies, `BoxShape3D` collision, motion types, speeds, amplitudes, and physics process.
- Added stationary support frames, guide rails, top beams, and warning-light caps around the three moving gates.

### Ramps and shortcuts

- Rebuilt the main ramp with a distinct surface, side structure, hazard color, and landing-direction bars while preserving its original hidden CSG collision transform.
- Added varied support and direction treatment to all three multi-jump hurdles without changing jump physics or collision.
- Batched both dirt shortcut surfaces into one visual node and added restrained broken-fence posts, arrow signs, and rock-gap cues.
- Shortcut route points, collision, savings, and AI shortcut selection are unchanged.

### Final section and trackside props

- Added stronger final barriers, approach direction bars, finish pillars, top beam, alternating checkered blocks, flags, and event-color rhythm.
- Kept the existing finish stripe and `FinishLine` area aligned with the final route point; finish detection code was not touched.
- Added sparse signs, posts, crates, cones, rocks, and reeds outside the primary racing readability zone.
- Zone identity now uses event blue at Start/Final, wood in Forest/shortcuts, wet stone at River, metal at Bridge/Gates, and warning color at obstacles/ramps.

## Gameplay safety and performance

- No gameplay, AI, item, skill, checkpoint, finish, pacing, or character script was changed.
- New scenery is visual-only and has no process callbacks.
- Dynamic obstacles retain one visual node and one primitive collision node per body.
- Reused and extended existing MultiMesh batches instead of adding per-prop nodes.
- Removed redundant scene-authored ramp/safety-rail visual nodes and finished at 175 runtime track nodes, down from pass 1's 176 and below the 180-node budget.

## Validation

- Godot 4.7.1 import and Grand Prix track smoke passed.
- Track remains 2467.7 m with 30 route points, 11 checkpoints, and unchanged shortcut savings of 54.4 m / 53.7 m.
- Finish crossing rejects the pre-line position and accepts the post-line position.
- Character Select, Chimera, 12-item, 4-skill, and RC5 challenge tests passed.
- Hard 18-racer Grand Prix passed with all racers finishing in 69.91 seconds, 3/3 shortcut completion, and 8 recoveries.
- Normal 15-racer four-round campaign passed with all 15 Grand Prix racers finishing and all four rounds reaching the saved Result state in 100.7 seconds.
- Baseline and optimized 10/25/50-racer benchmarks passed. Optimized 50-racer result: 59.97 FPS, 42.68 MB peak memory.

## Known existing issue

The Normal 15-racer real-time balance probe timed out once with 13/15 finishers. The same `validate-rc5` probe already fails on the unchanged pass-1 PR: one Dog repeatedly stalls at checkpoint 9/route 23. This pass does not change gameplay collision or AI logic, Hard 18 completes, and the accelerated Normal 15 campaign completes. Per scope, the pre-existing checkpoint-9 AI recovery issue is documented rather than changing AI/gameplay in this environment PR.
