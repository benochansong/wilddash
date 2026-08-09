class_name WildDashChimeraLoadout
extends Resource

## Serializable three-slot chimera configuration.
## Gameplay meaning is intentionally stable:
## - head: passive trait
## - body: movement/collision/camera base
## - tail: active skill source

@export var head_id: StringName = &"dog"
@export var body_id: StringName = &"rabbit"
@export var tail_id: StringName = &"elephant"
@export var palette_id: StringName = &"classic"
@export var pattern_id: StringName = &"stripe"

func normalize() -> void:
	if not WildDashAnimalCatalog.is_valid(head_id):
		head_id = &"dog"
	if not WildDashAnimalCatalog.is_valid(body_id):
		body_id = &"dog"
	if not WildDashAnimalCatalog.is_valid(tail_id):
		tail_id = &"dog"
	if not WildDashChimeraSystem.is_valid_palette(palette_id):
		palette_id = &"classic"
	if not WildDashChimeraSystem.is_valid_pattern(pattern_id):
		pattern_id = &"stripe"

func to_dictionary() -> Dictionary:
	normalize()
	return {
		"head": String(head_id),
		"body": String(body_id),
		"tail": String(tail_id),
		"palette": String(palette_id),
		"pattern": String(pattern_id),
	}

func duplicate_loadout() -> WildDashChimeraLoadout:
	var copy := WildDashChimeraLoadout.new()
	copy.head_id = head_id
	copy.body_id = body_id
	copy.tail_id = tail_id
	copy.palette_id = palette_id
	copy.pattern_id = pattern_id
	copy.normalize()
	return copy

static func from_dictionary(data: Dictionary) -> WildDashChimeraLoadout:
	var loadout := WildDashChimeraLoadout.new()
	loadout.head_id = StringName(str(data.get("head", "dog")))
	loadout.body_id = StringName(str(data.get("body", "dog")))
	loadout.tail_id = StringName(str(data.get("tail", "dog")))
	loadout.palette_id = StringName(str(data.get("palette", "classic")))
	loadout.pattern_id = StringName(str(data.get("pattern", "stripe")))
	loadout.normalize()
	return loadout
