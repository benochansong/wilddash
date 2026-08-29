# RC7 Character Art Stage 2 — 12-Racer Commercial Polish

## Goal

Extend the RC7 production-art bridge from the four selectable racers to the full 12-animal roster while making Dog, Rabbit, Cat and Elephant read more like hero characters in a commercial stylized party racer.

This stage is visual-only. It does not modify gameplay collision, physics, AI, skills, stats, checkpoints, route geometry or race rules.

## Shared system

All twelve racers now use `WildDashProductionCharacterPolish` as the common visual-detail layer.

- Playable characters attach it explicitly in their wrapper scenes.
- NPC characters attach it automatically from `npc_animal_visual.gd` after the species base mesh is generated.
- The polish layer writes only MeshInstance3D presentation detail under `ImportedModel`.
- Headless execution skips the production-detail layer.
- Final authored GLBs can replace these proxy details without changing CharacterController or gameplay code.

## Hero playable polish

### Dog
Commercial read: friendly default mascot / balanced racer.

Added or reinforced:
- cream chest bib and paw cuffs
- teal collar and side race panels
- orange collar tag and hero badge
- dark back identifier and cream tail tip
- soft cheek color accents

### Rabbit
Commercial read: fast, cheerful, high-energy racer.

Added or reinforced:
- white chest and hind-paw definition
- coral inner ears and cheek accents
- mint runner band
- berry shoulder stripes
- white forehead blaze

### Cat
Commercial read: agile, stylish, slightly mischievous racer.

Added or reinforced:
- lavender chest and ear insets
- dark plum back stripes
- gold collar, bell and race side panels
- pink cheek accents and hero badge
- lavender tail-tip identifier

### Elephant
Commercial read: powerful but warm heavy-class racer.

Added or reinforced:
- soft inner-ear treatment
- ivory foot cuffs and trunk-tip accent
- cyan race harness and forehead mark
- navy harness wings / badge
- subtle coral cheek accents

## NPC roster polish

### Bear
Identity: dependable heavy racer.
- cream belly / ear insets
- teal race sash
- honey medal and paw cuffs
- dark back stripe

### Panda
Identity: soft, readable heavy racer with high contrast.
- white belly / forehead highlight
- mint race sash
- yellow bamboo-style badge
- black paw cuffs

### Fox
Identity: nimble shortcut specialist.
- cream chest and ear insets
- cyan speed band
- orange speed badge
- dark front paw socks

### Deer
Identity: elegant trail runner.
- cream chest
- mint trail band
- forest badge / hoof cuffs
- repeated back spots for instant silhouette recognition

### Wolf
Identity: focused pack racer.
- silver chest mane / ear inset
- cyan scout band
- navy badge and paw cuffs

### Monkey
Identity: playful technical racer.
- tan belly patch
- mango adventure band
- aqua badge and wrist cuffs
- tail band accent

### Boar
Identity: compact power racer.
- cream chest and forehead stripe
- orange power harness
- coral power badge
- dark hoof cuffs

### Raccoon
Identity: clever item-fighter racer.
- cream chest
- violet bandit scarf
- teal scarf badge / tail accent
- dark paw cuffs

## Readability rules preserved

- Face direction remains -Z forward.
- Character silhouette remains inside the existing gameplay envelope.
- No CollisionShape3D is added by this art layer.
- High-chroma accents are concentrated around torso/neck so they remain visible from chase-camera distance.
- Small details are intentionally limited to avoid production-proxy clutter.
- Existing species-specific ears, tails, antlers, tusks and masks remain the primary silhouette cues.

## Performance intent

The Stage 2 details are lightweight primitive meshes intended as temporary commercial-quality proxy presentation, not permanent final production geometry.

For final authored characters:
- LOD0: 8k-12k triangles
- LOD1: 45-60% of LOD0
- LOD2: 15-25% of LOD0
- 1 material preferred, 2 maximum
- remove equivalent RC7 proxy detail after GLB acceptance

## Validation still required before merge

1. Godot 4.7.1 import / script parse.
2. Character-select visual review of Dog, Rabbit, Cat and Elephant.
3. Dense 15/18-racer race camera review to check visual clutter.
4. Verify oversized details do not visually intersect track props at start-grid spacing.
5. Confirm headless CI remains unaffected by skipped production-detail execution.

## Next art step after validation

Do not keep stacking procedural geometry indefinitely. Once this Stage 2 proxy language is accepted, the highest-value next step is authored GLB replacement in this order:

1. Dog
2. Rabbit
3. Cat
4. Elephant
5. Fox / Panda / Bear / Raccoon
6. Deer / Wolf / Monkey / Boar

The GLB pass should preserve the color-blocking and silhouette identities established here while replacing primitive proxy forms with properly modeled, rigged and animated production assets.
