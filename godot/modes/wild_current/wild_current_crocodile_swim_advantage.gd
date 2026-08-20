class_name WildCurrentCrocodileSwimAdvantage
extends Node

## Round 5-only aquatic specialization for Crocodile.
## The base character remains deliberately slower on land; this layer makes the
## Water Bruiser fantasy materially true in WILD CURRENT without touching R1-R4.

const CROCODILE_MAX_SWIM_SPEED: float = 14.2
const CROCODILE_CRUISE_SWIM_SPEED: float = 10.2
const CROCODILE_MOMENTUM_RESPONSE_SCALE: float = 0.92
const CROCODILE_LATERAL_CURRENT_SCALE: float = 0.90
const CROCODILE_DIVE_RECHARGE_SCALE: float = 0.88

const TAIL_SWEEP_RANGE: float = 4.8
const TAIL_SWEEP_DIVE_RANGE: float = 5.15
const TAIL_SWEEP_KNOCKBACK: float = 8.6
const TAIL_SWEEP_DIVE_POWER_SCALE: float = 1.12
const TAIL_SWEEP_PLAYER_COOLDOWN: float = 1.45
const TAIL_SWEEP_AI_COOLDOWN: float = 2.65
const TAIL_SWEEP_MAX_HITS: int = 3
const TAIL_SWEEP_VERTICAL_TOLERANCE: float = 2.4
const TAIL_SWEEP_SURFACE_RETENTION: float = 0.84
const TAIL_SWEEP_DIVE_RETENTION: float = 0.80
const AI_ATTACK_PROBE_INTERVAL: float = 0.16
const AI_ATTACK_OPENING_GRACE: float = 1.25

var _applied: Dictionary = {}
var _driver_by_racer_id: Dictionary = {}
var _crocodile_drivers: Array[WildCurrentSwimmerPhase2] = []
var _attack_cooldowns: Dictionary = {}
var _elapsed: float = 0.0
var _ai_probe_timer: float = 0.0

func _ready() -> void:
	if not InputManager.race_combat_action_resolved.is_connected(_on_race_combat_action):
		InputManager.race_combat_action_resolved.connect(_on_race_combat_action)
	print("r5_crocodile_swim_advantage_ready round5_only=true max=%.1f cruise=%.1f" % [
		CROCODILE_MAX_SWIM_SPEED,
		CROCODILE_CRUISE_SWIM_SPEED,
	])
	print("r5_crocodile_water_combat_ready tail_range=%.2f tail_knockback=%.2f dive_power=%.2f max_hits=%d player_input=F_Y ai_enabled=true" % [
		TAIL_SWEEP_RANGE,
		TAIL_SWEEP_KNOCKBACK,
		TAIL_SWEEP_DIVE_POWER_SCALE,
		TAIL_SWEEP_MAX_HITS,
	])

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed <= 6.0:
		_apply_to_round5_swimmers()
	_update_attack_cooldowns(delta)
	_ai_probe_timer -= delta
	if _ai_probe_timer <= 0.0:
		_ai_probe_timer = AI_ATTACK_PROBE_INTERVAL
		_update_ai_tail_attacks()

func _apply_to_round5_swimmers() -> void:
	var race_root := get_parent()
	if race_root == null:
		return
	for child in race_root.get_children():
		var driver := child as WildCurrentSwimmerPhase2
		if driver == null or driver.racer == null:
			continue
		var racer := driver.racer as WildDashCharacterController
		if racer == null:
			continue
		_driver_by_racer_id[racer.get_instance_id()] = driver
		if racer.animal_id != &"crocodile":
			continue
		var key := driver.get_instance_id()
		if _applied.has(key):
			continue

		driver.max_swim_speed = maxf(driver.max_swim_speed, CROCODILE_MAX_SWIM_SPEED)
		driver.cruise_swim_speed = maxf(driver.cruise_swim_speed, CROCODILE_CRUISE_SWIM_SPEED)
		driver.set("_momentum_scale", CROCODILE_MOMENTUM_RESPONSE_SCALE)
		driver.set("_lateral_current_scale", CROCODILE_LATERAL_CURRENT_SCALE)
		driver.set("_dive_recharge_scale", CROCODILE_DIVE_RECHARGE_SCALE)
		_applied[key] = true
		_crocodile_drivers.append(driver)
		_attack_cooldowns[racer.get_instance_id()] = 0.0

		print("r5_crocodile_water_advantage racer=%s max=%.1f cruise=%.1f propulsion=%.2f lateral_current=%.2f dive_recharge=%.2f tail_sweep=true" % [
			RaceManager.get_racer_label(racer),
			driver.max_swim_speed,
			driver.cruise_swim_speed,
			1.0 / CROCODILE_MOMENTUM_RESPONSE_SCALE,
			CROCODILE_LATERAL_CURRENT_SCALE,
			CROCODILE_DIVE_RECHARGE_SCALE,
		])

func _on_race_combat_action(action: Dictionary) -> void:
	if not RaceManager.active:
		return
	var kind := StringName(action.get("kind", &""))
	if kind not in [&"tap", &"hold"]:
		return
	for driver in _crocodile_drivers:
		if driver == null or not is_instance_valid(driver) or not driver.player_controlled:
			continue
		_perform_tail_sweep(driver, &"PLAYER")
		return

func _update_attack_cooldowns(delta: float) -> void:
	for racer_id in _attack_cooldowns.keys():
		_attack_cooldowns[racer_id] = maxf(0.0, float(_attack_cooldowns[racer_id]) - delta)

func _update_ai_tail_attacks() -> void:
	if not RaceManager.active or _elapsed < AI_ATTACK_OPENING_GRACE:
		return
	for driver in _crocodile_drivers:
		if driver == null or not is_instance_valid(driver) or driver.player_controlled:
			continue
		var attacker := driver.racer as WildDashCharacterController
		if attacker == null or attacker.finished:
			continue
		if _cooldown_for(attacker) > 0.0:
			continue
		if _has_tail_target(attacker, TAIL_SWEEP_DIVE_RANGE if driver.is_diving() else TAIL_SWEEP_RANGE):
			_perform_tail_sweep(driver, &"AI")

func _has_tail_target(attacker: WildDashCharacterController, range_value: float) -> bool:
	for other_node in RaceManager.racers:
		var other := other_node as WildDashCharacterController
		if not _is_valid_tail_target(attacker, other):
			continue
		var delta := other.global_position - attacker.global_position
		if absf(delta.y) <= TAIL_SWEEP_VERTICAL_TOLERANCE and Vector2(delta.x, delta.z).length() <= range_value:
			return true
	return false

func _perform_tail_sweep(driver: WildCurrentSwimmerPhase2, source: StringName) -> void:
	if driver == null or driver.racer == null or not RaceManager.active:
		return
	var attacker := driver.racer as WildDashCharacterController
	if attacker == null or attacker.finished or _cooldown_for(attacker) > 0.0:
		return

	var diving := driver.is_diving()
	var range_value := TAIL_SWEEP_DIVE_RANGE if diving else TAIL_SWEEP_RANGE
	var power := TAIL_SWEEP_KNOCKBACK * (TAIL_SWEEP_DIVE_POWER_SCALE if diving else 1.0)
	var retention := TAIL_SWEEP_DIVE_RETENTION if diving else TAIL_SWEEP_SURFACE_RETENTION
	var hit_count := 0

	for other_node in RaceManager.racers:
		if hit_count >= TAIL_SWEEP_MAX_HITS:
			break
		var other := other_node as WildDashCharacterController
		if not _is_valid_tail_target(attacker, other):
			continue
		var delta := other.global_position - attacker.global_position
		if absf(delta.y) > TAIL_SWEEP_VERTICAL_TOLERANCE:
			continue
		var planar := Vector3(delta.x, 0.0, delta.z)
		if planar.length() > range_value:
			continue
		if planar.length_squared() <= 0.0001:
			planar = attacker.global_transform.basis.x

		var victim_driver := _driver_by_racer_id.get(other.get_instance_id(), null) as WildCurrentSwimmerPhase2
		if victim_driver == null:
			continue
		if not victim_driver.apply_water_combat_push(planar, power, retention):
			continue

		hit_count += 1
		var victim_visual := other.get_visual()
		if victim_visual != null:
			victim_visual.play_action(&"Hit", 0.24)
		print("r5_crocodile_tail_hit attacker=%s victim=%s power=%.2f diving=%s water_only=true" % [
			RaceManager.get_racer_label(attacker),
			RaceManager.get_racer_label(other),
			power,
			str(diving),
		])

	var cooldown := TAIL_SWEEP_PLAYER_COOLDOWN if source == &"PLAYER" else TAIL_SWEEP_AI_COOLDOWN + float(attacker.get_instance_id() % 5) * 0.11
	_attack_cooldowns[attacker.get_instance_id()] = cooldown
	_play_tail_feedback(attacker, diving)
	_emit_tail_audio(attacker)
	print("r5_crocodile_tail_sweep attacker=%s source=%s diving=%s range=%.2f knockback=%.2f hits=%d cooldown=%.2f teleport=false" % [
		RaceManager.get_racer_label(attacker),
		String(source),
		str(diving),
		range_value,
		power,
		hit_count,
		cooldown,
	])

func _is_valid_tail_target(attacker: WildDashCharacterController, other: WildDashCharacterController) -> bool:
	return other != null and other != attacker and not other.finished and is_instance_valid(other)

func _cooldown_for(attacker: WildDashCharacterController) -> float:
	if attacker == null:
		return INF
	return float(_attack_cooldowns.get(attacker.get_instance_id(), 0.0))

func _play_tail_feedback(attacker: WildDashCharacterController, diving: bool) -> void:
	var visual := attacker.get_visual()
	if visual == null:
		return
	if visual.has_method("play_tail_sweep"):
		visual.call("play_tail_sweep", 1.15 if diving else 1.0)
	else:
		visual.play_action(&"Skill", 0.26)

func _emit_tail_audio(attacker: WildDashCharacterController) -> void:
	var race_root := get_parent()
	if race_root != null and race_root.has_method("emit_swim_audio"):
		race_root.call("emit_swim_audio", attacker, &"splash")