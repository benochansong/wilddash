extends "res://modes/neon_harbor_race/neon_harbor_race_v3_pace_balance.gd"

## Final Round 3 adapter for WILD TIDE — JUNGLE HARBOR.
## Keeps the V3 canonical pace work, then adds terrain-aware pace, species route
## identities, and imperfect telegraph response for Mangrove Titan hazards.

const WILD_TIDE_AI_UPDATE_SECONDS: float = 0.28
const WILD_TIDE_AI_LOG_SECONDS: float = 6.0
const WILD_TIDE_HAZARD_DODGE_SECONDS: float = 1.35

var _wild_tide_elapsed: float = 0.0
var _wild_tide_log_elapsed: float = 0.0
var _world_controller: WildDashWildTideWorldController
var _titan_controller: WildDashMangroveTitanController
var _last_hazard_serial: int = -1
var _hazard_dodge_until_by_id: Dictionary = {}

func _ready() -> void:
	super._ready()
	_world_controller = get_node_or_null("WildTideWorldController") as WildDashWildTideWorldController
	_titan_controller = get_node_or_null("MangroveTitanController") as WildDashMangroveTitanController
	if hud != null:
		hud.configure(
			"ROUND 3 — WILD TIDE: JUNGLE HARBOR",
			"수륙 레이스 · Crocodile=Deep Water · Monkey=Canopy · Titan 경고를 보고 회피 · Q/B Pack Buster"
		)
	print("WILD TIDE MODE V4 READY pace_v3=true water_jungle=true terrain_ai=true titan=true pack_buster=true")

func _process(delta: float) -> void:
	super(delta)
	if not RaceManager.active or player == null:
		return
	_wild_tide_elapsed += delta
	_wild_tide_log_elapsed += delta
	if _wild_tide_elapsed >= WILD_TIDE_AI_UPDATE_SECONDS:
		_wild_tide_elapsed = 0.0
		_update_wild_tide_ai()
	if _wild_tide_log_elapsed >= WILD_TIDE_AI_LOG_SECONDS:
		_wild_tide_log_elapsed = 0.0
		_log_wild_tide_state()

func _update_wild_tide_ai() -> void:
	var player_progress: float = RaceManager.get_track_progress(player)
	var hazard_serial: int = -1
	var hazard_type: StringName = &""
	var hazard_center: Vector3 = Vector3.ZERO
	if _titan_controller != null:
		hazard_serial = _titan_controller.get_hazard_serial()
		hazard_type = _titan_controller.get_active_hazard()
		hazard_center = _titan_controller.get_active_hazard_center()
	if hazard_serial != _last_hazard_serial and hazard_type != &"":
		_last_hazard_serial = hazard_serial
		_assign_hazard_responses(hazard_serial, hazard_type, hazard_center)

	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null or racer.finished:
			continue
		var base_speed: float = _round3_get_canonical_ai_speed(racer)
		var progress_gap: float = RaceManager.get_track_progress(racer) - player_progress
		var gap_scale: float = _round3_gap_scale(progress_gap)
		var terrain_multiplier: float = float(racer.get_meta(&"wild_tide_speed_multiplier", 1.0))
		var route_multiplier: float = _species_route_pace_multiplier(racer)
		var desired: float = base_speed * ROUND3_NORMAL_MODE_SCALE * _round3_difficulty_scale() * gap_scale
		desired *= terrain_multiplier * route_multiplier
		var max_scale: float = 1.50 if racer.animal_id == &"crocodile" else 1.28
		driver.target_speed = clampf(desired, base_speed * 0.84, base_speed * max_scale)

		var racer_id: int = racer.get_instance_id()
		var dodge_until: float = float(_hazard_dodge_until_by_id.get(racer_id, 0.0))
		if dodge_until <= Time.get_ticks_msec() / 1000.0:
			_hazard_dodge_until_by_id.erase(racer_id)
			driver.preferred_lane = _species_preferred_lane(racer)

func _species_route_pace_multiplier(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 1.0
	var progress: float = RaceManager.get_progress_percent(racer) / 100.0
	var in_jungle: bool = progress >= 0.30 and progress <= 0.60
	match racer.animal_id:
		&"crocodile":
			return 1.02
		&"monkey":
			return 1.08 if in_jungle else 1.0
		&"rabbit", &"cat":
			return 1.045 if progress >= 0.63 and progress <= 0.80 else 1.0
		&"fox":
			return 1.035 if not bool(racer.has_meta(&"wild_tide_terrain")) else 0.98
		&"boar":
			return 1.025 if in_jungle else 1.0
		&"elephant":
			return 1.02 if in_jungle else 1.0
		_:
			return 1.0

func _species_preferred_lane(racer: WildDashCharacterController) -> float:
	var progress: float = RaceManager.get_progress_percent(racer) / 100.0
	var in_jungle: bool = progress >= 0.30 and progress <= 0.60
	var in_flooded_delta: bool = progress >= 0.63 and progress <= 0.84
	match racer.animal_id:
		&"crocodile": return 0.0
		&"raccoon": return -1.2
		&"bear": return 1.0
		&"monkey": return -2.8 if in_jungle else -0.8
		&"rabbit": return 3.0 if in_flooded_delta else 1.4
		&"cat": return 3.2 if in_flooded_delta else 2.0
		&"deer": return 2.2
		&"fox": return -2.4
		&"boar": return -1.8 if in_jungle else -0.4
		&"elephant": return 1.8 if in_jungle else 0.6
		&"wolf": return -0.6
		_:
			return 0.0

func _assign_hazard_responses(serial: int, hazard_type: StringName, hazard_center: Vector3) -> void:
	var chance: float = _hazard_avoidance_chance()
	var now: float = Time.get_ticks_msec() / 1000.0
	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null or racer.finished:
			continue
		var deterministic_roll: float = float((racer.get_instance_id() + serial * 37) % 100) / 100.0
		if deterministic_roll > chance:
			continue
		var racer_id: int = racer.get_instance_id()
		_hazard_dodge_until_by_id[racer_id] = now + WILD_TIDE_HAZARD_DODGE_SECONDS
		var delta_to_hazard: Vector3 = racer.global_position - hazard_center
		var side: float = 1.0 if delta_to_hazard.x >= 0.0 else -1.0
		driver.preferred_lane = side * 4.0
		if hazard_type == &"water_wave" or hazard_type == &"tail_sweep":
			if racer.animal_id in [&"rabbit", &"monkey", &"deer", &"cat"]:
				racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 0.92)
		print("AI HAZARD RESPONSE racer=%s animal=%s hazard=%s avoid=true chance=%.2f" % [
			racer.name, String(racer.animal_id), String(hazard_type), chance,
		])

func _hazard_avoidance_chance() -> float:
	var difficulty: StringName = StringName(GameManager.difficulty)
	match difficulty:
		&"easy": return 0.48
		&"hard": return 0.86
		_:
			return 0.70

func _log_wild_tide_state() -> void:
	var water_ratio: float = 0.0
	var route_state: Dictionary = {}
	if _world_controller != null:
		water_ratio = _world_controller.get_baseline_water_ratio()
		route_state = _world_controller.get_route_state()
	var hazard: StringName = &""
	if _titan_controller != null:
		hazard = _titan_controller.get_active_hazard()
	print("ROUTE STATE water=%.1f%% high_tide_1=%s high_tide_2=%s canopy=true jungle_shortcut=%s hazard=%s player_rank=%d/%d" % [
		water_ratio * 100.0,
		str(bool(route_state.get("high_tide_one", false))),
		str(bool(route_state.get("high_tide_two", false))),
		str(bool(route_state.get("jungle_shortcut", false))),
		String(hazard),
		RaceManager.get_rank(player),
		RaceManager.racers.size(),
	])

func get_round3_character_advantage(animal_id: StringName) -> StringName:
	match animal_id:
		&"dog": return &"BALANCED"
		&"wolf": return &"PACK_CHASER"
		&"boar": return &"ROUGH_BREAKTHROUGH"
		&"rabbit": return &"JUMP_ROUTE"
		&"deer": return &"LEAP_ROUTE"
		&"monkey": return &"CANOPY"
		&"elephant": return &"SHALLOW_BREAKABLE"
		&"bear": return &"WATER_HEAVY"
		&"crocodile": return &"DEEP_WATER_KING"
		&"cat": return &"ELEVATED_NARROW"
		&"fox": return &"FAST_LAND"
		&"raccoon": return &"WATER_OPPORTUNIST"
		_:
			return &"BALANCED"
