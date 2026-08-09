# WILD DASH 3D — Character System V2

This phase rebuilds the playable animal layer without touching the preserved React/Electron Prototype V1 or the Windows RC1 release branch.

## Architecture

```text
CharacterRoot (CharacterBody3D)
├─ CollisionShape3D       <- generated from AnimalDefinition
└─ VisualSlot
   └─ VisualModel         <- swappable per animal
      └─ ImportedModel
         ├─ Skeleton3D
         ├─ low-poly placeholder meshes OR imported GLB
         └─ AnimationPlayer / AnimationTree
```

`CharacterController` depends on `WildDashAnimalDefinition` and the stable `WildDashCharacterVisual` interface. It never depends on Dog/Rabbit/Elephant/Cat mesh node paths.

Production GLB replacement therefore happens inside each animal's `visual_scene` only.

## Current four-animal identity

| Animal | Role | Max speed | Jump | Collision radius | Skill | Cooldown | Camera feel |
|---|---|---:|---:|---:|---|---:|---|
| Dog / 멍대시 | Balanced Runner | 14.5 | 7.5 | 0.62 | 균형 질주: speed ×1.18 for 2.5s | 12s | balanced chase |
| Rabbit / 깡총이 | Agile Jumper | 14.0 | 9.2 | 0.52 | 도약 추진: high leap + short boost | 8s | closer / responsive |
| Elephant / 코뿜이 | Heavy Tank | 13.1 | 6.1 | 0.80 | 코 방어: knockback ×0.35 | 10s | wider / heavier |
| Cat / 냥쏘 | Evasive Sprinter | 14.2 | 7.8 | 0.50 | 그림자 회피: speed/turn boost, reduced knockback | 9s | close / fast smoothing |

The cooldowns preserve the existing Godot/Race3D prototype values: 12 / 8 / 10 / 9 seconds.

## Placeholder visuals

The current model files are intentionally low-cost procedural/primitive scenes:

- `characters/visuals/dog_visual.tscn`
- `characters/visuals/rabbit_visual.tscn`
- `characters/visuals/elephant_visual.tscn`
- `characters/visuals/cat_visual.tscn`

They are not production art. Their job is to make body size, silhouette and gameplay identity visible before final Blender/Maya models arrive.

Each placeholder includes the future production contract nodes `Skeleton3D` and `AnimationPlayer`.

## Animation contract

Every animal supports these semantic states:

- Idle
- Run
- Jump
- Hit
- Skill
- Win
- Lose

The low-poly placeholders animate procedurally to make the states visible today. A production GLB can replace this with imported clips or an AnimationTree without changing `CharacterController`.

## Selection behavior

`WildDashModeController.spawn_racer()` now resolves the player animal from `GameManager.selected_animal`. This applies Character Select consistently to Grand Prix, Fruit Collection, Floor Collapse and Push-Out.

AI racers continue to rotate through Dog/Rabbit/Elephant/Cat independently.

## Automated character gate

`tests/character_system_smoke.tscn` instantiates all four animals and verifies:

- unique AnimalDefinition
- unique visual scene
- VisualModel exists
- Skeleton3D exists
- AnimationPlayer exists
- collision radius and height match the definition
- movement values match the definition
- all seven animation states are accepted
- skill activates with the correct cooldown
- camera profile is complete

The CI success marker is:

```text
CHARACTER SYSTEM PASS animals=4 states=7
```

## Next art step

Do not modify `CharacterController` when production art arrives.

For each animal:

1. Create the final low-poly model in Blender or Maya.
2. Rig one Skeleton.
3. Export Idle/Run/Jump/Hit/Skill/Win/Lose in GLB.
4. Import GLB into Godot.
5. Wrap it in that animal's VisualModel scene.
6. Disable `procedural_placeholder`.
7. Map the imported AnimationPlayer/AnimationTree.
8. Run the character smoke test and four-round campaign regression.

Chimera composition is intentionally a separate phase after these four base animals are stable.
