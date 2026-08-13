# WILD DASH Production Art Bible

## Visual North Star
WILD DASH uses an original stylized arcade-party-racer language: bold silhouettes, cheerful color families, chunky readable forms, restrained surface detail, and high contrast between drivable space, hazards, rewards, and scenery.

### Core principles
- Gameplay readability before detail.
- One strong silhouette idea per racer and hero prop.
- Rounded/chamfered shapes over razor-thin realism.
- Saturated focal colors against quieter environment support colors.
- Simple PBR response: mostly rough surfaces, selective metal, controlled emission.
- Production assets must never redefine gameplay collision by accident.

## Character direction
Playable racers keep a compact body, oversized expressive head, readable species feature, four-limb running silhouette, and a strong back-view identifier.

| Racer | Hero silhouette | Primary palette | Back-view identifier |
| --- | --- | --- | --- |
| Dog | floppy ears + compact muzzle | orange / cream / dark brown | lifted curved tail |
| Rabbit | tall ears + springy hind legs | coral pink / warm white | round tail |
| Cat | triangular ears + long expressive tail | violet / lavender / plum | high curved tail |
| Elephant | broad ears + trunk + heavy feet | slate blue / periwinkle / ivory | wide ears / heavy stance |

NPC animals inherit the same proportion rules but preserve their current gameplay archetypes.

## Environment direction
### Wild World Grand Prix
Warm adventurous nature. Asphalt/dirt readability, cyan/orange event accents, wood/stone supports, bold tunnel and bridge silhouettes.

### Neon Harbor Night Race
Blue-hour industrial city. Deep navy road masses, cyan/magenta emission, warm safety lamps, readable container/warehouse silhouettes.

### Snowpeak Winter Rally
Bright cold daylight. Dark packed road, blue ice, warm resort markers, high-contrast red/orange safety accents against snow.

## Material rules
- Character skin/fur: roughness 0.68-0.86, non-metallic.
- Road: roughness 0.82-0.94, low specular response.
- Painted race accents: roughness 0.55-0.72.
- Metal hero props: metallic 0.45-0.75, roughness 0.38-0.62.
- Neon/emissive signage: emission used only for navigation, landmarks, and mood.
- Snow/ice: snow remains broad and matte; ice gets controlled specular rather than mirror reflection.

## Geometry budgets
### Racers
- Current in-engine production proxy target: approximately 1.5k-4k rendered triangles.
- Authored GLB LOD0 target: 8k-12k triangles.
- LOD1: 45-60% of LOD0.
- LOD2: 15-25% of LOD0.
- Prefer one material per racer, two maximum when a strong accent requires it.

### Props
- Hero prop: 1k-6k triangles.
- Repeated track prop: 100-1.5k triangles.
- Repeated foliage should remain MultiMesh-friendly.

## Naming convention
- Characters: `chr_<species>_<asset>`
- Environment kits: `env_<biome>_<asset>`
- Track props: `trk_<track>_<asset>`
- Materials: `mat_<family>_<variant>`
- Textures: `tex_<asset>_<channel>`
- LOD suffixes: `_lod0`, `_lod1`, `_lod2`
- Collision proxy suffix: `_col`

## Runtime/source split
```text
godot/assets/
  characters/
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
  source/              # Blender/Maya source; .gdignore

godot/characters/visuals/   # gameplay-facing VisualModel wrappers
```

## Import contract
1. Export GLB/glTF with transforms applied and +Y up / -Z forward compatible orientation.
2. Keep gameplay collision outside imported render meshes.
3. Character wrapper owns scale/orientation correction; gameplay controller never references bones directly.
4. Animation semantic contract: `Idle`, `Run`, `Jump`, `Hit`, `Skill`, `Win`, `Lose`.
5. Track GLB replacements must match the existing collision envelope and route clearance.
6. LOD and visibility ranges are set in wrapper scenes, not baked into gameplay logic.

## Priority replacement order
1. Dog / Rabbit / Cat / Elephant presentation quality.
2. Grand Prix finish gate, bridge/tunnel portals, road-edge kit.
3. Neon Harbor signs, container/warehouse hero modules, tunnel lights.
4. Snowpeak snowbank/rail/resort marker kit.
5. Remaining eight NPC animals.
6. Fruit Collection / Push Out hero props.
7. Floor Collapse production-art hook.

## Acceptance guardrails
- No checkpoint, route-point, shortcut, obstacle timing, AI, item, skill, or collision contract changes in an art-only pass.
- New decoration must not create gameplay collision unless an existing collision proxy explicitly owns that job.
- Human-play camera readability must be checked after every hero-prop replacement.
- Missing external GLB assets must degrade to the in-repository production proxy rather than breaking the game.
