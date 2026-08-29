class_name WildDashGrandPrixRivalPressure
extends Node

## V3.1 signature-rival pressure.
## Only two racers receive the stronger profile so the whole field does not
## become artificially fast. The rivals use modest capped pace pressure rather
## than teleports: one primary challenger and one secondary challenger.

const UPDATE_INTERVAL := 0.12
const FAR_BEHIND_GAP_METERS := 70.0
const CLOSE_PRESSURE_GAP_METERS := 28.0
const AHEAD_RELAX_GAP_METERS := 34.0

const RIVAL_PROFILES: Dictionary = {
	"AI_01": {
		"label": "ALPHA RIVAL",
		"close_scale": 1.105,
		"far_scale": 1.135,
		"ahead_scale": 1.015,
		"far_ahead_scale": 0.995,
		"accel_scale": 1.16,
		"steering": 7.15,
		"lane_wander": 0.07,
	},
	"AI_02": {
		"label": "CHASE RIVAL",
		"close_scale": 1.070,
		"far_scale": 1.095,
		"ahead_scale": 1.005,
		"far_ahead_scale": 0.990,
		"accel_scale": 1.11,
		"steering": 6.85,
		"lane_wander": 0.09,
	},
}

var _rivals: Array[Dictionary] = []
var _update_elapsed := 0.0
var _telemetry_elapsed := 0.0

func _ready() -> void:
	process_priority = 60
	call_deferred("_bind_signature_rivals")

func _bind_signature_rivals() -> void:
	for _frame in range(8):
		await get_tree().physics_frame

	for node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if not node is WildDashAIController:
			continue
		var driver := node as WildDashAIController
		var racer := driver.get_racer()
		if racer == null or racer.is_player:
			continue
		var racer_name := String(racer.name)
		if not RIVAL_PROFILES.has(racer_name):
			continue

		var profile: Dictionary = RIVAL_PROFILES[racer_name]
		profile = profile.duplicate(true)
		var base_speed := driver.target_speed
		var base_acceleration := driver.acceleration
		driver.acceleration = maxf(driver.acceleration, base_acceleration * float(profile["accel_scale"]))
		driver.steering_strength = maxf(driver.steering_strength, float(profile["steering"]))
		driver.lane_wander = minf(driver.lane_wander, float(profile["lane_wander"]))

		_rivals.append({
			"driver": driver,
			"racer": racer,
			"profile": profile,
			"base_speed": base_speed,
			"base_acceleration": base_acceleration,
		})
		print("GRAND PRIX V3.1 RIVAL READY racer=%s role=%s base=%.2f accel=%.2f steering=%.2f wander=%.2f" % [
			racer_name,
			String(profile["label"]),
			base_speed,
			driver.acceleration,
			driver.steering_strength,
			driver.lane_wander,
		])

	print("GRAND PRIX V3.1 RIVAL FIELD READY rivals=%d target=2 update_hz=%.1f" % [
		_rivals.size(), 1.0 / UPDATE_INTERVAL,
	])
	if _rivals.size() < 2:
		push_warning("Grand Prix V3.1 expected two signature rivals")

func _process(delta: float) -> void:
	if _rivals.is_empty() or not RaceManager.active:
		return
	_update_elapsed += delta
	_telemetry_elapsed += delta
	if _update_elapsed < UPDATE_INTERVAL:
		return
	_update_elapsed = fmod(_update_elapsed, UPDATE_INTERVAL)

	var player := _find_player()
	if player == null or player.finished:
		return
	var player_progress := RaceManager.get_track_progress(player)

	for entry: Dictionary in _rivals:
		var driver := entry["driver"] as WildDashAIController
		var racer := entry["racer"] as WildDashCharacterController
		if driver == null or racer == null or racer.finished:
			continue
		var profile: Dictionary = entry["profile"]
		var base_speed := float(entry["base_speed"])
		var base_acceleration := float(entry["base_acceleration"])
		var rival_progress := RaceManager.get_track_progress(racer)
		var gap := player_progress - rival_progress
		var pace_scale := float(profile["close_scale"])

		if gap > FAR_BEHIND_GAP_METERS:
			pace_scale = float(profile["far_scale"])
		elif gap < -AHEAD_RELAX_GAP_METERS:
			pace_scale = float(profile["far_ahead_scale"])
		elif gap < 0.0:
			pace_scale = float(profile["ahead_scale"])
		elif gap <= CLOSE_PRESSURE_GAP_METERS:
			pace_scale = float(profile["close_scale"])
		else:
			pace_scale = lerpf(float(profile["close_scale"]), float(profile["far_scale"]), clampf((gap - CLOSE_PRESSURE_GAP_METERS) / maxf(1.0, FAR_BEHIND_GAP_METERS - CLOSE_PRESSURE_GAP_METERS), 0.0, 1.0))

		var desired_target := base_speed * pace_scale
		# Pack tactics may briefly lower target_speed for traffic safety. Rival
		# pressure only restores the intended pace floor; it never teleports or
		# directly changes progress.
		driver.target_speed = maxf(driver.target_speed, desired_target)
		driver.acceleration = maxf(driver.acceleration, base_acceleration * float(profile["accel_scale"]))
		driver.steering_strength = maxf(driver.steering_strength, float(profile["steering"]))

	if _telemetry_elapsed >= 3.0:
		_telemetry_elapsed = 0.0
		_report_rival_pressure(player_progress)

func _report_rival_pressure(player_progress: float) -> void:
	var parts: Array[String] = []
	for entry: Dictionary in _rivals:
		var driver := entry["driver"] as WildDashAIController
		var racer := entry["racer"] as WildDashCharacterController
		if driver == null or racer == null:
			continue
		var gap := player_progress - RaceManager.get_track_progress(racer)
		parts.append("%s gap=%+.1fm rank=%d speed=%.1f target=%.1f" % [
			String(racer.name), gap, RaceManager.get_rank(racer), racer.current_speed, driver.target_speed,
		])
	if not parts.is_empty():
		print("GRAND PRIX V3.1 RIVAL PRESSURE " + " | ".join(parts))

func _find_player() -> WildDashCharacterController:
	for candidate in RaceManager.racers:
		if candidate is WildDashCharacterController and (candidate as WildDashCharacterController).is_player:
			return candidate as WildDashCharacterController
	return null
