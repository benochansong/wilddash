extends Node

const CHARACTER_SELECT_SCENE := "res://scenes/character_select.tscn"

func _ready() -> void:
	var requested_ai := GameManager.MIN_AI_COUNT
	if OS.has_environment("WILDDASH_AI_COUNT"):
		requested_ai = int(OS.get_environment("WILDDASH_AI_COUNT"))

	# Human/Windows play enters the real Character Select. Headless CI keeps
	# the deterministic automatic campaign so existing regression coverage
	# remains stable and does not depend on UI input.
	if DisplayServer.get_name() != "headless":
		GameManager.set_ai_count(requested_ai)
		GameManager.set_state(GameManager.GameState.CHARACTER_SELECT)
		var error := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
		if error != OK:
			push_error("Failed to load Character Select: %s" % error_string(error))
		return

	# Character/chimera selection is owned by GameManager. Main only configures
	# the headless run defaults and must not overwrite a previously selected loadout.
	GameManager.configure_run(&"dog", &"chaos", {}, requested_ai)
	print("WILD DASH 3D four-round campaign ready: ai=%d range=%d..%d" % [GameManager.ai_count, GameManager.MIN_AI_COUNT, GameManager.MAX_AI_COUNT])
	GameManager.start_campaign()
