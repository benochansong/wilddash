# RC5 Grand Prix Environment Realism and Optimization Final Report

## A. Pass 1 through Pass 3 summary

- Pass 1 established the stylized-realism foundation for Road, Forest, Canyon, Bridge, and Tunnel. It introduced zoned surface materials, road-edge language, varied vegetation and rock silhouettes, bridge structure, tunnel segmentation, and visual/gameplay collision separation.
- Pass 2 upgraded Water/River, static and moving obstacles, ramps, shortcut discovery, the final/finish area, and sparse trackside props. It preserved all gameplay transforms and motion timing while replacing single primitive visuals with compound or batched forms.
- Pass 3 unified the material system, polished material response, added compatibility-safe global lighting, introduced environment LOD/visibility ranges, removed redundant per-prop work, added static validation, and produced an unsigned Windows x64 internal candidate.

## B. Grand Prix zone improvements

- Start: bright event-blue signage, readable starting surface, restrained race-event mood.
- Forest: cooler green palette, tapered trunks, clustered crowns, bushes, rocks, logs, wooden edge language, and near/far canopy LOD.
- Canyon: warm layered rock color, irregular six-sided cliffs, outcrops, loose stones, and long-distance cliff silhouettes.
- River: clean animated arcade water, dirt banks, reeds, wet-rock accents, and brighter reflected sky color.
- Bridge: metal deck-edge beams, longitudinal supports, vertical piers, cross braces, rail posts, and warning rhythm.
- Moving Gate: stationary support frames and guide rails plus compound moving barriers, joints, stripes, and warning caps.
- Multi Jump: supported ramp forms, varied hurdle height treatment, hazard markings, and landing-direction bars.
- Tunnel: rough concrete shell, segmented walls/ceiling, portal frames, guide lights, darker surfaces, and a bright exit band.
- Shortcuts: batched worn dirt paths, broken-fence rhythm, restrained arrows, natural openings, and rock-gap cues.
- Final/Finish: stronger barriers, approach rhythm, finish pillars, top beam, alternating checkers, flags, and high-readability cyan/orange accents aligned to the real finish plane.

## C. Material system

- Replaced per-track palette construction with `WildDashEnvironmentMaterialLibrary`, a small static cached library.
- Shared resources now cover Asphalt, Dirt, Grass, Rock, Wood, Metal, Concrete, Water, Hazard, Finish, and Wet Rock.
- Bridge/Metal, Tunnel/Concrete, and Event/Finish aliases reuse the same material resources rather than duplicating instances.
- The lightweight surface shader now supports aggregate roughness variation, path wear, directional wood grain, and layered rock/concrete color variation.
- Metal uses controlled metallic response; Finish is bright and emissive enough to read without overpowering racers.

## D. Lighting system

- Added `GrandPrixWorldEnvironment` with a friendly procedural sky, balanced sky ambient/reflection, Filmic tonemapping, modest exposure, and low-density height/depth fog.
- Reuses and tunes the existing Grand Prix `Sun`; no duplicate DirectionalLight is created.
- Sun color is slightly warm with reduced energy and shadow opacity to keep characters and obstacles readable.
- The project uses `gl_compatibility`, so SSAO remains intentionally disabled. No SSR, volumetric fog, dynamic grading volumes, or heavy local-light network was added.
- Zone mood comes primarily from material response and emissive landmarks: cool Forest, warm Canyon, bright River reflection, dark Tunnel/bright exit, and energetic Final accents. This avoids abrupt cinematic color shifts.

## E. LOD

- Near: full tree clusters, bushes, floor rocks, fallen logs, bridge braces, tunnel details, and small props.
- Mid: primary tree silhouettes, canyon outcrops, structural bridge/tunnel elements, and obstacle/event details.
- Far: low-poly single-cluster forest canopies and large canyon cliff silhouettes; tiny vegetation and props are culled.
- Overlapping visibility margins reduce obvious popping between near and far forest representations.

## F. MultiMesh optimization

- Reused MultiMesh batches for road surfaces, shoulders, curbs, lines, rails, trees, crowns, bushes, rocks, logs, bridge structure, tunnel panels, river vegetation, finish details, and trackside props.
- River banks/reeds, shortcut props, and final decorations extend existing material/mesh batches.
- Dynamic obstacles keep one compound `ArrayMesh` visual node and one primitive collision node each.
- Runtime Grand Prix node count is 178/180. Added WorldEnvironment, far-canopy LOD, and round-prop batch while remaining inside the existing budget.

## G. Collision and process optimization

- Decoration root is process-disabled and the validation test rejects collision objects under it.
- Road, walls, gameplay guardrails, obstacle bodies, ramp surfaces, bridge safety edges, checkpoints, and finish detection retain simple gameplay collision.
- Vegetation, small rocks, signs, beams, lights, water, finish decoration, and distant scenery have no collision.
- No environment `_process()` loop was added. Only the existing moving-obstacle physics process remains for animated scenery.

## H. Normal 15 result

- Four-round Normal campaign passed in 98.6 seconds locally.
- Grand Prix started with 15 racers and all 15 finished.
- Rounds 2, 3, Final, campaign completion, Result scene, and save confirmation all passed.
- The separate real-time balance probe has a pre-existing checkpoint-9/route-23 Dog recovery stall on pass 1 and pass 2. This environment-only pass does not change AI recovery logic.

## I. Hard 18 result

- All 18 racers finished the Grand Prix in 69.14 seconds.
- Average finish time: 57.48 seconds; finish gap: 43.12 seconds.
- Shortcut completion: 3/3; recoveries: 7; interaction-flow checks passed.

## J. 10/25/50 benchmark comparison

Headless benchmark figures measure CPU/physics behavior, not real GPU rendering. Draw calls, rendered primitives, video-memory load, shadow cost, fog cost, and visibility-range GPU savings are not represented.

| Profile | Racers | Pass 2 FPS | Pass 3 FPS | Pass 2 process ms | Pass 3 process ms | Pass 2 physics ms | Pass 3 physics ms | Pass 3 memory MB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Baseline | 10 | 59.99 | 59.99 | 0.679 | 0.663 | 2.515 | 2.578 | 31.17 |
| Baseline | 25 | 59.97 | 60.02 | 1.120 | 1.225 | 5.616 | 6.818 | 35.51 |
| Baseline | 50 | 59.97 | 59.97 | 1.898 | 2.234 | 13.096 | 14.226 | 42.73 |
| Optimized | 10 | 59.99 | 60.00 | 0.674 | 0.681 | 2.727 | 2.588 | 31.17 |
| Optimized | 25 | 60.00 | 60.00 | 1.158 | 1.313 | 5.583 | 5.610 | 35.47 |
| Optimized | 50 | 59.97 | 59.97 | 2.056 | 2.175 | 13.763 | 13.162 | 42.68 |

Optimized 50-racer physics time improved by about 4.4%, process time varied upward by about 0.12 ms, memory was unchanged, and average headless FPS remained 59.97. The benchmark scene does not instantiate the Grand Prix environment, so baseline-run variation cannot be attributed to the visual pass. No serious CPU/physics regression was found.

## K. Windows build result

- Export: unsigned Windows x64 internal candidate succeeded.
- File: `outputs/WILD_DASH_RC5_ENV_PASS_3_INTERNAL.exe`
- Size: 109,499,016 bytes.
- `WILDDASH_AUTOTEST_LOAD_ONLY=1` headless smoke launch exited with code 0.
- This is an internal test candidate only. No signing, public release, upload, or distribution was performed.

## L. Remaining placeholders

- Environment forms are still procedural low-poly geometry rather than authored production assets.
- Most surfaces use local procedural variation instead of hand-authored UV textures, decals, or trim sheets.
- Terrain is route-driven geometry rather than a sculpted terrain mesh.
- Trees use clustered low-poly spheres rather than authored foliage cards/atlases.
- Finish banners, mechanical joints, bridge bolts, cliff faces, and tunnel frames remain lightweight generated forms.
- Lighting is dynamic compatibility-renderer lighting; there are no baked lightmaps or authored reflection probes.

## M. Recommended Blender/GLB replacements

- Modular road curb/retaining-wall/guardrail kit with consistent pivots and trim-sheet UVs.
- Two or three stylized tree families with authored near/mid/far meshes and foliage atlases.
- Canyon cliff modules, overhangs, arches, loose-rock clusters, and wet-river rock variants.
- Bridge deck, beam, brace, railing, pier, bolt, and expansion-joint modules.
- Tunnel portal, wall panel, ceiling support, light fixture, and drainage-edge modules.
- Moving-gate frame, actuator, hinge, piston, barrier, warning lamp, and rotating-log assets.
- Main/multi-jump ramp kit with side profiles, frame braces, surface decals, and landing markers.
- Finish gantry, flags, cloth banners, cones, barrels, crates, signs, and event-fence prop set.

Replacement GLBs should preserve the current visual/collision split, route clearance, material-library slots, visibility ranges, and MultiMesh-friendly pivots.
