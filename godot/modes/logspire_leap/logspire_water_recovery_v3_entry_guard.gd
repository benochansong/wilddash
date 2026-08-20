extends "res://modes/logspire_leap/logspire_water_recovery_v2.gd"

## Round 3 water-entry safety guard.
## Area3D overlap alone is never enough to enter swimming. A racer must have
## actually left a platform, be descending, and reach the water surface band.

const WATER_ENTRY_MAX_BODY_ABOVE_SURFACE: float = 1.05
const WATER_HANDOFF_MAX_BODY_ABOVE_SURFACE: float = 1.20
const WATER_ENTRY_MIN_DOWN_SPEED: float = -0.55

func _pool_layout() -> Array[Dictionary]:
	return [
		# Zone 1 water is slightly lower than V2 so the start grid has visible and
		# physical clearance while still remaining a recovery river over the floor.
		{"zone": 0, "center": Vector3(0.0, -0.15, -55.0), "size": Vector2(92.0, 154.0), "water_y": -0.15},
		{"zone": 1, "center": Vector3(0.0, -0.75, -165.0), "size": Vector2(92.0, 130.0), "water_y": -0.75},
		{"zone": 2, "center": Vector3(0.0, 8.75, -290.0), "size": Vector2(88.0, 140.0), "water_y": 8.75},
		{"zone": 3, "center": Vector3(0.0, 15.75, -440.0), "size": Vector2(108.0, 196.0), "water_y": 15.75},
		{"zone": 4, "center": Vector3(0.0, 23.25, -585.0), "size": Vector2(100.0, 136.0), "water_y": 23.25},
		{"zone": 5, "center": Vector3(0.0, 48.25, -720.0), "size": Vector2(100.0, 190.0), "water_y": 48.25},
	]

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured or not RaceManager.active:
		return
	# Area3D signals are useful for effects, but the authoritative transition is
	# also checked from the racer body every physics frame. This prevents a start
	# overlap rejection from swallowing a later real fall in the same water pool.
	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
		if state not in [WaterState.RACING, WaterState.FALLING]:
			continue
		var pool: Dictionary = _pool_for_position(racer.global_position)
		if pool.is_empty():
			continue
		var water_y: float = float(pool.get("water_y", -999.0))
		if not _is_real_water_entry(racer, water_y):
			continue
		_enter_water(racer, int(pool.get("zone", 0)), water_y)

func _on_water_body_entered(body: Node3D, zone: int, water_y: float) -> void:
	var racer := body as WildDashCharacterController
	if not _is_real_water_entry(racer, water_y):
		if racer != null and is_instance_valid(racer) and RaceManager.active:
			print("LOGSPIRE WATER ENTRY REJECT racer=%s zone=%d floor=%s vy=%.2f body_y=%.2f water_y=%.2f" % [
				RaceManager.get_racer_label(racer),
				zone + 1,
				str(racer.is_on_floor()),
				racer.velocity.y,
				racer.global_position.y,
				water_y,
			])
		return
	var racer_id: int = racer.get_instance_id()
	var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
	if state not in [WaterState.RACING, WaterState.FALLING]:
		return
	_enter_water(racer, zone, water_y)

func should_handle_racer(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	if bool(racer.get_meta(WATER_META, false)):
		return true
	var racer_id: int = racer.get_instance_id()
	var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
	if state not in [WaterState.RACING, WaterState.FALLING]:
		return true
	if racer.is_on_floor() or racer.velocity.y > WATER_ENTRY_MIN_DOWN_SPEED:
		return false
	var pool: Dictionary = _pool_for_position(racer.global_position)
	if pool.is_empty():
		return false
	var water_y: float = float(pool.get("water_y", -999.0))
	return racer.global_position.y <= water_y + WATER_HANDOFF_MAX_BODY_ABOVE_SURFACE

func _is_real_water_entry(racer: WildDashCharacterController, water_y: float) -> bool:
	if racer == null or not is_instance_valid(racer) or racer.finished or not RaceManager.active:
		return false
	# This is the critical start-grid guard: racers standing on a platform can
	# overlap the water Area3D with their capsule, but must remain normal racers.
	if racer.is_on_floor():
		return false
	if racer.velocity.y > WATER_ENTRY_MIN_DOWN_SPEED:
		return false
	if racer.global_position.y > water_y + WATER_ENTRY_MAX_BODY_ABOVE_SURFACE:
		return false
	return true
