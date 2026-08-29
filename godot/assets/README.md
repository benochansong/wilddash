# Assets

WILD DASH 3D separates runtime assets from Blender/Maya source files.

```text
assets/
  source/                     Blender/Maya source; excluded by `.gdignore`
    characters/
    environments/

  characters/                 Imported GLB/glTF runtime assets
    playable/
    npc/

  environments/
    shared/
    wild_world/
    neon_harbor/
    snowpeak/

  materials/
    characters/
    environment/

  textures/
  props/
  items/
```

Base production flow:

```text
Blender / Maya source
→ GLB or glTF 2.0 export
→ assets/characters or assets/environments
→ Godot import
→ gameplay-facing wrapper scene
→ gameplay scene
```

Character GLBs are never connected directly to `CharacterController`.
`characters/visuals/*_visual.tscn` owns imported model / Skeleton / Animation implementation while `CharacterRoot` remains responsible for physics, collision and gameplay.

RC7 adds an in-engine **production-detail proxy layer** for Dog, Rabbit, Cat and Elephant. It improves silhouette/detail immediately while the final authored GLBs are being produced. The proxy is visual-only and can be removed when the corresponding wrapper switches to a production GLB.

Race-track production dressing follows the same rule: visual hero markers never replace the existing hidden collision, checkpoint, shortcut or AI-route contracts.

See:
- [`CHARACTER_PIPELINE.md`](./CHARACTER_PIPELINE.md) — character export/import contract
- [`PRODUCTION_ASSET_MANIFEST.md`](./PRODUCTION_ASSET_MANIFEST.md) — concrete GLB slots and replacement order
- [`../docs/PRODUCTION_ART_BIBLE.md`](../docs/PRODUCTION_ART_BIBLE.md) — WILD DASH art direction, palettes, budgets and naming
