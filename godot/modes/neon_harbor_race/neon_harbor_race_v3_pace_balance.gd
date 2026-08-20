extends "res://modes/neon_harbor_race/neon_harbor_race_v2_mode.gd"

## Round 3 Pace Balance V3.
##
## The original Neon Harbor mode assigned nearly every AI a fixed 14.4-14.9
## target speed even though the active roster contains twelve animals with very
## different canonical ai_race_speed values. This adapter restores the animal
## definition as the source of truth, then applies only small mode/difficulty and
## race-gap modifiers. No teleport catch-up or hard braking is used.

const ROUND3_NORMAL_MODE_SCALE: float = 1.04
const ROUND3_PACE_UPDATE_SECONDS: float = 0.35
const ROUND3_TARGET_SLEW_PER_SECOND: float = 2.20
const ROUND3_AHEAD_SOFT_GAP: float = 20.0
const ROUND3_AHEAD_MEDIUM_GAP: float = 40.0
const ROUND3_AHEAD_LARGE_GAP: float = 65.0
const ROUND3_AHEAD_EXTREME_GAP: float = 90.0
const ROUND3_BEHIND_ASSIST_GAP: float = 35.0
const ROUND3_DEBUG_LOG_SECONDS: float = 5.0

var _round3_pace_initialized: bool = false
var _round3_pace_elapsed: float = 0.0
var _round3_debug_elapsed: float = 0.0
var _round3_base_speed_by_id: Dictionary = {}

func _process(delta: float) -> void:
	super(delta)
	if not _round3_pace_initialized and not ai_racers.is_empty() and ai_drivers.size() >= ai_racers.size():
		_round3_initialize_ai_pace()
	if not _round3_pace_initialized or not RaceManager.active or player == null:
		return

	_round3_pace_elapsed += delta
	_round3_debug_elapsed += delta
	if _round3_pace_elapsed >= ROUND3_PACE_UPDATE_SECONDS:
		var elapsed: float = _round3_pace_elapsed
		_round3_pace_elapsed = 0.0
		_round3_update_ai_pace(elapsed)
	if _round3_debug_elapsed >= ROUND3_DEBUG_LOG_SECONDS:
		_round3_debug_elapsed = 0.0
		_round3_log_pack_state()

func _round3_initialize_ai_pace() -> void:
	_round3_base_speed_by_id.clear()
	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null:
			continue
		var base_speed: float = _round3_get_canonical_ai_speed(racer)
		_round3_base_speed_by_id[racer.get_instance_id()] = base_speed
		var desired: float = _round3_desired_speed(racer, base_speed)
		# Apply the canonical pace immediately so the old 14.x fixed target cannot
		# create a runaway pack during the opening seconds.
		driver.target_speed = desired
		print("ROUND3 AI PACE animal=%s base=%.2f mode_scale=%.3f difficulty_scale=%.3f gap_scale=1.000 final=%.2f" % [
			String(racer.animal_id),
			base_speed,
			ROUND3_NORMAL_MODE_SCALE,
			_round3_difficulty_scale(),
			desired,
		])
	_round3_pace_initialized = true
	print("ROUND3 AI PACE V3 READY racers=%d canonical_speed=true fixed_14x_removed=true natural_gap_control=true" % ai_racers.size())

func _round3_update_ai_pace(elapsed: float) -> void:
	var player_progress: float = RaceManager.get_track_progress(player)
	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null or racer.finished:
			continue
		var id: int = racer.get_instance_id()
		var base_speed: float = float(_round3_base_speed_by_id.get(id, _round3_get_canonical_ai_speed(racer)))
		var ai_progress: float = RaceManager.get_track_progress(racer)
		var progress_gap: float = ai_progress - player_progress
		var gap_scale: float = _round3_gap_scale(progress_gap)
		var desired: float = base_speed * ROUND3_NORMAL_MODE_SCALE * _round3_difficulty_scale() * gap_scale
		desired = clampf(desired, base_speed * 0.88, base_speed * 1.12)
		driver.target_speed = move_toward(
			driver.target_speed,
			desired,
			ROUND3_TARGET_SLEW_PER_SECOND * elapsed
		)

func _round3_desired_speed(racer: WildDashCharacterController, base_speed: float) -> float:
	if racer == null:
		return base_speed
	var desired: float = base_speed * ROUND3_NORMAL_MODE_SCALE * _round3_difficulty_scale()
	return clampf(desired, base_speed * 0.88, base_speed * 1.12)

func _round3_get_canonical_ai_speed(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 10.0
	var definition: WildDashAnimalDefinition = WildDashAnimalCatalog.get_definition(racer.animal_id)
	if definition != null and definition.ai_race_speed > 0.01:
		return definition.ai_race_speed
	return maxf(7.5, racer.cruise_speed * 1.10)

func _round3_difficulty_scale() -> float:
	var difficulty: StringName = StringName(GameManager.difficulty)
	match difficulty:
		&"easy":
			return 0.94
		&"hard":
			return 1.06
		_:
			return 1.0

func _round3_gap_scale(progress_gap: float) -> float:
	# A racer already far ahead of the player never receives additional leading
	# acceleration. The reduction is gradual, preserving a believable moving pack.
	if progress_gap >= ROUND3_AHEAD_EXTREME_GAP:
		return 0.90
	if progress_gap >= ROUND3_AHEAD_LARGE_GAP:
		return 0.93
	if progress_gap >= ROUND3_AHEAD_MEDIUM_GAP:
		return 0.96
	if progress_gap >= ROUND3_AHEAD_SOFT_GAP:
		return 0.985
	if progress_gap <= -ROUND3_BEHIND_ASSIST_GAP:
		return 1.015
	return 1.0

func _round3_log_pack_state() -> void:
	if player == null:
		return
	var player_progress: float = RaceManager.get_track_progress(player)
	var furthest_ahead: float = 0.0
	var nearest_ahead: float = INF
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished:
			continue
		var gap: float = RaceManager.get_track_progress(racer) - player_progress
		if gap > 0.0:
			furthest_ahead = maxf(furthest_ahead, gap)
			nearest_ahead = minf(nearest_ahead, gap)
	if nearest_ahead == INF:
		nearest_ahead = 0.0
	print("ROUND3 PACK GAP player_rank=%d nearest_ahead=%.1fm leader_gap=%.1fm canonical_pace=true" % [
		RaceManager.get_rank(player), nearest_ahead, furthest_ahead,
	])
