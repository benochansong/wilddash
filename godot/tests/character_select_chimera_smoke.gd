extends Node

const SELECT_SCENE: PackedScene = preload("res://scenes/character_select.tscn")
var _failed := false

func _ready() -> void:
	var screen := SELECT_SCENE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().physics_frame

	var preview = screen.call("get_preview_racer") as WildDashCharacterController
	_assert(preview != null, "preview racer missing")

	screen.call("select_animal", &"rabbit")
	await get_tree().process_frame
	_assert(not preview.is_chimera(), "basic animal unexpectedly chimera")
	_assert(preview.animal_id == &"rabbit", "rabbit selection did not reach preview")
	_assert(preview.get_skill_name() == "SPRING LEAP", "basic rabbit skill mismatch")

	screen.call("set_chimera_mode", true)
	_cycle_to(screen, &"head", &"rabbit")
	_cycle_to(screen, &"body", &"elephant")
	_cycle_to(screen, &"tail", &"cat")
	await get_tree().process_frame

	var loadout = screen.call("get_current_loadout") as WildDashChimeraLoadout
	_assert(loadout != null, "chimera loadout missing")
	_assert(loadout.head_id == &"rabbit", "head selection mismatch")
	_assert(loadout.body_id == &"elephant", "body selection mismatch")
	_assert(loadout.tail_id == &"cat", "tail selection mismatch")
	_assert(preview.is_chimera(), "preview did not enter chimera mode")
	_assert(preview.animal_id == &"elephant", "body chassis was not applied")
	_assert(preview.get_skill_name() == "SPRING LEAP", "head skill was not applied")
	_assert(preview.get_passive_name() == "HEAVY FRAME", "body passive was not applied")
	_assert(preview.get_utility_name() == "REFLEX TAIL", "tail utility was not applied")

	var saved: bool = bool(screen.call("save_current_selection"))
	_assert(saved, "chimera save failed")
	_assert(GameManager.chimera_enabled, "GameManager chimera flag not enabled")
	var reloaded := SaveManager.load_chimera()
	_assert(reloaded.head_id == &"rabbit" and reloaded.body_id == &"elephant" and reloaded.tail_id == &"cat", "saved chimera did not reload")

	if _failed:
		get_tree().quit(1)
		return
	print("CHARACTER SELECT CHIMERA PASS basic=rabbit head=rabbit body=elephant tail=cat")
	get_tree().quit(0)

func _cycle_to(screen: Node, slot: StringName, target: StringName) -> void:
	for _i in range(5):
		var current := screen.call("get_current_loadout") as WildDashChimeraLoadout
		var value: StringName = current.head_id
		if slot == &"body":
			value = current.body_id
		elif slot == &"tail":
			value = current.tail_id
		if value == target:
			return
		screen.call("cycle_chimera_slot", slot, 1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("CHARACTER SELECT CHIMERA FAIL: " + message)
