extends "res://modes/logspire_leap/logspire_water_recovery_v4_deep_swim.gd"

## Water recovery must resolve through a ladder during normal play.
## Time spent swimming is never, by itself, a reason to restart at a checkpoint.
## Reaching the visible front of a ladder captures the racer immediately.

const INSTANT_LADDER_CAPTURE_RADIUS: float = 4.25

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var ladder: Dictionary = _resolve_water_ladder(racer)
	if not ladder.is_empty():
		_ladder_by_id[racer_id] = ladder
		var bottom_value: Variant = ladder.get("bottom", racer.global_position)
		var bottom: Vector3 = bottom_value if bottom_value is Vector3 else racer.global_position
		var distance: float = Vector2(
			racer.global_position.x - bottom.x,
			racer.global_position.z - bottom.z
		).length()
		if distance <= INSTANT_LADDER_CAPTURE_RADIUS:
			var snap := racer.global_position
			snap.x = bottom.x
			snap.z = bottom.z
			racer.global_position = snap
			print("LOGSPIRE LADDER INSTANT CAPTURE racer=%s ladder=%s distance=%.2f" % [
				RaceManager.get_racer_label(racer), String(ladder.get("id", &"")), distance,
			])
			_begin_ladder_climb(racer, ladder)
			return
	super(racer, delta)

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	if bool(racer.get_meta(WATER_META, false)):
		var racer_id: int = racer.get_instance_id()
		var ladder: Dictionary = _resolve_water_ladder(racer)
		if not ladder.is_empty():
			_ladder_by_id[racer_id] = ladder
			_water_elapsed_by_id[racer_id] = 0.0
			_state_by_id[racer_id] = WaterState.SWIMMING
			if racer.is_player and DisplayServer.get_name() != "headless":
				_set_hud_message("KEEP SWIMMING · LADDER RECOVERY ONLY")
			print("LOGSPIRE WATER NO RESTART racer=%s reason=%s ladder=%s checkpoint_respawn=false" % [
				RaceManager.get_racer_label(racer), reason, String(ladder.get("id", &"")),
			])
			return
		_water_elapsed_by_id[racer_id] = 0.0
		_state_by_id[racer_id] = WaterState.SWIMMING
		print("LOGSPIRE WATER NO RESTART racer=%s reason=%s ladder=SEARCHING checkpoint_respawn=false" % [
			RaceManager.get_racer_label(racer), reason,
		])
		return
	super(racer, reason)

func _resolve_water_ladder(racer: WildDashCharacterController) -> Dictionary:
	if racer == null or _ladder_system == null or _water_ai == null:
		return {}
	var racer_id: int = racer.get_instance_id()
	var current_value: Variant = _ladder_by_id.get(racer_id, {})
	if current_value is Dictionary:
		var current: Dictionary = current_value
		if not current.is_empty():
			return current
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var candidates: Array = _ladder_system.call("get_ladders_for_zone", zone)
	if candidates.is_empty():
		candidates = _ladder_system.call("get_all_ladders")
	var result: Variant = _water_ai.call(
		"choose_ladder",
		racer,
		zone,
		candidates,
		RaceManager.get_checkpoint_progress(racer)
	)
	if result is Dictionary:
		return result
	return {}
