extends "res://modes/fruit_collection/fruit_frenzy_v8_canopy_combat.gd"

## Small lifecycle guard around the phase-2 canopy controller. Swinging temporarily
## disables the racer's own physics callback, so leaving the mode must always hand
## CharacterBody authority back before the scene is freed.

func _physics_process(delta: float) -> void:
	super(delta)
	if _combat_v2_speed_bonus_remaining <= 0.0:
		_combat_v2_speed_bonus_scale = 1.0

func _exit_tree() -> void:
	if player != null and _canopy.get_active_vine_id() != &"":
		_canopy.cancel_vine(player)
	super()
