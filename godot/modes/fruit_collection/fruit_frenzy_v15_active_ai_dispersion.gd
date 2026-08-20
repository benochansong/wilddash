extends "res://modes/fruit_collection/fruit_frenzy_v14_monkey_climb_stages.gd"

## Round 2 V15 — active collection watchdog + stronger spatial dispersion.
##
## V12 made collection the primary intent, but two problems can still leave the
## field looking passive: an AI can hold a statistically reachable vertical fruit
## while its arena driver has already reached the same X/Z and therefore stops,
## and the soft sector cap still allows several racers to converge on one area.
## V15 keeps the V12/V14 architecture, then adds a movement watchdog, per-racer
## temporary fruit avoidance after a stall, stronger physical crowd penalties,
## deterministic sector preferences, and much more local combat engagement.

const V15_ACTIVITY_SAMPLE_SECONDS: float = 0.45
const V15_IDLE_REPLAN_SECONDS: float = 1.35
const V15_MIN_SAMPLE_MOVEMENT: float = 0.28
const V15_STALLED_FRUIT_AVOID_MSEC: int = 3200
const V15_PHYSICAL_CROWD_RADIUS: float = 5.2
const V15_PHYSICAL_CROWD_PENALTY: float = 165.0
const V15_SECTOR_OCCUPANCY_PENALTY: float = 215.0
const V15_PREFERRED_SECTOR_BONUS: float = 92.0
const V15_SEPARATION_RADIUS: float = 4.2
const V15_SEPARATION_STRENGTH: float = 2.35
const V15_NORMAL_COMBAT_RANGE: float = 2.8
const V15_HUNTER_COMBAT_RANGE: float = 5.2
const V15_ACTIVITY_LOG_MSEC: int = 1800

const V15_SECTOR_ORDER: Array[StringName] = [
	&"ORCHARD_GROUND",
	&"ORCHARD_CANOPY",
	&"RIVER",
	&"MARKET",
	&"HILL",
	&"CENTER_PERIMETER",
]

const V15_SCATTER_POINTS: Array[Vector3] = [
	Vector3(-19.0, 0.0, -4.0),
	Vector3(-8.0, 0.0, -15.0),
	Vector3(16.0, 0.0, -12.0),
	Vector3(17.0, 0.0, 12.0),
	Vector3(-17.0, 0.0, 14.0),
	Vector3(0.0, 0.0, 3.0),
]

var _v15_activity_elapsed: float = 0.0
var _v15_last_x_by_id: Dictionary = {}
var _v15_last_z_by_id: Dictionary = {}
var _v15_idle_seconds_by_id: Dictionary = {}
var _v15_avoid_fruit_until: Dictionary = {}
var _v15_watchdog_replans: int = 0
var _v15_last_activity_log_msec: int = 0

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		_v15_last_x_by_id[id] = racer.global_position.x
		_v15_last_z_by_id[id] = racer.global_position.z
		_v15_idle_seconds_by_id[id] = 0.0
	print("FRUIT FRENZY V15 ACTIVE AI READY idle_replan=%.2fs crowd_radius=%.1fm separation=%.1fm combat_normal=%.1fm combat_hunter=%.1fm sector_preference=6" % [
		V15_IDLE_REPLAN_SECONDS,
		V15_PHYSICAL_CROWD_RADIUS,
		V15_SEPARATION_RADIUS,
		V15_NORMAL_COMBAT_RANGE,
		V15_HUNTER_COMBAT_RANGE,
	])

func _physics_process(delta: float) -> void:
	super(delta)
	if mode_finished or not GameManager.round_active:
		return
	_v15_activity_elapsed += delta
	if _v15_activity_elapsed < V15_ACTIVITY_SAMPLE_SECONDS:
		return
	var sample_seconds: float = _v15_activity_elapsed
	_v15_activity_elapsed = 0.0
	_v15_update_activity_watchdog(sample_seconds)

func _v12_best_collect_target(
	racer: WildDashCharacterController,
	ai_index: int,
	claims: Dictionary,
	sector_counts: Dictionary
) -> int:
	if racer == null:
		return -1
	var now_msec: int = Time.get_ticks_msec()
	var racer_id: int = racer.get_instance_id()
	var preferred_sector: StringName = V15_SECTOR_ORDER[ai_index % V15_SECTOR_ORDER.size()]
	var best_index: int = -1
	var best_score: float = INF

	for fruit_index: int in range(fruits.size()):
		if claims.has(fruit_index) or not _v12_fruit_target_valid(racer, fruit_index):
			continue
		if _v15_is_fruit_temporarily_avoided(racer_id, fruit_index, now_msec):
			continue

		var fruit: MeshInstance3D = fruits[fruit_index]
		var access_type: int = WildDashFruitAccessSystem.get_access_type(fruit)
		var sector: StringName = _v12_sector_for_fruit(fruit_index)
		var score: float = racer.global_position.distance_squared_to(fruit.global_position)

		var occupancy: int = int(sector_counts.get(sector, 0))
		if occupancy > 0:
			score += float(occupancy) * V15_SECTOR_OCCUPANCY_PENALTY
		if sector == preferred_sector:
			score -= V15_PREFERRED_SECTOR_BONUS

		var nearby_ai: int = _v15_count_ai_near_position(fruit.global_position, racer)
		if nearby_ai > 0:
			score += float(nearby_ai) * V15_PHYSICAL_CROWD_PENALTY

		score += _v12_species_access_bias(racer.animal_id, access_type)
		score += float((fruit_index * 7 + ai_index * 11) % 17) * 0.31
		if score < best_score:
			best_score = score
			best_index = fruit_index

	# If every candidate is temporarily avoided after a stall, return no fruit.
	# The V12 planner will use its fallback zone target, which keeps this racer
	# moving instead of immediately re-selecting the same bad vertical target.
	return best_index

func _v12_local_combat_target(
	source: WildDashCharacterController,
	max_range: float,
	claims: Dictionary
) -> WildDashCharacterController:
	if source == null:
		return null
	var hunter: bool = source.animal_id in [&"wolf", &"raccoon"]
	var effective_range: float = minf(max_range, V15_HUNTER_COMBAT_RANGE if hunter else V15_NORMAL_COMBAT_RANGE)
	var minimum_carry: int = 2 if hunter else 3
	var max_range_sq: float = effective_range * effective_range
	var best: WildDashCharacterController = null
	var best_score: float = -INF

	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var carry: int = _get_carry(target)
		if carry < minimum_carry:
			continue
		var target_id: int = target.get_instance_id()
		var allowed_chasers: int = 2 if carry >= 5 else 1
		if int(claims.get(target_id, 0)) >= allowed_chasers:
			continue
		var distance_sq: float = source.global_position.distance_squared_to(target.global_position)
		if distance_sq > max_range_sq:
			continue
		var score: float = float(carry) * 8.0 - sqrt(distance_sq) * 2.4
		if hunter:
			score += 4.0
		if score > best_score:
			best_score = score
			best = target
	return best

func _v12_apply_local_separation(racer: WildDashCharacterController, target: Vector3) -> Vector3:
	if racer == null:
		return target
	var planar_to_target: float = Vector2(
		target.x - racer.global_position.x,
		target.z - racer.global_position.z
	).length()
	# Do not steer an AI away from the fruit once it is already in pickup range.
	if planar_to_target <= 2.0:
		return target

	var separation: Vector3 = Vector3.ZERO
	for other: WildDashCharacterController in ai_racers:
		if other == null or other == racer or other.finished:
			continue
		var delta: Vector3 = racer.global_position - other.global_position
		delta.y = 0.0
		var distance: float = delta.length()
		if distance <= 0.01 or distance >= V15_SEPARATION_RADIUS:
			continue
		separation += delta.normalized() * (1.0 - distance / V15_SEPARATION_RADIUS)
	if separation.length_squared() <= 0.001:
		return target
	return target + separation.normalized() * V15_SEPARATION_STRENGTH

func _v15_update_activity_watchdog(sample_seconds: float) -> void:
	var moving_count: int = 0
	var idle_count: int = 0
	var now_msec: int = Time.get_ticks_msec()

	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null or racer.finished:
			continue
		var id: int = racer.get_instance_id()
		var canopy: WildDashCanopyTraversalSystem = _phase3_ai_canopy_by_id.get(id, null) as WildDashCanopyTraversalSystem
		if canopy != null and canopy.is_swinging():
			_v15_store_activity_position(id, racer)
			_v15_idle_seconds_by_id[id] = 0.0
			moving_count += 1
			continue
		if _is_stunned(racer):
			_v15_store_activity_position(id, racer)
			_v15_idle_seconds_by_id[id] = 0.0
			continue

		var previous_x: float = float(_v15_last_x_by_id.get(id, racer.global_position.x))
		var previous_z: float = float(_v15_last_z_by_id.get(id, racer.global_position.z))
		var dx: float = racer.global_position.x - previous_x
		var dz: float = racer.global_position.z - previous_z
		var moved: float = sqrt(dx * dx + dz * dz)
		_v15_store_activity_position(id, racer)

		var intent: StringName = StringName(_v12_intent_by_id.get(id, V12_INTENT_COLLECT))
		var idle_seconds: float = float(_v15_idle_seconds_by_id.get(id, 0.0))
		if moved < V15_MIN_SAMPLE_MOVEMENT and racer.current_speed < 0.85:
			idle_seconds += sample_seconds
		else:
			idle_seconds = maxf(0.0, idle_seconds - sample_seconds * 1.8)
		_v15_idle_seconds_by_id[id] = idle_seconds

		if idle_seconds >= V15_IDLE_REPLAN_SECONDS:
			idle_count += 1
			_v15_recover_idle_ai(racer, driver, i, intent, now_msec)
			_v15_idle_seconds_by_id[id] = 0.0
		else:
			moving_count += 1

	if now_msec - _v15_last_activity_log_msec >= V15_ACTIVITY_LOG_MSEC:
		_v15_last_activity_log_msec = now_msec
		print("ROUND2 ACTIVE AI moving=%d idle_replanned=%d watchdog_total=%d ai=%d spread_targeting=true" % [
			moving_count,
			idle_count,
			_v15_watchdog_replans,
			ai_racers.size(),
		])

func _v15_recover_idle_ai(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	ai_index: int,
	intent: StringName,
	now_msec: int
) -> void:
	var id: int = racer.get_instance_id()
	var old_fruit: int = int(_v12_target_fruit_by_id.get(id, -1))
	if old_fruit >= 0:
		_v15_avoid_fruit_until[_v15_avoid_key(id, old_fruit)] = now_msec + V15_STALLED_FRUIT_AVOID_MSEC
	_v12_target_fruit_by_id[id] = -1
	_v12_target_lock_until_by_id[id] = 0
	_v12_set_intent(id, V12_INTENT_COLLECT)
	if _v14_monkey_stage_by_id.has(id):
		_v14_monkey_stage_by_id[id] = 0

	var scatter_index: int = (ai_index + _v15_watchdog_replans + 2) % V15_SCATTER_POINTS.size()
	var scatter: Vector3 = V15_SCATTER_POINTS[scatter_index]
	var phase: float = float((id + _v15_watchdog_replans * 17) % 9) * 0.47
	scatter.x += cos(phase) * 2.4
	scatter.z += sin(phase) * 2.4
	driver.set_arena_target(scatter)

	# Give a blocked racer a small horizontal wake-up nudge. This is deliberately
	# below combat knockback strength; it only prevents zero-velocity dead poses.
	var direction: Vector3 = scatter - racer.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		var wake_speed: float = maxf(2.8, racer.arena_move_speed * 0.34)
		racer.velocity.x = direction.x * wake_speed
		racer.velocity.z = direction.z * wake_speed
		racer.current_speed = Vector2(racer.velocity.x, racer.velocity.z).length()

	_v15_watchdog_replans += 1
	print("ROUND2 AI WAKEUP racer=%s animal=%s old_intent=%s old_fruit=%d scatter=%s avoid_ms=%d" % [
		racer.name,
		String(racer.animal_id),
		String(intent),
		old_fruit,
		str(scatter),
		V15_STALLED_FRUIT_AVOID_MSEC,
	])

func _v15_store_activity_position(id: int, racer: WildDashCharacterController) -> void:
	_v15_last_x_by_id[id] = racer.global_position.x
	_v15_last_z_by_id[id] = racer.global_position.z

func _v15_is_fruit_temporarily_avoided(racer_id: int, fruit_index: int, now_msec: int) -> bool:
	var key: String = _v15_avoid_key(racer_id, fruit_index)
	var until_msec: int = int(_v15_avoid_fruit_until.get(key, 0))
	if until_msec <= now_msec:
		if _v15_avoid_fruit_until.has(key):
			_v15_avoid_fruit_until.erase(key)
		return false
	return true

func _v15_avoid_key(racer_id: int, fruit_index: int) -> String:
	return "%d:%d" % [racer_id, fruit_index]

func _v15_count_ai_near_position(position: Vector3, exclude: WildDashCharacterController) -> int:
	var count: int = 0
	var radius_sq: float = V15_PHYSICAL_CROWD_RADIUS * V15_PHYSICAL_CROWD_RADIUS
	for other: WildDashCharacterController in ai_racers:
		if other == null or other == exclude or other.finished:
			continue
		var dx: float = other.global_position.x - position.x
		var dz: float = other.global_position.z - position.z
		if dx * dx + dz * dz <= radius_sq:
			count += 1
	return count
