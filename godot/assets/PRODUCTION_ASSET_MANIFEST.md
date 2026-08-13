# WILD DASH Production Asset Manifest

This manifest defines the hand-authored asset slots that replace the RC7 in-engine production proxies over time without touching gameplay code.

## Playable character slots

| Species | Runtime GLB target | Wrapper scene | Status |
| --- | --- | --- | --- |
| Dog | `assets/characters/playable/dog/chr_dog_lod0.glb` | `characters/visuals/dog_visual.tscn` | RC7 hero production-polish active; GLB pending |
| Rabbit | `assets/characters/playable/rabbit/chr_rabbit_lod0.glb` | `characters/visuals/rabbit_visual.tscn` | RC7 hero production-polish active; GLB pending |
| Cat | `assets/characters/playable/cat/chr_cat_lod0.glb` | `characters/visuals/cat_visual.tscn` | RC7 hero production-polish active; GLB pending |
| Elephant | `assets/characters/playable/elephant/chr_elephant_lod0.glb` | `characters/visuals/elephant_visual.tscn` | RC7 hero production-polish active; GLB pending |

### Required character animation names
`Idle`, `Run`, `Jump`, `Hit`, `Skill`, `Win`, `Lose`

### Character import rules
- Apply transforms before export.
- Keep render mesh collision-free.
- Preserve -Z forward orientation expected by the wrapper.
- LOD0 target: 8k-12k triangles.
- LOD1 target: 45-60% of LOD0.
- LOD2 target: 15-25% of LOD0.
- Prefer one material, two maximum.
- Wrapper scene is responsible for visual scale/orientation correction.

## NPC character slots

All eight race NPC species now receive the same RC7 `WildDashProductionCharacterPolish` layer from `npc_animal_visual.gd`. The base procedural species builder remains authoritative until authored GLBs arrive.

| Species | Runtime GLB target | Runtime wrapper | RC7 status |
| --- | --- | --- | --- |
| Bear | `assets/characters/npc/bear/chr_bear_lod0.glb` | `characters/visuals/bear_visual.tscn` | production-polish active; GLB pending |
| Panda | `assets/characters/npc/panda/chr_panda_lod0.glb` | `characters/visuals/panda_visual.tscn` | production-polish active; GLB pending |
| Fox | `assets/characters/npc/fox/chr_fox_lod0.glb` | `characters/visuals/fox_visual.tscn` | production-polish active; GLB pending |
| Deer | `assets/characters/npc/deer/chr_deer_lod0.glb` | `characters/visuals/deer_visual.tscn` | production-polish active; GLB pending |
| Wolf | `assets/characters/npc/wolf/chr_wolf_lod0.glb` | `characters/visuals/wolf_visual.tscn` | production-polish active; GLB pending |
| Monkey | `assets/characters/npc/monkey/chr_monkey_lod0.glb` | `characters/visuals/monkey_visual.tscn` | production-polish active; GLB pending |
| Boar | `assets/characters/npc/boar/chr_boar_lod0.glb` | `characters/visuals/boar_visual.tscn` | production-polish active; GLB pending |
| Raccoon | `assets/characters/npc/raccoon/chr_raccoon_lod0.glb` | `characters/visuals/raccoon_visual.tscn` | production-polish active; GLB pending |

The NPC gameplay definitions, AI personality, stats and skills are not replaced by art assets.

## Environment kit slots

### Shared
`assets/environments/shared/`
- `env_shared_guardrail_modular.glb`
- `env_shared_finish_gantry.glb`
- `env_shared_race_banner.glb`
- `env_shared_item_station_frame.glb`

### Wild World Grand Prix
`assets/environments/wild_world/`
- `env_wildworld_road_edge_kit.glb`
- `env_wildworld_bridge_kit.glb`
- `env_wildworld_tunnel_portal.glb`
- `env_wildworld_cliff_modules.glb`
- `env_wildworld_tree_family.glb`

### Neon Harbor
`assets/environments/neon_harbor/`
- `env_neon_container_kit.glb`
- `env_neon_warehouse_kit.glb`
- `env_neon_tunnel_kit.glb`
- `env_neon_signage_kit.glb`
- `env_neon_crane_hero.glb`

### Snowpeak
`assets/environments/snowpeak/`
- `env_snowpeak_snowbank_kit.glb`
- `env_snowpeak_resort_kit.glb`
- `env_snowpeak_ice_cave_kit.glb`
- `env_snowpeak_ski_gate.glb`
- `env_snowpeak_safety_marker.glb`

## Collision ownership
Production render assets do not own gameplay collision by default.
Existing hidden/static collision, race barrier controllers, tunnel containment, obstacle collision and checkpoint Areas remain authoritative.
If a production asset needs collision, create a dedicated `_col` proxy and connect it only after validating route clearance.

## LOD / batching
- Repeated foliage and small track props should remain MultiMesh-friendly.
- Hero assets can use normal MeshInstance3D nodes with visibility ranges.
- Never add per-prop `_process()` loops for static scenery.
- Keep small micro detail out of distant LODs.
- RC7 procedural production-polish is a bridge; authored GLBs should replace, not stack indefinitely on top of, equivalent proxy detail.

## Replacement protocol
1. Add GLB under the appropriate asset slot.
2. Create/adjust a wrapper scene, never reference the GLB directly from gameplay scripts.
3. Match the existing visual envelope first.
4. Disable the corresponding RC7 proxy detail only after visual verification.
5. Run Godot import + character/track smoke tests.
6. Human-play the affected camera/track section before merge.
