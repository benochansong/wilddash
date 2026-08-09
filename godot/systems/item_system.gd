extends Node

signal item_granted(character: Node, item_id: StringName)
signal item_used(character: Node, item_id: StringName)

const ITEM_IDS: Array[StringName] = [&"banana", &"shield", &"magnet", &"ink"]

func is_valid_item(item_id: StringName) -> bool:
	return ITEM_IDS.has(item_id)

func grant_item(character: Node, item_id: StringName) -> bool:
	if character == null or not is_valid_item(item_id) or not character.has_method("set_held_item"):
		return false
	character.call("set_held_item", item_id)
	item_granted.emit(character, item_id)
	return true

func use_held_item(character: Node) -> bool:
	if character == null or not character.has_method("get_held_item") or not character.has_method("set_held_item"):
		return false
	var item_id: StringName = character.call("get_held_item")
	if item_id == &"":
		return false
	character.call("set_held_item", &"")
	# First-stage Godot scaffold intentionally does not implement the final effect.
	# Production banana/shield/magnet/ink behavior will live here or in item scenes.
	item_used.emit(character, item_id)
	return true
