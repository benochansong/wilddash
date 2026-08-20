class_name WildDashFutureItemCatalog
extends RefCounted

## Staged definitions for the next item implementation pass. These are NOT added
## to the live roll pool yet; Item Chaos V2 first validates density/variety using
## the existing 18 proven items.

const COCONUT_CANNON: StringName = &"coconut_cannon"
const VINE_SNARE: StringName = &"vine_snare"
const SEED_SCATTER: StringName = &"seed_scatter"
const BOUNCE_MUSHROOM: StringName = &"bounce_mushroom"

const STAGED_IDS: Array[StringName] = [
	COCONUT_CANNON,
	VINE_SNARE,
	SEED_SCATTER,
	BOUNCE_MUSHROOM,
]

const META: Dictionary = {
	COCONUT_CANNON: {"name": "COCONUT CANNON", "role": &"attack", "knockback": 4.8, "bounces": 1},
	VINE_SNARE: {"name": "VINE SNARE", "role": &"trap", "slow_seconds": 0.8, "handling_scale": 0.72},
	SEED_SCATTER: {"name": "SEED SCATTER", "role": &"utility", "projectiles": 3, "effect_scale": 0.55},
	BOUNCE_MUSHROOM: {"name": "BOUNCE MUSHROOM", "role": &"trap", "vertical_launch": 5.2, "ringout_cap": true},
}

static func get_staged_count() -> int:
	return STAGED_IDS.size()

static func get_meta(item_id: StringName) -> Dictionary:
	return (META.get(item_id, {}) as Dictionary).duplicate(true)
