extends Node

const SELECT_SCENE: PackedScene = preload("res://scenes/character_select.tscn")

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

	screen.call("set_chimera_mode", true)
	screen.call("cycle_chimera_slot", &"head", 1)
	screen.call("cycle_chimera_slot", &"body", 2)
	screen.call("cycle_chimera_slot", &"tail", 3)
	await get_tree().process_frame

	var loadout = screen.call("get_current_loadout") as WildDashChimeraLoadout
	_assert(loadout != null, "chimera loadout missing")
	_assert(loadout.head_id == &"rabbit", "head selection mismatch")
	_assert(loadout.body_id == &"elephant", "body selection mismatch")
	_assert(loadout.tail_id == &"cat", "tail selection mismatch")
	_assert(preview.is_chimera(), "preview did not enter chimera mode")
	_assert(preview.animal_id == &"elephant", "body physics were not applied")
	_assert(preview.get_passive_name() == "Long-Ear Sense", "head passive was not applied")
	_assert(preview.get_skill_name() == "그림자 회피", "tail skill was not applied")

	var saved: bool = bool(screen.call("save_current_selection"))
	_assert(saved, "chimera save failed")
	_assert(GameManager.chimera_enabled, "GameManager chimera flag not enabled")
	var reloaded := SaveManager.load_chimera()
	_assert(reloaded.head_id == &"rabbit" and reloaded.body_id == &"elephant" and reloaded.tail_id == &"cat", "saved chimera did not reload")

	print("CHARACTER SELECT CHIMERA PASS basic=rabbit head=rabbit body=elephant tail=cat")
	get_tree().quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CHARACTER SELECT CHIMERA FAIL: " + message)
	get_tree().quit(1)
