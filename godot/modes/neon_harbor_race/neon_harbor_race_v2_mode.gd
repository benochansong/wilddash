extends "res://modes/neon_harbor_race/neon_harbor_race_mode.gd"

## Neon Harbor V2 development adapter.
##
## Direct F6 scene runs do not go through Character Select, so explicitly
## restore the last persisted playable racer before the inherited Round 3
## setup spawns the player. Normal campaign runs keep the in-memory selection
## from Character Select untouched.
##
## Ability shortcuts and tactical lane branches belong to Phase 3. Until the
## grounded route is graphically proven, every AI shortcut request is routed
## back to the authoritative main course so Phase 1 validates one clean path.

func _ready() -> void:
	var direct_scene_test: bool = not GameManager.campaign_running
	if direct_scene_test:
		var saved_animal: StringName = SaveManager.get_last_character()
		if WildDashAnimalCatalog.is_playable(saved_animal):
			GameManager.selected_animal = saved_animal
		else:
			GameManager.selected_animal = &"dog"
		print("NEON HARBOR F6 TEST CHARACTER selected=%s saved=%s fallback=%s" % [
			String(GameManager.selected_animal),
			String(saved_animal),
			str(not WildDashAnimalCatalog.is_playable(saved_animal)),
		])
	else:
		print("NEON HARBOR CAMPAIGN CHARACTER selected=%s" % String(GameManager.selected_animal))

	super._ready()

func _build_shortcut_route(_skip_route_index: int) -> Array[Vector3]:
	return _build_race_route_with_runout()
