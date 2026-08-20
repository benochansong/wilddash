class_name WildDashRaceCombatAIDirector
extends Node

## Shared Round 1 / Round 3 combat decision layer.
##
## Driving remains owned by WildDashAIController / route-specific pace systems.
## This director only decides combat, defense and small tactical lane nudges, then
## reuses Race Combat Core V3 + ItemSystem for the actual gameplay result.

const ROUND_GRAND_PRIX: StringName = &"grand_prix"
const ROUND_WILD_TIDE: StringName = &"neon_harbor_race"

const NORMAL_DECISION_INTERVAL: float = 0.26
const EASY_DECISION_INTERVAL: float = 0.34
const HARD_DECISION_INTERVAL: float = 0.20
const NIGHTMARE_DECISION_INTERVAL: float = 0.18
const DECISION_JITTER: float = 0.055
const GLOBAL_OFFENSE_GAP_NORMAL: float = 1.80
const GLOBAL_OFFENSE_GAP_EASY: float = 2.15
const GLOBAL_OFFENSE_GAP_HARD: float = 1.45
const GLOBAL_OFFENSE_GAP_NIGHTMARE: float = 1.30
const BODY_CHECK_MIN_DISTANCE: float = 1.20
const BODY_CHECK_MAX_DISTANCE: float = 2.80
const BODY_CHECK_MAX_VERTICAL: float = 1.85
const TARGET_MAX_DISTANCE: float = 36.0
const TARGET_BEHIND_PROGRESS_ALLOWANCE: float = 3.0
const TARGET_ROUTE_DIVERGENCE_SOFT: float = 22.0
const TARGET_RESERVATION_SECONDS: float = 1.15
const RIVALRY_SECONDS: float = 6.0
const OVERTAKE_RIVALRY_SECONDS: float = 5.0
const ITEM_MIN_HOLD_EASY: float = 0.95
const ITEM_MIN_HOLD_NORMAL: float = 0.74
const ITEM_MIN_HOLD_HARD: float = 0.56
const ITEM_MAX_HOLD_SECONDS: float = 6.5
const DEFENSE_COOLDOWN_SECONDS: float = 1.15
const BOX_SEEK_COOLDOWN_SECONDS: float = 0.75
const COMBAT_TELEMETRY_SECONDS: float = 10.0

@export var round_id: StringName = ROUND_GRAND_PRIX

var _initialized: bool = false
var _racers: Array[WildDashCharacterController] = []
var _drivers_by_id: Dictionary = {}
var _next_decision_by_id: Dictionary = {}
var _decision_serial_by_id: Dictionary = {}
var _body_next_by_id: Dictionary = {}
var _defense_next_by_id: Dictionary = {}
var _box_seek_next_by_id: Dictionary = {}
var _held_item_by_id: Dictionary = {}
var _held_age_by_id: Dictionary = {}
var _last_rank_by_id: Dictionary = {}
var _target_reservations: Dictionary = {}
var _rivalry_until: Dictionary = {}
var _bomb_warning_seen: Dictionary = {}
var _next_global_offense_time: float = 0.0
var _maintenance_elapsed: float = 0.0
var _telemetry_elapsed: float = 0.0
var _combat_events_in_window: int = 0
var _item_events_in_window: int = 0
var _body_events_in_window: int = 0
var _defense_events_in_window: int = 0

func _ready() -> void:
	process_priority = 92
	call_deferred("_bootstrap")

func _exit_tree() -> void:
	if ItemSystem.item_hit.is_connected(_on_item_hit):
		ItemSystem.item_hit.disconnect(_on_item_hit)

func _bootstrap() -> void:
	for _attempt: int in range(120):
		_discover_ai_drivers()
		if not _racers.is_empty():
			break
		await get_tree().physics_frame
	if _racers.is_empty():
		push_warning("RACE COMBAT AI DIRECTOR bootstrap skipped: no race AI drivers")
		return

	_disable_legacy_base_item_brains()
	if not ItemSystem.item_hit.is_connected(_on_item_hit):
		ItemSystem.item_hit.connect(_on_item_hit)

	var now_seconds: float = _now_seconds()
	for racer: WildDashCharacterController in _racers:
		if racer == null:
			continue
		var racer_id: int = racer.get_instance_id()
		_next_decision_by_id[racer_id] = now_seconds + 0.05 + float(racer_id % 11) * 0.017
		_decision_serial_by_id[racer_id] = 0
		_body_next_by_id[racer_id] = 0.0
		_defense_next_by_id[racer_id] = 0.0
		_box_seek_next_by_id[racer_id] = 0.0
		_held_item_by_id[racer_id] = racer.get_held_item()
		_held_age_by_id[racer_id] = 0.0
		_last_rank_by_id[racer_id] = RaceManager.get_rank(racer)
	_initialized = true
	print("RACE COMBAT AI DIRECTOR READY round=%s racers=%d driving_separate=true target_cap=2 rivalry=true item_hold=true core_v3=true" % [
		String(round_id), _racers.size(),
	])

func _process(delta: float) -> void:
	if not _initialized or not RaceManager.active:
		return
	var now_seconds: float = _now_seconds()
	_maintenance_elapsed += delta
	_telemetry_elapsed += delta
	if _maintenance_elapsed >= 0.25:
		_maintenance_elapsed = 0.0
		_cleanup_target_reservations(now_seconds)
		_cleanup_rivalries(now_seconds)
		_cleanup_bomb_warning_cache()

	for racer: WildDashCharacterController in _racers:
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		_update_item_hold_age(racer, delta)
		var racer_id: int = racer.get_instance_id()
		var next_value: Variant = _next_decision_by_id.get(racer_id, 0.0)
		if float(next_value) > now_seconds:
			continue
		var serial: int = int(_decision_serial_by_id.get(racer_id, 0)) + 1
		_decision_serial_by_id[racer_id] = serial
		var interval: float = _decision_interval()
		var jitter: float = (float((racer_id + serial * 7) % 11) / 10.0 - 0.5) * DECISION_JITTER
		_next_decision_by_id[racer_id] = now_seconds + maxf(0.14, interval + jitter)
		_evaluate_racer(racer, now_seconds, serial)

	if _telemetry_elapsed >= COMBAT_TELEMETRY_SECONDS:
		var seconds: float = _telemetry_elapsed
		_telemetry_elapsed = 0.0
		print("AI COMBAT CADENCE round=%s seconds=%.1f events=%d body=%d items=%d defense=%d target_reservations=%d" % [
			String(round_id), seconds, _combat_events_in_window, _body_events_in_window,
			_item_events_in_window, _defense_events_in_window, _target_reservations.size(),
		])
		_combat_events_in_window = 0
		_body_events_in_window = 0
		_item_events_in_window = 0
		_defense_events_in_window = 0

func _discover_ai_drivers() -> void:
	_racers.clear()
	_drivers_by_id.clear()
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if node == null or node.get_parent() != parent_node or not (node is WildDashAIController):
			continue
		var driver: WildDashAIController = node as WildDashAIController
		if driver.preserve_player_identity:
			continue
		var racer: WildDashCharacterController = driver.get_racer()
		if racer == null or racer.is_player or racer.movement_mode != WildDashCharacterController.MovementMode.RACE:
			continue
		_racers.append(racer)
		_drivers_by_id[racer.get_instance_id()] = driver

func _disable_legacy_base_item_brains() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var disabled: int = 0
	for child: Node in parent_node.get_children():
		if child is WildDashAIItemBrain and String(child.name) != "PlayerTestItemBrain":
			child.set_process(false)
			disabled += 1
	print("RACE COMBAT AI ITEM AUTHORITY round=%s legacy_base_item_brains_disabled=%d expanded_item_controller_preserved=true" % [
		String(round_id), disabled,
	])

func _evaluate_racer(racer: WildDashCharacterController, now_seconds: float, serial: int) -> void:
	var driver: WildDashAIController = _driver_for(racer)
	if driver == null:
		return
	_update_overtake_rivalry(racer)

	# Priority 1-3: hazard / route / stuck recovery. The driving systems remain
	# authoritative; combat simply yields when the racer is in a dangerous state.
	if _hazard_priority_active(racer):
		return
	if _try_pack_buster_evade(racer, driver, now_seconds, serial):
		return
	if _try_heavy_evade(racer, driver, now_seconds, serial):
		return
	if _recovery_priority_active(racer, driver):
		_try_recovery_item(racer)
		return

	var target: WildDashCharacterController = _select_combat_target(racer)

	# Defensive actions may happen while global offense is cooling down.
	if _try_defensive_item(racer, driver, now_seconds, serial):
		return

	if now_seconds >= _next_global_offense_time:
		if _try_offensive_item(racer, driver, target, now_seconds, serial):
			if target != null:
				_reserve_target(racer, target, TARGET_RESERVATION_SECONDS)
			_next_global_offense_time = now_seconds + _global_offense_gap()
			return
		if _try_body_check(racer, driver, target, now_seconds, serial):
			_next_global_offense_time = now_seconds + _global_offense_gap()
			return

	# Lowest priority: seek a nearby forward item box without abandoning route.
	_try_item_box_lane_nudge(racer, driver, now_seconds)

func _select_combat_target(attacker: WildDashCharacterController) -> WildDashCharacterController:
	if attacker == null:
		return null
	var attacker_rank: int = RaceManager.get_rank(attacker)
	var attacker_progress: float = RaceManager.get_track_progress(attacker)
	var forward: Vector3 = -attacker.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var held_item: StringName = attacker.get_held_item()
	var max_distance: float = TARGET_MAX_DISTANCE if held_item == ItemSystem.ROCKET_NUT else 12.0
	var best: WildDashCharacterController = null
	var best_score: float = -INF

	for value: Variant in RaceManager.racers:
		var candidate: WildDashCharacterController = value as WildDashCharacterController
		if candidate == null or candidate == attacker or candidate.finished or RaceManager.finish_order.has(candidate):
			continue
		var offset: Vector3 = candidate.global_position - attacker.global_position
		if absf(offset.y) > 4.0:
			continue
		var planar: Vector3 = Vector3(offset.x, 0.0, offset.z)
		var distance: float = planar.length()
		if distance <= 0.05 or distance > max_distance:
			continue
		var candidate_progress: float = RaceManager.get_track_progress(candidate)
		var progress_gap: float = candidate_progress - attacker_progress
		if progress_gap < -TARGET_BEHIND_PROGRESS_ALLOWANCE and distance > 3.4:
			continue
		var alignment: float = forward.dot(planar / distance)
		if alignment < -0.38 and distance > 3.2:
			continue

		var attacker_count: int = _active_attacker_count(candidate)
		var cap: int = _target_attacker_cap(attacker, candidate)
		if attacker_count >= cap:
			continue

		var candidate_rank: int = RaceManager.get_rank(candidate)
		var rank_delta: int = attacker_rank - candidate_rank
		var rank_relevance: float = 0.0
		if rank_delta == 1:
			rank_relevance = 2.20
		elif rank_delta == 2:
			rank_relevance = 1.45
		elif rank_delta > 2:
			rank_relevance = maxf(0.35, 1.15 - float(rank_delta - 2) * 0.18)
		elif abs(rank_delta) <= 1 and distance <= 4.5:
			rank_relevance = 0.65

		var distance_score: float = maxf(0.0, 1.65 - distance / maxf(1.0, max_distance) * 1.45)
		var overtake_score: float = 0.0
		if distance <= 6.0 and progress_gap >= -1.5 and progress_gap <= 8.0:
			if attacker.current_speed >= candidate.current_speed * 0.96:
				overtake_score = 1.10
		var rivalry_score: float = 0.55 if _is_rivalry_active(attacker, candidate) else 0.0
		var item_score: float = _item_target_suitability(attacker, candidate, held_item, distance, progress_gap)
		var gang_penalty: float = float(attacker_count) * 0.82
		var route_penalty: float = 0.0
		if absf(progress_gap) > TARGET_ROUTE_DIVERGENCE_SOFT:
			route_penalty = minf(1.4, (absf(progress_gap) - TARGET_ROUTE_DIVERGENCE_SOFT) * 0.045)
		var target_score: float = rank_relevance + distance_score + overtake_score + rivalry_score + item_score - gang_penalty - route_penalty
		if target_score > best_score:
			best_score = target_score
			best = candidate
	return best

func _item_target_suitability(
	attacker: WildDashCharacterController,
	candidate: WildDashCharacterController,
	item_id: StringName,
	distance: float,
	progress_gap: float
) -> float:
	if item_id == ItemSystem.ROCKET_NUT and distance >= 8.0 and distance <= 35.0 and progress_gap > 0.0:
		return 1.05
	if item_id == ItemSystem.STICKY_FRUIT and distance <= 6.0 and absf(progress_gap) <= 4.0:
		return 0.70
	if item_id == ItemSystem.WIND_BOOST and distance <= 8.5 and progress_gap >= 0.0:
		return 0.65
	if candidate.is_player:
		# Explicitly neutral: player receives no targeting bonus or penalty.
		return 0.0
	return 0.0

func _try_offensive_item(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	target: WildDashCharacterController,
	now_seconds: float,
	serial: int
) -> bool:
	var item_id: StringName = racer.get_held_item()
	if item_id == &"" or not ItemSystem.is_valid_item(item_id):
		return false
	var age: float = _held_age(racer)
	if age < _minimum_item_hold():
		return false
	var rank: int = RaceManager.get_rank(racer)
	var total: int = maxi(1, RaceManager.racers.size())
	var back_ratio: float = float(clampi(rank, 1, total) - 1) / float(maxi(1, total - 1))
	var item_bias: float = _item_bias_for(racer)

	if item_id == ItemSystem.ACORN_BOMB:
		var pack_count: int = _largest_pack_ahead(racer, 15.0, 80.0)
		var chance: float = 0.0
		if pack_count >= 3 and back_ratio >= 0.30:
			chance = 0.88
		elif pack_count >= 2 and back_ratio >= 0.50:
			chance = 0.72
		elif age >= ITEM_MAX_HOLD_SECONDS and pack_count >= 1 and back_ratio >= 0.45:
			chance = 0.48
		if back_ratio < 0.28:
			chance *= 0.28
		if chance > 0.0 and _decision_roll(racer, serial, 41, clampf(chance * item_bias, 0.0, 0.96)):
			var used_bomb: bool = WildDashLongBombItemSupport.use_long_bomb(racer)
			if used_bomb:
				_record_item_event()
				print("AI ITEM animal=%s item=PACK_BUSTER targets=%d rank=%d decision=PACK_BREAK" % [
					String(racer.animal_id), pack_count, rank,
				])
			return used_bomb
		return false

	if item_id == ItemSystem.ROCKET_NUT:
		var rocket_target: WildDashCharacterController = WildDashLongBombItemSupport.find_race_target_ahead_by_rank(racer, 2, 48.0)
		if rocket_target == null:
			return false
		var rocket_distance: float = racer.global_position.distance_to(rocket_target.global_position)
		var good_window: bool = rocket_distance >= 8.0 and rocket_distance <= 35.0
		if age >= ITEM_MAX_HOLD_SECONDS:
			good_window = rocket_distance >= 5.0 and rocket_distance <= 48.0
		if good_window and _decision_roll(racer, serial, 43, clampf(0.76 * item_bias + back_ratio * 0.08, 0.0, 0.94)):
			var used_rocket: bool = ItemSystem.use_held_item(racer)
			if used_rocket:
				_reserve_target(racer, rocket_target, TARGET_RESERVATION_SECONDS)
				_record_item_event()
				print("AI ITEM animal=%s item=ROCKET_NUT target=%s distance=%.1f rank=%d decision=OVERTAKE" % [
					String(racer.animal_id), RaceManager.get_racer_label(rocket_target), rocket_distance, rank,
				])
			return used_rocket
		return false

	if item_id == ItemSystem.STICKY_FRUIT:
		var sticky_target: WildDashCharacterController = _find_sticky_overtake_target(racer)
		if sticky_target != null:
			var sticky_distance: float = racer.global_position.distance_to(sticky_target.global_position)
			var speed_delta: float = absf(racer.current_speed - sticky_target.current_speed)
			if sticky_distance <= 6.0 and speed_delta <= 4.5 and _decision_roll(racer, serial, 47, clampf(0.70 * item_bias, 0.0, 0.90)):
				var used_sticky: bool = ItemSystem.use_held_item(racer)
				if used_sticky:
					_reserve_target(racer, sticky_target, 0.90)
					_record_item_event()
					print("AI ITEM animal=%s item=STICKY_FRUIT target=%s distance=%.1f decision=OVERTAKE_TRAP" % [
						String(racer.animal_id), RaceManager.get_racer_label(sticky_target), sticky_distance,
					])
				return used_sticky
		return false

	if item_id == ItemSystem.WIND_BOOST and target != null:
		var target_distance: float = racer.global_position.distance_to(target.global_position)
		if target_distance <= 8.5 and _decision_roll(racer, serial, 53, clampf(0.62 * item_bias, 0.0, 0.88)):
			var used_wind: bool = ItemSystem.use_held_item(racer)
			if used_wind:
				_reserve_target(racer, target, 0.80)
				_record_item_event()
			return used_wind

	# Non-combat utility items remain useful and never get held forever after the
	# legacy base item brain is disabled. Expanded items keep their existing
	# ItemCombatExpansionController authority.
	return _try_utility_item(racer, driver, age, rank, total, serial)

func _try_defensive_item(
	racer: WildDashCharacterController,
	_driver: WildDashAIController,
	now_seconds: float,
	serial: int
) -> bool:
	var racer_id: int = racer.get_instance_id()
	var next_value: Variant = _defense_next_by_id.get(racer_id, 0.0)
	if float(next_value) > now_seconds:
		return false
	var item_id: StringName = racer.get_held_item()
	if item_id == &"" or not ItemSystem.is_valid_item(item_id) or _held_age(racer) < _minimum_item_hold():
		return false
	var item_bias: float = _item_bias_for(racer)

	if item_id == ItemSystem.BANANA_PEEL:
		var rear: WildDashCharacterController = _find_rear_chaser(racer, 5.0, 15.0)
		if rear != null and _decision_roll(racer, serial, 61, clampf(0.78 * item_bias, 0.0, 0.94)):
			var used_banana: bool = ItemSystem.use_held_item(racer)
			if used_banana:
				_defense_next_by_id[racer_id] = now_seconds + DEFENSE_COOLDOWN_SECONDS
				_record_defense_event()
				print("AI DEFENSE animal=%s action=BANANA_DROP pursuer=%s distance=%.1f" % [
					String(racer.animal_id), RaceManager.get_racer_label(rear), racer.global_position.distance_to(rear.global_position),
				])
			return used_banana

	if item_id == ItemSystem.SHOCKWAVE:
		var crowded: int = WildDashRaceCombatCoreV3.get_nearby_racers(racer, 6.0).size()
		if crowded >= 2 and _decision_roll(racer, serial, 67, 0.88 if crowded >= 3 else 0.72):
			var used_wave: bool = ItemSystem.use_held_item(racer)
			if used_wave:
				_defense_next_by_id[racer_id] = now_seconds + DEFENSE_COOLDOWN_SECONDS
				_next_global_offense_time = maxf(_next_global_offense_time, now_seconds + _global_offense_gap() * 0.70)
				_record_defense_event()
				print("AI DEFENSE animal=%s action=SHOCKWAVE nearby=%d" % [String(racer.animal_id), crowded])
			return used_wave

	if item_id == ItemSystem.BUBBLE_SHIELD:
		var close_racers: int = WildDashRaceCombatCoreV3.get_nearby_racers(racer, 6.5).size()
		var rear_threat: WildDashCharacterController = _find_rear_chaser(racer, 3.5, 11.0)
		if close_racers >= 2 or rear_threat != null:
			if _decision_roll(racer, serial, 71, 0.72):
				var used_shield: bool = ItemSystem.use_held_item(racer)
				if used_shield:
					_defense_next_by_id[racer_id] = now_seconds + DEFENSE_COOLDOWN_SECONDS
					_record_defense_event()
				return used_shield

	if item_id == ItemSystem.GHOST_FRUIT:
		var jammed: int = WildDashRaceCombatCoreV3.get_nearby_racers(racer, 5.5).size()
		if jammed >= 2 and _decision_roll(racer, serial, 73, 0.70):
			var used_ghost: bool = ItemSystem.use_held_item(racer)
			if used_ghost:
				_record_defense_event()
			return used_ghost
	return false

func _try_utility_item(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	age: float,
	rank: int,
	total: int,
	serial: int
) -> bool:
	var item_id: StringName = racer.get_held_item()
	var trailing_half: bool = rank > ceili(float(maxi(1, total)) * 0.5)
	var used: bool = false
	match item_id:
		ItemSystem.DASH_BERRY, ItemSystem.SUPER_CARROT:
			if age >= 1.1 and (trailing_half or age >= ITEM_MAX_HOLD_SECONDS) and _decision_roll(racer, serial, 79, 0.68):
				used = ItemSystem.use_held_item(racer)
		ItemSystem.RECOVERY_FEATHER:
			if racer.current_speed < driver.target_speed * 0.70 or age >= ITEM_MAX_HOLD_SECONDS:
				used = ItemSystem.use_held_item(racer)
		ItemSystem.MAGNET:
			if ItemSystem.is_item_station_ahead(racer, 34.0) or age >= ITEM_MAX_HOLD_SECONDS:
				used = ItemSystem.use_held_item(racer)
		_:
			if age >= ITEM_MAX_HOLD_SECONDS and item_id != ItemSystem.ROCKET_NUT and item_id != ItemSystem.ACORN_BOMB:
				used = ItemSystem.use_held_item(racer)
	if used:
		_record_item_event()
		print("AI ITEM animal=%s item=%s rank=%d decision=UTILITY_HOLD_RELEASE age=%.1f" % [
			String(racer.animal_id), ItemSystem.get_display_name(item_id), rank, age,
		])
	return used

func _try_body_check(
	racer: WildDashCharacterController,
	_driver: WildDashAIController,
	target: WildDashCharacterController,
	now_seconds: float,
	serial: int
) -> bool:
	if target == null or WildDashRaceCombatCoreV3.get_recent_hit_protection(target):
		return false
	var racer_id: int = racer.get_instance_id()
	var next_value: Variant = _body_next_by_id.get(racer_id, 0.0)
	if float(next_value) > now_seconds:
		return false
	var raw_offset: Vector3 = target.global_position - racer.global_position
	if absf(raw_offset.y) > BODY_CHECK_MAX_VERTICAL:
		return false
	var offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
	var distance: float = offset.length()
	if distance < BODY_CHECK_MIN_DISTANCE or distance > BODY_CHECK_MAX_DISTANCE:
		return false
	if not WildDashRaceCombatCoreV3.can_body_check_target(racer, target, BODY_CHECK_MAX_DISTANCE):
		return false
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false
	forward = forward.normalized()
	var alignment: float = forward.dot(offset / distance)
	if alignment < -0.15:
		return false
	if racer.animal_id == &"elephant" and absf(_driver_for(racer).preferred_lane) > 2.75:
		# Avoid deliberate heavy attacks on narrow/extreme route edges.
		return false

	var aggression: float = _combat_aggression(racer)
	var overtake_bonus: float = 0.0
	if distance <= 2.6 and racer.current_speed >= target.current_speed * 0.96:
		overtake_bonus = 0.18
	var chance: float = clampf(aggression * 0.58 + overtake_bonus, 0.10, 0.86)
	if racer.animal_id == &"raccoon":
		chance *= 0.72
	if not _decision_roll(racer, serial, 83, chance):
		return false

	var profile: WildDashRaceImpactProfile = WildDashRaceCombatCoreV3.build_body_check_profile(racer, target)
	var applied: bool = WildDashRaceCombatCoreV3.apply_race_impact(racer, target, &"body_check", profile, racer.global_position)
	if not applied:
		return false
	_body_next_by_id[racer_id] = now_seconds + _body_check_cooldown(racer.animal_id)
	_reserve_target(racer, target, TARGET_RESERVATION_SECONDS)
	_record_body_event()
	print("AI COMBAT DECISION animal=%s action=BODY_CHECK target=%s distance=%.1f rank=%d impact=%s knockback=%.2f" % [
		String(racer.animal_id), RaceManager.get_racer_label(target), distance,
		RaceManager.get_rank(racer), String(profile.impact_label), profile.knockback,
	])
	return true

func _try_pack_buster_evade(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	now_seconds: float,
	serial: int
) -> bool:
	var racer_id: int = racer.get_instance_id()
	var next_value: Variant = _defense_next_by_id.get(racer_id, 0.0)
	if float(next_value) > now_seconds:
		return false
	var parent_node: Node = get_parent()
	if parent_node == null:
		return false
	for child: Node in parent_node.get_children():
		if not (child is WildDashAcornBomb):
			continue
		var bomb: WildDashAcornBomb = child as WildDashAcornBomb
		if bomb.owner_racer == racer:
			continue
		var key: String = "%d:%d" % [racer_id, bomb.get_instance_id()]
		if _bomb_warning_seen.has(key):
			continue
		var planar: Vector3 = bomb.global_position - racer.global_position
		planar.y = 0.0
		var distance: float = planar.length()
		# Ballistic V3 is short-lived. Near-apex/descending projectiles with a close
		# planar footprint are treated as the landing telegraph.
		if distance > 10.0 or bomb.velocity.y > 4.0:
			continue
		_bomb_warning_seen[key] = bomb
		var chance: float = _bomb_evade_chance()
		if not _decision_roll(racer, serial, 89, chance):
			return false
		var right: Vector3 = racer.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() <= 0.001:
			right = Vector3.RIGHT
		else:
			right = right.normalized()
		var side_amount: float = planar.dot(right)
		var evade_sign: float = -1.0 if side_amount >= 0.0 else 1.0
		if absf(side_amount) < 0.20:
			evade_sign = -1.0 if racer_id % 2 == 0 else 1.0
		driver.preferred_lane = clampf(driver.preferred_lane + evade_sign * 1.55, -3.6, 3.6)
		if racer.animal_id in [&"rabbit", &"cat", &"deer", &"monkey"] and racer.is_on_floor():
			racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 0.82)
		_defense_next_by_id[racer_id] = now_seconds + DEFENSE_COOLDOWN_SECONDS
		_record_defense_event()
		print("AI DEFENSE animal=%s action=BOMB_EVADE chance=%.2f distance=%.1f" % [
			String(racer.animal_id), chance, distance,
		])
		return true
	return false

func _try_heavy_evade(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	now_seconds: float,
	serial: int
) -> bool:
	if not racer.animal_id in [&"rabbit", &"cat", &"fox"]:
		return false
	var racer_id: int = racer.get_instance_id()
	if float(_defense_next_by_id.get(racer_id, 0.0)) > now_seconds:
		return false
	var heavy: WildDashCharacterController = _nearest_heavy_threat(racer)
	if heavy == null:
		return false
	var chance: float = 0.56
	if racer.animal_id == &"cat":
		chance = 0.62
	elif racer.animal_id == &"fox":
		chance = 0.59
	if GameManager.difficulty == &"hard" or GameManager.difficulty == &"nightmare":
		chance += 0.08
	if not _decision_roll(racer, serial, 97, minf(0.78, chance)):
		return false
	var right: Vector3 = racer.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var offset: Vector3 = heavy.global_position - racer.global_position
	offset.y = 0.0
	var side: float = offset.dot(right)
	var evade_sign: float = -1.0 if side >= 0.0 else 1.0
	driver.preferred_lane = clampf(driver.preferred_lane + evade_sign * 1.15, -3.6, 3.6)
	if racer.is_on_floor() and _decision_roll(racer, serial, 101, 0.44):
		racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 0.72)
	_defense_next_by_id[racer_id] = now_seconds + DEFENSE_COOLDOWN_SECONDS
	_record_defense_event()
	print("AI DEFENSE animal=%s action=HEAVY_EVADE threat=%s distance=%.1f" % [
		String(racer.animal_id), String(heavy.animal_id), racer.global_position.distance_to(heavy.global_position),
	])
	return true

func _try_recovery_item(racer: WildDashCharacterController) -> bool:
	if racer.get_held_item() != ItemSystem.RECOVERY_FEATHER:
		return false
	if _held_age(racer) < 0.20:
		return false
	var used: bool = ItemSystem.use_held_item(racer)
	if used:
		_record_defense_event()
	return used

func _recovery_priority_active(racer: WildDashCharacterController, driver: WildDashAIController) -> bool:
	if racer == null or driver == null:
		return false
	if racer.has_blocking_collision():
		return true
	return driver.target_speed > 1.0 and racer.current_speed < driver.target_speed * 0.42

func _hazard_priority_active(racer: WildDashCharacterController) -> bool:
	if round_id != ROUND_WILD_TIDE or racer == null:
		return false
	var parent_node: Node = get_parent()
	if parent_node == null:
		return false
	var titan: Node = parent_node.get_node_or_null("MangroveTitanController")
	if titan == null or not titan.has_method("get_active_hazard"):
		return false
	var hazard_value: Variant = titan.call("get_active_hazard")
	var hazard: StringName = StringName(String(hazard_value))
	if hazard == &"":
		return false
	# Existing Wild Tide hazard AI owns lane/jump telegraph responses. Combat
	# yields during the active telegraph so the two systems never fight steering.
	return true

func _try_item_box_lane_nudge(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	now_seconds: float
) -> void:
	if racer.get_held_item() != &"":
		return
	var racer_id: int = racer.get_instance_id()
	if float(_box_seek_next_by_id.get(racer_id, 0.0)) > now_seconds:
		return
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	var right: Vector3 = racer.global_transform.basis.x
	right.y = 0.0
	if forward.length_squared() <= 0.001 or right.length_squared() <= 0.001:
		return
	forward = forward.normalized()
	right = right.normalized()
	var best_box: Node3D = null
	var best_score: float = INF
	var best_side: float = 0.0
	for node: Node in get_tree().get_nodes_in_group("wilddash_item_box"):
		var box: Node3D = node as Node3D
		if box == null:
			continue
		if box.has_method("is_active") and not bool(box.call("is_active")):
			continue
		var offset: Vector3 = box.global_position - racer.global_position
		offset.y = 0.0
		var ahead: float = offset.dot(forward)
		var side: float = offset.dot(right)
		if ahead < 4.0 or ahead > 12.0 or absf(side) > 3.8:
			continue
		var score: float = ahead + absf(side) * 0.45
		if score < best_score:
			best_score = score
			best_box = box
			best_side = side
	if best_box == null:
		return
	driver.preferred_lane = clampf(driver.preferred_lane + clampf(best_side * 0.38, -1.05, 1.05), -3.6, 3.6)
	_box_seek_next_by_id[racer_id] = now_seconds + BOX_SEEK_COOLDOWN_SECONDS

func _largest_pack_ahead(racer: WildDashCharacterController, min_distance: float, max_distance: float) -> int:
	var ahead: Array[WildDashCharacterController] = []
	var own_progress: float = RaceManager.get_track_progress(racer)
	for value: Variant in RaceManager.racers:
		var other: WildDashCharacterController = value as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		if RaceManager.get_track_progress(other) <= own_progress + 0.5:
			continue
		var distance: float = racer.global_position.distance_to(other.global_position)
		if distance >= min_distance and distance <= max_distance:
			ahead.append(other)
	var best: int = 0
	for center: WildDashCharacterController in ahead:
		var cluster: int = 1
		for other: WildDashCharacterController in ahead:
			if other == center:
				continue
			if center.global_position.distance_to(other.global_position) <= 9.0:
				cluster += 1
		best = maxi(best, cluster)
	return best

func _find_rear_chaser(
	racer: WildDashCharacterController,
	min_distance: float,
	max_distance: float
) -> WildDashCharacterController:
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return null
	forward = forward.normalized()
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	for value: Variant in RaceManager.racers:
		var other: WildDashCharacterController = value as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		var offset: Vector3 = other.global_position - racer.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance < min_distance or distance > max_distance:
			continue
		if offset.dot(forward) >= -0.8:
			continue
		if other.current_speed < racer.current_speed * 0.92:
			continue
		if distance < best_distance:
			best_distance = distance
			best = other
	return best

func _find_sticky_overtake_target(racer: WildDashCharacterController) -> WildDashCharacterController:
	var own_progress: float = RaceManager.get_track_progress(racer)
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	for value: Variant in RaceManager.racers:
		var other: WildDashCharacterController = value as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		var gap: float = RaceManager.get_track_progress(other) - own_progress
		if gap < -3.0 or gap > 4.5:
			continue
		var distance: float = racer.global_position.distance_to(other.global_position)
		if distance > 6.0:
			continue
		if distance < best_distance:
			best_distance = distance
			best = other
	return best

func _nearest_heavy_threat(racer: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	for value: Variant in RaceManager.racers:
		var other: WildDashCharacterController = value as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		if not other.animal_id in [&"elephant", &"bear", &"boar"]:
			continue
		var distance: float = racer.global_position.distance_to(other.global_position)
		if distance > 4.2 or distance >= best_distance:
			continue
		if other.current_speed < racer.current_speed * 0.78:
			continue
		best_distance = distance
		best = other
	return best

func _combat_aggression(racer: WildDashCharacterController) -> float:
	var value: float = 0.58
	match racer.animal_id:
		&"wolf": value = 0.90
		&"boar": value = 0.92
		&"bear": value = 0.80
		&"elephant": value = 0.78
		&"crocodile": value = 0.64
		&"raccoon": value = 0.76
		&"monkey": value = 0.58
		&"fox": value = 0.62
		&"dog": value = 0.60
		&"cat": value = 0.46
		&"rabbit": value = 0.32
		&"deer": value = 0.43
		_: value = 0.56
	if round_id == ROUND_WILD_TIDE:
		if racer.animal_id == &"crocodile" and _is_deep_water(racer):
			value = 0.90
		if racer.animal_id == &"monkey" and racer.global_position.y > 2.2:
			value *= 0.40
		if racer.animal_id in [&"rabbit", &"cat"] and racer.global_position.y > 2.0:
			value *= 0.72
		if racer.animal_id in [&"elephant", &"boar"]:
			var progress: float = RaceManager.get_progress_percent(racer) / 100.0
			if progress >= 0.30 and progress <= 0.62:
				value *= 1.12
	return clampf(value, 0.20, 0.96)

func _item_bias_for(racer: WildDashCharacterController) -> float:
	var bias: float = 1.0
	match racer.animal_id:
		&"raccoon": bias = 1.25
		&"fox": bias = 1.12
		&"cat": bias = 1.10
		&"dog": bias = 1.02
		&"wolf": bias = 1.02
		&"rabbit": bias = 0.94
		&"elephant", &"bear", &"boar": bias = 0.92
		_: bias = 1.0
	if round_id == ROUND_WILD_TIDE and racer.animal_id == &"raccoon" and racer.has_meta(&"wild_tide_terrain"):
		bias *= 1.08
	if round_id == ROUND_WILD_TIDE and racer.animal_id == &"monkey" and racer.global_position.y > 2.2:
		bias *= 0.72
	return bias

func _is_deep_water(racer: WildDashCharacterController) -> bool:
	if racer == null or not racer.has_meta(&"wild_tide_terrain"):
		return false
	var terrain_value: Variant = racer.get_meta(&"wild_tide_terrain", &"")
	return String(terrain_value).to_lower().contains("deep")

func _body_check_cooldown(animal_id: StringName) -> float:
	match animal_id:
		&"wolf", &"boar": return 1.35
		&"bear", &"elephant": return 1.55
		&"crocodile": return 1.60
		&"dog", &"monkey": return 1.78
		&"raccoon", &"fox": return 1.90
		&"cat", &"deer": return 2.05
		&"rabbit": return 2.20
		_: return 1.85

func _target_attacker_cap(attacker: WildDashCharacterController, target: WildDashCharacterController) -> int:
	if _is_rivalry_active(attacker, target):
		return 3
	if RaceManager.get_rank(target) <= 3 and RaceManager.get_rank(attacker) > 3:
		return 3
	return 2

func _reserve_target(attacker: WildDashCharacterController, target: WildDashCharacterController, duration: float) -> void:
	if attacker == null or target == null:
		return
	var target_id: int = target.get_instance_id()
	var attackers: Dictionary = {}
	var value: Variant = _target_reservations.get(target_id, {})
	if value is Dictionary:
		attackers = value
	attackers[attacker.get_instance_id()] = _now_seconds() + maxf(0.2, duration)
	_target_reservations[target_id] = attackers
	var count: int = _active_attacker_count(target)
	var cap: int = _target_attacker_cap(attacker, target)
	if count >= cap:
		print("AI COMBAT TARGET victim=%s attackers=%d capped=true" % [RaceManager.get_racer_label(target), count])

func _active_attacker_count(target: WildDashCharacterController) -> int:
	if target == null:
		return 0
	var value: Variant = _target_reservations.get(target.get_instance_id(), {})
	if not (value is Dictionary):
		return 0
	var attackers: Dictionary = value
	var now_seconds: float = _now_seconds()
	var count: int = 0
	for expiry_value: Variant in attackers.values():
		if float(expiry_value) > now_seconds:
			count += 1
	return count

func _cleanup_target_reservations(now_seconds: float) -> void:
	for target_key: Variant in _target_reservations.keys():
		var value: Variant = _target_reservations.get(target_key, {})
		if not (value is Dictionary):
			_target_reservations.erase(target_key)
			continue
		var attackers: Dictionary = value
		for attacker_key: Variant in attackers.keys():
			if float(attackers.get(attacker_key, 0.0)) <= now_seconds:
				attackers.erase(attacker_key)
		if attackers.is_empty():
			_target_reservations.erase(target_key)
		else:
			_target_reservations[target_key] = attackers

func _on_item_hit(target: Node, source: Node, effect_id: StringName, blocked: bool) -> void:
	if blocked:
		return
	var victim: WildDashCharacterController = target as WildDashCharacterController
	var attacker: WildDashCharacterController = source as WildDashCharacterController
	if victim == null or attacker == null or victim == attacker:
		return
	if not RaceManager.racers.has(victim) or not RaceManager.racers.has(attacker):
		return
	_start_rivalry(attacker, victim, RIVALRY_SECONDS, effect_id)

func _update_overtake_rivalry(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	var current_rank: int = RaceManager.get_rank(racer)
	var previous_rank: int = int(_last_rank_by_id.get(racer_id, current_rank))
	_last_rank_by_id[racer_id] = current_rank
	if previous_rank <= 0 or current_rank <= 0 or current_rank >= previous_rank:
		return
	for value: Variant in RaceManager.racers:
		var other: WildDashCharacterController = value as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		if RaceManager.get_rank(other) != previous_rank:
			continue
		if racer.global_position.distance_to(other.global_position) <= 8.0:
			_start_rivalry(racer, other, OVERTAKE_RIVALRY_SECONDS, &"overtake")
			return

func _start_rivalry(
	a: WildDashCharacterController,
	b: WildDashCharacterController,
	duration: float,
	source_id: StringName
) -> void:
	var key: String = _rivalry_key(a, b)
	var now_seconds: float = _now_seconds()
	var old_until: float = float(_rivalry_until.get(key, 0.0))
	_rivalry_until[key] = maxf(old_until, now_seconds + duration)
	if old_until <= now_seconds:
		print("RIVALRY a=%s b=%s duration=%.1f source=%s" % [
			RaceManager.get_racer_label(a), RaceManager.get_racer_label(b), duration, String(source_id),
		])

func _is_rivalry_active(a: WildDashCharacterController, b: WildDashCharacterController) -> bool:
	if a == null or b == null:
		return false
	return float(_rivalry_until.get(_rivalry_key(a, b), 0.0)) > _now_seconds()

func _rivalry_key(a: WildDashCharacterController, b: WildDashCharacterController) -> String:
	var a_id: int = a.get_instance_id()
	var b_id: int = b.get_instance_id()
	return "%d:%d" % [mini(a_id, b_id), maxi(a_id, b_id)]

func _cleanup_rivalries(now_seconds: float) -> void:
	for key: Variant in _rivalry_until.keys():
		if float(_rivalry_until.get(key, 0.0)) <= now_seconds:
			_rivalry_until.erase(key)

func _cleanup_bomb_warning_cache() -> void:
	for key: Variant in _bomb_warning_seen.keys():
		var value: Variant = _bomb_warning_seen.get(key)
		if not (value is Node) or not is_instance_valid(value as Node):
			_bomb_warning_seen.erase(key)

func _update_item_hold_age(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var item_id: StringName = racer.get_held_item()
	var previous_value: Variant = _held_item_by_id.get(racer_id, &"")
	var previous: StringName = StringName(String(previous_value))
	if item_id != previous:
		_held_item_by_id[racer_id] = item_id
		_held_age_by_id[racer_id] = 0.0
		return
	_held_age_by_id[racer_id] = float(_held_age_by_id.get(racer_id, 0.0)) + delta

func _held_age(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 0.0
	return float(_held_age_by_id.get(racer.get_instance_id(), 0.0))

func _driver_for(racer: WildDashCharacterController) -> WildDashAIController:
	if racer == null:
		return null
	var value: Variant = _drivers_by_id.get(racer.get_instance_id())
	return value as WildDashAIController

func _decision_interval() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return EASY_DECISION_INTERVAL
		&"hard": return HARD_DECISION_INTERVAL
		&"nightmare": return NIGHTMARE_DECISION_INTERVAL
		_: return NORMAL_DECISION_INTERVAL

func _global_offense_gap() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return GLOBAL_OFFENSE_GAP_EASY
		&"hard": return GLOBAL_OFFENSE_GAP_HARD
		&"nightmare": return GLOBAL_OFFENSE_GAP_NIGHTMARE
		_: return GLOBAL_OFFENSE_GAP_NORMAL

func _minimum_item_hold() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return ITEM_MIN_HOLD_EASY
		&"hard", &"nightmare": return ITEM_MIN_HOLD_HARD
		_: return ITEM_MIN_HOLD_NORMAL

func _bomb_evade_chance() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return 0.45
		&"hard": return 0.84
		&"nightmare": return 0.88
		_: return 0.66

func _decision_roll(
	racer: WildDashCharacterController,
	serial: int,
	salt: int,
	chance: float
) -> bool:
	if racer == null or chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	var racer_seed: int = racer.get_instance_id() % 997
	var value: int = (racer_seed * 37 + serial * 61 + salt * 17) % 1000
	return float(value) / 1000.0 < chance

func _record_item_event() -> void:
	_combat_events_in_window += 1
	_item_events_in_window += 1

func _record_body_event() -> void:
	_combat_events_in_window += 1
	_body_events_in_window += 1

func _record_defense_event() -> void:
	_combat_events_in_window += 1
	_defense_events_in_window += 1

func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001
