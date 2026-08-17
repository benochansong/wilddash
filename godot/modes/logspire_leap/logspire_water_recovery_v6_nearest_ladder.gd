extends "res://modes/logspire_leap/logspire_water_recovery_v5_ladder_priority.gd"

## Player-tested ladder reliability pass.
## V5 could keep a stale route-aware ladder target even when the player was
## physically touching a much closer ladder. V6 gives nearby physical ladders
## priority and scales climb time by actual ladder height.

const NEARBY_LADDER_CAPTURE_RADIUS: float = 5.25
const NEARBY_LADDER_SWITCH_ADVANTAGE: float = 6.0
const NEARBY_LADDER_MAX_VERTICAL_DELTA: float = 2.5
const LADDER_CLIMB_SPEED_MPS: float = 8.0
const LADDER_CLIMB_MIN_SECONDS: float = 1.4
const LADDER_CLIMB_MAX_SECONDS: float = 5.5

var _climb_duration_by_id: Dictionary = {}

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	var racer_id: int = racer.get_instance_id()
	var nearest: Dictionary = _nearest_physical_ladder(racer)
	if not nearest.is_empty():
		var current_value: Variant = _ladder_by_id.get(racer_id, {})
		var current: Dictionary = current_value if current_value is Dictionary else {}
		var nearest_distance: float = _planar_distance_to_ladder(racer, nearest)
		var current_distance: float = INF
		if not current.is_empty():
			current_distance = _planar_distance_to_ladder(racer, current)
		if current.is_empty() or nearest_distance + NEARBY_LADDER_SWITCH_ADVANTAGE < current_distance:
			_ladder_by_id[racer_id] = nearest
			if racer.is_player and DisplayServer.get_name() != "headless":
				_set_hud_message("RECOVERY ROUTE · NEAREST LADDER %.0fm · CLIMB!" % nearest_distance)
			print("LOGSPIRE LADDER TARGET SWITCH racer=%s ladder=%s old_distance=%.2f new_distance=%.2f nearest_priority=true" % [
				RaceManager.get_racer_label(racer),
				String(nearest.get("id", &"")),
				current_distance,
				nearest_distance,
			])
		if nearest_distance <= NEARBY_LADDER_CAPTURE_RADIUS:
			_ladder_by_id[racer_id] = nearest
			var bottom_value: Variant = nearest.get("bottom", racer.global_position)
			var bottom: Vector3 = bottom_value if bottom_value is Vector3 else racer.global_position
			var snap := racer.global_position
			snap.x = bottom.x
			snap.z = bottom.z
			racer.global_position = snap
			print("LOGSPIRE LADDER NEAREST CAPTURE racer=%s ladder=%s distance=%.2f radius=%.2f" % [
				RaceManager.get_racer_label(racer), String(nearest.get("id", &"")), nearest_distance, NEARBY_LADDER_CAPTURE_RADIUS,
			])
			_begin_ladder_climb(racer, nearest)
			return
	super(racer, delta)

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	var racer_id: int = racer.get_instance_id()
	var bottom_value: Variant = ladder.get("bottom", racer.global_position)
	var exit_value: Variant = ladder.get("exit", racer.global_position + Vector3.UP * 4.0)
	var bottom: Vector3 = bottom_value if bottom_value is Vector3 else racer.global_position
	var exit_position: Vector3 = exit_value if exit_value is Vector3 else racer.global_position + Vector3.UP * 4.0
	var climb_height: float = maxf(1.0, exit_position.y - bottom.y)
	var duration: float = clampf(climb_height / LADDER_CLIMB_SPEED_MPS, LADDER_CLIMB_MIN_SECONDS, LADDER_CLIMB_MAX_SECONDS)
	_climb_duration_by_id[racer_id] = duration
	var snap := racer.global_position
	snap.x = bottom.x
	snap.z = bottom.z
	snap.y = maxf(snap.y, bottom.y)
	racer.global_position = snap
	super(racer, ladder)
	print("LOGSPIRE LADDER CLIMB PROFILE racer=%s ladder=%s height=%.2f duration=%.2f speed=%.1f" % [
		RaceManager.get_racer_label(racer), String(ladder.get("id", &"")), climb_height, duration, LADDER_CLIMB_SPEED_MPS,
	])

func _update_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	var racer_id: int = racer.get_instance_id()
	var elapsed: float = float(_climb_elapsed_by_id.get(racer_id, 0.0)) + delta
	_climb_elapsed_by_id[racer_id] = elapsed
	var from_value: Variant = _climb_from_by_id.get(racer_id, racer.global_position)
	var to_value: Variant = _climb_to_by_id.get(racer_id, racer.global_position)
	var from: Vector3 = from_value if from_value is Vector3 else racer.global_position
	var to: Vector3 = to_value if to_value is Vector3 else racer.global_position
	var duration: float = float(_climb_duration_by_id.get(racer_id, LADDER_CLIMB_SECONDS))
	var t: float = clampf(elapsed / maxf(0.01, duration), 0.0, 1.0)
	# Keep the racer locked to the ladder axis. Linear vertical travel reads more
	# clearly on very tall ladders than a strong ease curve.
	var position := from.lerp(to, t)
	position.x = from.x
	position.z = from.z
	racer.global_position = position
	racer.velocity = Vector3.ZERO
	if t >= 1.0:
		_climb_duration_by_id.erase(racer_id)
		_finish_water_recovery(racer)

func _nearest_physical_ladder(racer: WildDashCharacterController) -> Dictionary:
	if racer == null or _ladder_system == null:
		return {}
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, -1))
	var candidates: Array = _ladder_system.call("get_ladders_for_zone", zone)
	if candidates.is_empty():
		candidates = _ladder_system.call("get_all_ladders")
	var best: Dictionary = {}
	var best_distance: float = INF
	for value: Variant in candidates:
		if not (value is Dictionary):
			continue
		var ladder: Dictionary = value
		var bottom_value: Variant = ladder.get("bottom", racer.global_position)
		if not (bottom_value is Vector3):
			continue
		var bottom: Vector3 = bottom_value
		if absf(racer.global_position.y - bottom.y) > NEARBY_LADDER_MAX_VERTICAL_DELTA:
			continue
		var distance: float = Vector2(racer.global_position.x - bottom.x, racer.global_position.z - bottom.z).length()
		if distance < best_distance:
			best_distance = distance
			best = ladder
	return best

func _planar_distance_to_ladder(racer: WildDashCharacterController, ladder: Dictionary) -> float:
	var bottom_value: Variant = ladder.get("bottom", racer.global_position)
	if not (bottom_value is Vector3):
		return INF
	var bottom: Vector3 = bottom_value
	return Vector2(racer.global_position.x - bottom.x, racer.global_position.z - bottom.z).length()
