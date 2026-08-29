extends "res://modes/push_out/wild_rumble_round4_canopy_combat.gd"

## Lifecycle and shrinking-ring safety around the Monkey canopy controller.
## Final Duel must disable traversal without leaving the player CharacterBody's
## own physics callback switched off.

func _physics_process(delta: float) -> void:
	super(delta)
	if _round4_profile_speed_bonus_remaining <= 0.0:
		_round4_profile_speed_bonus_scale = 1.0

func _update_round4_vine_availability() -> void:
	if _round4_canopy_routes.is_empty():
		return
	var alive: int = _round4_alive_count()
	var allowed: int = 3
	if alive <= 2:
		allowed = 0
	elif alive <= 3:
		allowed = 1
	elif alive <= 5:
		allowed = 2
	allowed = mini(allowed, _round4_canopy_routes.size())
	if allowed == _round4_canopy_allowed_count:
		return
	var active_id: StringName = _round4_canopy.get_active_vine_id()
	for i: int in range(_round4_canopy_routes.size()):
		var enabled: bool = i < allowed
		_round4_canopy_routes[i].enabled = enabled
		if i < _round4_canopy_visuals.size() and _round4_canopy_visuals[i] != null:
			_round4_canopy_visuals[i].visible = enabled
	if active_id != &"":
		var active_still_enabled: bool = false
		for i: int in range(allowed):
			if _round4_canopy_routes[i].vine_id == active_id:
				active_still_enabled = true
				break
		if not active_still_enabled:
			_round4_canopy.cancel_vine(player)
			if player != null:
				player.velocity.y = maxf(player.velocity.y, 2.0)
	_round4_canopy_allowed_count = allowed
	print("MONKEY CANOPY R4 availability alive=%d vines=%d" % [alive, allowed])

func _exit_tree() -> void:
	if player != null and _round4_canopy.get_active_vine_id() != &"":
		_round4_canopy.cancel_vine(player)
