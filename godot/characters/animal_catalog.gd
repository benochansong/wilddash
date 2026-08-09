class_name WildDashAnimalCatalog
extends RefCounted

const PATHS := {
	&"dog": "res://characters/definitions/dog.tres",
	&"rabbit": "res://characters/definitions/rabbit.tres",
	&"elephant": "res://characters/definitions/elephant.tres",
	&"cat": "res://characters/definitions/cat.tres",
}

static func get_definition(animal_id: StringName) -> WildDashAnimalDefinition:
	var path: String = PATHS.get(animal_id, PATHS[&"dog"])
	var definition := load(path) as WildDashAnimalDefinition
	if definition == null:
		push_error("Failed to load animal definition: %s" % path)
	return definition

static func all_ids() -> Array[StringName]:
	return [&"dog", &"rabbit", &"elephant", &"cat"]

static func all_definitions() -> Array[WildDashAnimalDefinition]:
	var definitions: Array[WildDashAnimalDefinition] = []
	for animal_id: StringName in all_ids():
		var definition := get_definition(animal_id)
		if definition != null:
			definitions.append(definition)
	return definitions

static func is_valid(animal_id: StringName) -> bool:
	return PATHS.has(animal_id)
