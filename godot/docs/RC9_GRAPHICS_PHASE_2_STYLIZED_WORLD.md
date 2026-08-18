# RC9 Graphics Phase 2 — Premium Stylized Animal World

## Goal

Reduce the visible prototype-primitive feeling without changing gameplay. This pass sits on top of the existing Graphics Phase 1 lighting, material, color and performance structure.

The gameplay contract is unchanged: no route layout, platform gap, collision, AI, recovery, racer stat or combat-balance changes are part of this pass.

## Character layer

Every shared racer scene now owns a `PremiumCharacterArt` child in addition to the existing RC7 `ProductionCharacterPolish` layer.

Active RC9 roster:

- Dog
- Wolf
- Boar
- Rabbit
- Deer
- Monkey
- Elephant
- Bear
- Crocodile
- Cat
- Fox
- Raccoon

The premium layer strengthens silhouette with visual-only geometry. Rabbit gets taller hero ears and larger spring feet. Elephant gets broader ears, shoulders, feet and trunk volume. Bear gets heavier shoulders and paws. Crocodile gets stronger dorsal scutes and a longer power tail. Monkey gets long arms and larger expressive hands. Fox gets a much stronger tail and cheek/chest tufts. Other racers receive equivalent back-view and species-readability reinforcement.

## Sculpted fur

No photoreal fur or expensive hair simulation is used. Fur is represented by broad sculpted clusters on cheeks, head, chest and tail areas. Small-detail noise is intentionally avoided so racers remain readable from a chase camera.

## Expression system

The new visual expression rig prepares nine states:

- Neutral
- Happy
- Jump
- Surprised
- Hit
- Angry
- Boost
- Falling
- Victory

It also includes lightweight blinking. The system is visual-only and exposes `set_expression` plus `notify_visual_action` for future animation integration. Current automatic runtime inference covers neutral, jump, falling, hit, boost and victory while the remaining expressions are available to authored animation/event hooks.

## Secondary motion

A procedural presentation layer supplies small ear bounce, tail follow, head tuft motion, chest tuft movement and belly bounce. It is sinusoidal/damped visual motion only. No RigidBody, PhysicalBone, SoftBody or gameplay physics authority is introduced.

## Four-layer environment composition

Every round receives four visual depth roots:

1. Foreground Detail
2. Gameplay Art Layer
3. Background Detail
4. Far Background Silhouette

This gives screenshots depth without filling the racing corridor with collision props.

## Round 1 — Sunny Safari Adventure

Key additions:

- MultiMesh grass
- rock scatter
- race flags
- small wildlife silhouettes
- distant hills
- Baobab hero tree
- Sunstone race arch
- Adventure balloon

Landmarks: `SafariBaobab`, `SunstoneRaceArch`, `AdventureBalloon`.

## Round 2 — Juicy Tropical Festival

Key additions:

- tropical foliage
- festival bunting
- fruit basket clusters
- fruit market pavilion
- Golden Fruit shrine
- giant juice festival tower

Landmarks: `FruitMarketPavilion`, `GoldenFruitShrine`, `JuiceFestivalTower`.

## Round 3 — Magical Giant Forest

This is the highest-priority environment pass.

Key additions:

- visual Root/Bark sleeves beneath alternating Safe Route transitions
- moss route highlights
- MultiMesh ferns
- mooncap mushrooms
- magical firefly lights
- distant ancient-tree silhouettes
- limited sun shafts
- Titan Root Cathedral
- Mooncap Grove
- Ancient Firefly Gate

The Root/Bark sleeves read route coordinates from `LogspireWorld.get_main_route_points()` and add render geometry only. They do not replace or alter the platform collision geometry.

Landmarks: `TitanRootCathedral`, `MooncapGrove`, `AncientFireflyGate`.

## Round 4 — Animal Titan Arena

Key additions:

- audience banners
- perimeter totems
- arena impact marks
- giant Titan gate
- champion totem pair
- champion crown dais

Landmarks: `TitanGate`, `ChampionTotems`, `ChampionDais`.

## Round 5 — Neon Night Festival

Key additions:

- harbor festival lights
- container silhouettes
- city skyline
- wet side-puddle reflections without changing race-road collision/material authority
- holographic-style tower bands
- festival crane
- Final Festival gate

Landmarks: `HoloHarborTower`, `FestivalCrane`, `FinalFestival`.

## Performance rules

Repeated grass, foliage, ferns, mushrooms, lights, rocks, flags, containers and totems use MultiMesh where practical. Visual geometry uses `visibility_range_end`. Most materials remain opaque. Alpha transparency is limited to the small three-shaft magical forest effect. Headless mode does not build Phase 2 art.

Racers keep high visual contrast; dense decoration is biased away from the central gameplay corridor when possible.

## Production reality

This pass is a substantial upgrade to the in-engine procedural production proxy, but it is not a substitute for final authored Blender/Maya character and environment GLBs. The existing Production Art Bible remains the final asset pipeline contract. Once the new silhouette/color direction is accepted in manual playtest, hero characters and landmarks should eventually be replaced by authored LOD-ready assets rather than endlessly stacking procedural detail.

## Manual Godot 4.7.1 validation

Before PR #34 can leave Draft:

1. Open the project with zero GDScript parser errors.
2. Inspect all 12 active racers in Character Select and in a 15-racer race.
3. Check face overlays from front/three-quarter/chase views.
4. Verify secondary motion is subtle and does not visually detach from the base model.
5. Run R1 through R5 and confirm no new art blocks the camera or visually hides the route.
6. In R3 verify Root/Bark sleeves stay below the actual safe landing surface and do not resemble new collision floors.
7. Verify R4 arena landmarks remain outside combat space.
8. Verify R5 neon decoration does not overpower racer readability.
9. Measure FPS in 5, 15 and 18-racer stress tests.
10. Keep PR #34 Draft until the full manual visual/performance pass succeeds.
