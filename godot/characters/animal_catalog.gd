class_name WildDashAnimalCatalog
extends RefCounted

# RC9 keeps a 12-animal active roster. Panda remains in the repository as a
# future unlock/expansion character but Crocodile now owns the active heavy slot.
const CHIMERA_IDS: Array[StringName] = [&"dog", &"rabbit", &"elephant", &"cat"]
const PLAYABLE_IDS: Array[StringName] = [
	&"dog", &"wolf", &"boar",
	&"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"crocodile",
	&"cat", &"fox", &"raccoon",
]
# Compatibility group for the species that began life as NPC-only racers.
const NPC_IDS: Array[StringName] = [&"fox", &"bear", &"raccoon", &"crocodile", &"wolf", &"boar", &"deer", &"monkey"]
const RACE_ROSTER_IDS: Array[StringName] = [
	&"dog", &"fox", &"rabbit", &"bear", &"cat", &"raccoon",
	&"elephant", &"crocodile", &"wolf", &"boar", &"deer", &"monkey",
]

const PATHS := {
	&"dog": "res://characters/definitions/dog.tres",
	&"rabbit": "res://characters/definitions/rabbit.tres",
	&"elephant": "res://characters/definitions/elephant.tres",
	&"cat": "res://characters/definitions/cat.tres",
	&"fox": "res://characters/definitions/fox.tres",
	&"bear": "res://characters/definitions/bear.tres",
	&"raccoon": "res://characters/definitions/raccoon.tres",
	&"panda": "res://characters/definitions/panda.tres",
	&"crocodile": "res://characters/definitions/crocodile.tres",
	&"wolf": "res://characters/definitions/wolf.tres",
	&"boar": "res://characters/definitions/boar.tres",
	&"deer": "res://characters/definitions/deer.tres",
	&"monkey": "res://characters/definitions/monkey.tres",
}

static func get_definition(animal_id: StringName) -> WildDashAnimalDefinition:
	var path: String = PATHS.get(animal_id, PATHS[&"dog"])
	var definition := load(path) as WildDashAnimalDefinition
	if definition == null:
		push_error("Failed to load animal definition: %s" % path)
	return definition

static func all_ids() -> Array[StringName]:
	return PLAYABLE_IDS.duplicate()

static func playable_ids() -> Array[StringName]:
	return PLAYABLE_IDS.duplicate()

static func chimera_ids() -> Array[StringName]:
	return CHIMERA_IDS.duplicate()

static func npc_ids() -> Array[StringName]:
	return NPC_IDS.duplicate()

static func race_roster_ids() -> Array[StringName]:
	return RACE_ROSTER_IDS.duplicate()

static func all_known_ids() -> Array[StringName]:
	var ids := PLAYABLE_IDS.duplicate()
	if not ids.has(&"panda"):
		ids.append(&"panda")
	return ids

static func get_race_npc_id(index: int) -> StringName:
	if RACE_ROSTER_IDS.is_empty():
		return &"dog"
	return RACE_ROSTER_IDS[posmod(index, RACE_ROSTER_IDS.size())]

static func all_definitions() -> Array[WildDashAnimalDefinition]:
	var definitions: Array[WildDashAnimalDefinition] = []
	for animal_id: StringName in PLAYABLE_IDS:
		var definition := get_definition(animal_id)
		if definition != null:
			definitions.append(definition)
	return definitions

static func npc_definitions() -> Array[WildDashAnimalDefinition]:
	var definitions: Array[WildDashAnimalDefinition] = []
	for animal_id: StringName in NPC_IDS:
		var definition := get_definition(animal_id)
		if definition != null:
			definitions.append(definition)
	return definitions

static func is_playable(animal_id: StringName) -> bool:
	return PLAYABLE_IDS.has(animal_id)

static func is_chimera_part(animal_id: StringName) -> bool:
	return CHIMERA_IDS.has(animal_id)

static func is_npc(animal_id: StringName) -> bool:
	return NPC_IDS.has(animal_id)

static func is_valid(animal_id: StringName) -> bool:
	return PATHS.has(animal_id)
