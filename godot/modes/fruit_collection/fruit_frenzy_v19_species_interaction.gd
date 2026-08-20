extends "res://modes/fruit_collection/fruit_frenzy_v18_wild_moments.gd"

## Round 2 V19 — species combat and fruit interaction pass.
##
## This is a Fruit Collection-only adapter over the existing Combat V2 stack.
## Shared ability profiles, Fruit Frenzy carry/spill authority, Golden Fruit,
## banking, V17 fart dizzy, V18 Wild Moments and collection-first AI remain
## authoritative. The pass sharpens species identity without adding HP/death or
## a second combat system.

const R2_SPECIES_IDS: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"crocodile", &"cat", &"fox", &"raccoon",
]

const R2_DEER_MIN_RUN_RATIO: float = 0.42
const R2_DEER_STOMP_RADIUS: float = 2.15
const R2_DEER_MIN_HEIGHT: float = 0.38
const R2_DEER_MAX_HEIGHT: float = 2.65
const R2_MONKEY_SLAM_RADIUS: float = 3.05
const R2_MONKEY_SLAM_CENTER_RADIUS: float = 1.35
const R2_MONKEY_SLAM_OUTER_SCALE: float = 0.55
const R2_MONKEY_SLAM_MAX_TARGETS: int = 5
const R2_BEAR_WIDE_MAX_TARGETS: int = 3
const R2_BEAR_WIDE_KNOCKBACK_SCALE: float = 0.88
const R2_CROCODILE_TAIL_ARC_DOT: float = -0.34 # about a 220 degree control arc
const R2_RABBIT_HOP_SCALE: float = 0.28
const R2_RACCOON_STEAL_AMOUNT: int = 1
const R2_RACCOON_TARGET_PROTECTION_SECONDS: float = 1.25
const R2_SIGNATURE_RECOVERY_MAX: float = 0.80

var _r2_jump_armed_by_id: Dictionary = {}
var _r2_was_grounded_by_id: Dictionary = {}
var _r2_raccoon_target_protected_until: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in racers:
		_r2_register_species_state(racer)
	print("ROUND2 SPECIES COMBAT V19 READY deer=running_stomp monkey=ground_slam elephant=push bear=wide_shove boar=charge crocodile=tail_sweep wolf=medium_pounce cat=fast_pounce fox=dash_bump rabbit=hop_kick raccoon=steal dog=shoulder")

func _register_racer_state(racer: WildDashCharacterController) -> void:
	super(racer)
	_r2_register_species_state(racer)

func _r2_register_species_state(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var id: int = racer.get_instance_id()
	_r2_jump_armed_by_id[id] = false
	_r2_was_grounded_by_id[id] = racer.is_on_floor()

func _physics_process(delta: float) -> void:
	_r2_capture_intentional_jump_launches()
	super(delta)
	_r2_refresh_ground_state()
	_r2_cleanup_target_steal_protection()

func _r2_species_active() -> bool:
	return not mode_finished and GameManager.round_active and GameManager.get_current_round_id() == &"fruit_collection"

# -----------------------------------------------------------------------------
# Shared input: existing body-check / hold gesture remains authoritative.
# -----------------------------------------------------------------------------

func _try_player_body_check() -> void:
	if not _r2_species_active() or player == null:
		super()
		return
	# Rabbit's existing FAST KICK remains the attack authority; the small hop only
	# changes readability and never grants another hit or a new input binding.
	if player.animal_id == &"rabbit" and player.is_on_floor() and _player_body_check_cooldown <= 0.0 and not _is_stunned(player):
		player.velocity.y = maxf(player.velocity.y, player.jump_velocity * R2_RABBIT_HOP_SCALE)
	super()

func _on_round2_combat_gesture(action: Dictionary) -> void:
	if not _r2_species_active() or player == null:
		return
	var kind: StringName = StringName(action.get("kind", &""))
	if player.animal_id == &"bear" and kind == &"hold":
		if _combat_v2_heavy_recovery_remaining <= 0.0 and not _is_stunned(player):
			_r2_bear_wide_shove(player)
		return
	super(action)

# -----------------------------------------------------------------------------
# Deer Running Stomp / Monkey Ground Slam.
# Only an intentional upward launch arms these signatures, so walking off a
# platform cannot silently become an attack.
# -----------------------------------------------------------------------------

func _r2_capture_intentional_jump_launches() -> void:
	if not _r2_species_active():
		return
	for racer: WildDashCharacterController in racers:
		if racer == null or racer.finished or racer.animal_id not in [&"deer", &"monkey"]:
			continue
		var id: int = racer.get_instance_id()
		var was_grounded: bool = bool(_r2_was_grounded_by_id.get(id, racer.is_on_floor()))
		if was_grounded and not racer.is_on_floor() and racer.velocity.y > 0.45:
			_r2_jump_armed_by_id[id] = true

func _r2_refresh_ground_state() -> void:
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		if racer.is_on_floor() and bool(_r2_was_grounded_by_id.get(id, false)) == false and racer.velocity.y <= 0.25:
			# Landing without a valid hit closes the aerial window immediately.
			_r2_jump_armed_by_id[id] = false
		_r2_was_grounded_by_id[id] = racer.is_on_floor()

func _update_round2_aerial_combat() -> void:
	if player == null or not _r2_species_active():
		return
	if player.animal_id == &"deer":
		if _r2_can_resolve_signature_air(player):
			var target: WildDashCharacterController = _r2_deer_stomp_target(player)
			if target != null and _r2_apply_deer_stomp(player, target):
				_r2_jump_armed_by_id[player.get_instance_id()] = false
		return
	if player.animal_id == &"monkey":
		if _r2_can_resolve_signature_air(player) and _r2_apply_monkey_ground_slam(player):
			_r2_jump_armed_by_id[player.get_instance_id()] = false
		return
	super()

func _r2_can_resolve_signature_air(source: WildDashCharacterController) -> bool:
	if source == null or source.is_on_floor() or source.velocity.y > ROUND2_STOMP_MIN_FALL_SPEED:
		return false
	return bool(_r2_jump_armed_by_id.get(source.get_instance_id(), false))

func _r2_deer_stomp_target(source: WildDashCharacterController) -> WildDashCharacterController:
	if source == null:
		return null
	var planar_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
	var run_ratio: float = planar_speed / maxf(1.0, source.arena_move_speed)
	if run_ratio < R2_DEER_MIN_RUN_RATIO:
		return null
	var travel: Vector3 = Vector3(source.velocity.x, 0.0, source.velocity.z)
	if travel.length_squared() <= 0.01:
		travel = -source.global_transform.basis.z
	travel.y = 0.0
	travel = travel.normalized()
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var height: float = source.global_position.y - target.global_position.y
		if height < R2_DEER_MIN_HEIGHT or height > R2_DEER_MAX_HEIGHT:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > R2_DEER_STOMP_RADIUS:
			continue
		if travel.dot(offset.normalized()) < -0.05:
			continue
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _r2_apply_deer_stomp(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"deer")
	if spec == null:
		return false
	var height: float = source.global_position.y - target.global_position.y
	var horizontal_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(source, source.velocity.y, height, horizontal_speed)
	var context: Dictionary = {
		"airborne": true,
		"in_water": _is_river_position(source.global_position),
		"momentum_multiplier": aerial_scale,
	}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	if not result.applied:
		return false
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = -source.global_transform.basis.z
	target.apply_knockback(offset.normalized(), result.knockback)
	var spilled: int = _combat_v2_try_spill(target, mini(1, maxi(1, result.fruit_spill)), "DEER RUNNING STOMP")
	_r2_short_hit_feedback(target, 0.34)
	source.velocity.y = maxf(source.velocity.y, source.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(&"deer"))
	_r2_finish_signature_attack(source, minf(spec.cooldown, R2_SIGNATURE_RECOVERY_MAX))
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.45, &"stomp", 1.0)
	AudioManager.play_sfx_id("hit", 0.94)
	if source == player and hud != null:
		hud.set_message("RUNNING STOMP! · FRUIT SPILL +%d" % spilled)
	print("ROUND2 SPECIES COMBAT species=deer attack=running_stomp hit=1 spill=%d momentum=%.2f" % [spilled, aerial_scale])
	return true

func _r2_apply_monkey_ground_slam(source: WildDashCharacterController) -> bool:
	if source == null:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"monkey")
	if spec == null:
		return false
	var candidates: Array[Dictionary] = []
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var height: float = source.global_position.y - target.global_position.y
		if height < 0.48 or height > 3.45:
			continue
		var planar: Vector3 = target.global_position - source.global_position
		planar.y = 0.0
		var distance: float = planar.length()
		if distance <= R2_MONKEY_SLAM_RADIUS:
			candidates.append({"target": target, "distance": distance, "height": height})
	if candidates.is_empty():
		return false
	candidates.sort_custom(Callable(self, "_r2_sort_target_distance"))
	var hit_count: int = 0
	var spill_budget: int = 1
	for entry: Dictionary in candidates:
		if hit_count >= R2_MONKEY_SLAM_MAX_TARGETS:
			break
		var target: WildDashCharacterController = entry.get("target") as WildDashCharacterController
		if target == null:
			continue
		var distance: float = float(entry.get("distance", R2_MONKEY_SLAM_RADIUS))
		var height: float = float(entry.get("height", 0.8))
		var horizontal_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
		var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(source, source.velocity.y, height, horizontal_speed)
		var context: Dictionary = {
			"airborne": true,
			"in_water": _is_river_position(source.global_position),
			"momentum_multiplier": aerial_scale,
		}
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
		if not result.applied:
			continue
		var center: bool = distance <= R2_MONKEY_SLAM_CENTER_RADIUS
		var force_scale: float = 1.0 if center else R2_MONKEY_SLAM_OUTER_SCALE
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			offset = -source.global_transform.basis.z
		target.apply_knockback(offset.normalized(), result.knockback * force_scale)
		_r2_short_hit_feedback(target, 0.36 if center else 0.22)
		if center and spill_budget > 0:
			spill_budget -= _combat_v2_try_spill(target, 1, "MONKEY GROUND SLAM")
		hit_count += 1
	if hit_count <= 0:
		return false
	source.velocity.y = maxf(source.velocity.y, source.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(&"monkey"))
	_r2_finish_signature_attack(source, minf(spec.cooldown, R2_SIGNATURE_RECOVERY_MAX))
	WildDashCombatV2FX.spawn_impact(self, source.global_position + Vector3.UP * 0.20, &"stomp", 1.20)
	AudioManager.play_sfx_id("hit", 0.96)
	if source == player and hud != null:
		hud.set_message("GROUND SLAM! · CENTER 100% · OUTER 55% · TARGETS %d" % hit_count)
	print("ROUND2 SPECIES COMBAT species=monkey attack=ground_slam hits=%d center_scale=1.00 outer_scale=%.2f spill_budget=1" % [hit_count, R2_MONKEY_SLAM_OUTER_SCALE])
	return true

# -----------------------------------------------------------------------------
# Bear wide shove / Crocodile control sweep.
# -----------------------------------------------------------------------------

func _r2_bear_wide_shove(source: WildDashCharacterController) -> bool:
	if source == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"bear")
	if spec == null:
		return false
	var candidates: Array[Dictionary] = _r2_collect_arc_targets(source, spec.range, spec.arc_dot)
	if candidates.is_empty():
		_r2_finish_signature_attack(source, minf(spec.recovery, R2_SIGNATURE_RECOVERY_MAX))
		if source == player and hud != null:
			hud.set_message("WIDE SHOVE · NO TARGET")
		return false
	var hits: int = 0
	var spill_budget: int = 1
	for entry: Dictionary in candidates:
		if hits >= R2_BEAR_WIDE_MAX_TARGETS:
			break
		var target: WildDashCharacterController = entry.get("target") as WildDashCharacterController
		if target == null:
			continue
		var context: Dictionary = {"in_water": _is_river_position(source.global_position)}
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
		if not result.applied:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			continue
		target.apply_knockback(offset.normalized(), result.knockback * R2_BEAR_WIDE_KNOCKBACK_SCALE)
		_r2_short_hit_feedback(target, 0.34)
		if spill_budget > 0:
			spill_budget -= _combat_v2_try_spill(target, 1, "BEAR WIDE SHOVE")
		hits += 1
	_r2_finish_signature_attack(source, minf(spec.recovery, R2_SIGNATURE_RECOVERY_MAX))
	if hits > 0:
		WildDashCombatV2FX.spawn_impact(self, source.global_position + Vector3.UP * 0.55, &"impact", 1.05)
		AudioManager.play_sfx_id("hit", 0.96)
	if source == player and hud != null:
		hud.set_message("WIDE SHOVE! · TARGETS %d" % hits)
	print("ROUND2 SPECIES COMBAT species=bear attack=wide_shove hits=%d max_targets=%d kb_scale=%.2f" % [hits, R2_BEAR_WIDE_MAX_TARGETS, R2_BEAR_WIDE_KNOCKBACK_SCALE])
	return hits > 0

func _do_crocodile_tail_sweep() -> void:
	if player == null:
		return
	_r2_crocodile_tail_sweep(player)

func _r2_crocodile_tail_sweep(source: WildDashCharacterController) -> bool:
	if source == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"crocodile")
	if spec == null:
		return false
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var hits: int = 0
	var spill_budget: int = 1
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > spec.range:
			continue
		if forward.dot(offset.normalized()) < R2_CROCODILE_TAIL_ARC_DOT:
			continue
		var directional_multiplier: float = WildDashCombatAbilitySystem.get_tail_direction_multiplier(source, target)
		var context: Dictionary = {
			"in_water": _is_river_position(source.global_position),
			"directional_multiplier": directional_multiplier,
		}
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
		if not result.applied:
			continue
		target.apply_knockback(offset.normalized(), result.knockback)
		_r2_short_hit_feedback(target, 0.26)
		if spill_budget > 0:
			spill_budget -= _combat_v2_try_spill(target, 1, "CROCODILE TAIL SWEEP V19")
		hits += 1
	_r2_finish_signature_attack(source, minf(spec.recovery, R2_SIGNATURE_RECOVERY_MAX))
	if hits > 0:
		AudioManager.play_sfx_id("hit", 0.88)
	if source == player and hud != null:
		hud.set_message("TAIL SWEEP! · SPACE CONTROL · TARGETS %d" % hits)
	print("ROUND2 SPECIES COMBAT species=crocodile attack=tail_sweep hits=%d arc_degrees=220 spill_budget=1" % hits)
	return hits > 0

# -----------------------------------------------------------------------------
# Raccoon thief: one fruit per successful swipe, source cooldown plus recent
# target protection. It uses the same carry authority as the existing V10 steal.
# -----------------------------------------------------------------------------

func _phase3_round2_profile_attack(source: WildDashCharacterController, heavy: bool) -> bool:
	if source == null or source.animal_id != &"raccoon":
		return super(source, heavy)
	if not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"raccoon") if heavy else WildDashCombatAbilitySystem.get_basic_attack(&"raccoon")
	if spec == null:
		return false
	var target: WildDashCharacterController = _combat_v2_front_target(source, spec.range, spec.arc_dot)
	var momentum_ratio: float = clampf(Vector2(source.velocity.x, source.velocity.z).length() / maxf(1.0, source.arena_move_speed), 0.0, 1.0)
	var context: Dictionary = {
		"in_water": _is_river_position(source.global_position),
		"momentum_multiplier": WildDashCombatAbilitySystem.get_momentum_effect_multiplier(spec, momentum_ratio),
	}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	if not result.applied:
		return false
	if target == null:
		_r2_finish_signature_attack(source, minf(spec.recovery if heavy else spec.cooldown, R2_SIGNATURE_RECOVERY_MAX))
		if source == player and hud != null:
			hud.set_message("FRUIT SWIPE · NO TARGET")
		return false
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return false
	target.apply_knockback(offset.normalized(), result.knockback)
	var stole: bool = _phase3_try_quick_steal(source, target)
	_r2_short_hit_feedback(target, 0.24)
	_r2_finish_signature_attack(source, minf(spec.recovery if heavy else spec.cooldown, R2_SIGNATURE_RECOVERY_MAX))
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.55, &"control", 0.90)
	AudioManager.play_sfx_id("item" if stole else "hit", 0.82)
	if source == player and hud != null:
		hud.set_message("FRUIT SWIPE! · STEAL +1" if stole else "FRUIT SWIPE! · TARGET PROTECTED")
	print("ROUND2 SPECIES COMBAT species=raccoon attack=fruit_swipe hit=1 steal=%d target_protection=%.2fs" % [1 if stole else 0, R2_RACCOON_TARGET_PROTECTION_SECONDS])
	return true

func _phase3_try_quick_steal(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var source_id: int = source.get_instance_id()
	var target_id: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	if float(_phase3_steal_cooldown_by_id.get(source_id, 0.0)) > 0.0:
		return false
	if float(_r2_raccoon_target_protected_until.get(target_id, 0.0)) > now:
		return false
	if _get_carry(target) <= 0 or _get_carry(source) >= MAX_CARRY:
		return false
	var steal_amount: int = mini(R2_RACCOON_STEAL_AMOUNT, mini(_get_carry(target), MAX_CARRY - _get_carry(source)))
	if steal_amount <= 0:
		return false
	carried_by_id[target_id] = _get_carry(target) - steal_amount
	_add_carry(source, steal_amount)
	_phase3_steal_cooldown_by_id[source_id] = RACCOON_STEAL_COOLDOWN
	_r2_raccoon_target_protected_until[target_id] = now + R2_RACCOON_TARGET_PROTECTION_SECONDS
	if target == player:
		_show_event("FRUIT STOLEN! -%d" % steal_amount, 0.9)
	return true

func _r2_cleanup_target_steal_protection() -> void:
	if _r2_raccoon_target_protected_until.is_empty():
		return
	var now: float = Time.get_ticks_msec() * 0.001
	for id_value: Variant in _r2_raccoon_target_protected_until.keys():
		if float(_r2_raccoon_target_protected_until.get(id_value, 0.0)) <= now:
			_r2_raccoon_target_protected_until.erase(id_value)

# -----------------------------------------------------------------------------
# AI: V12/V15 still decides whether combat is worth pursuing. This override only
# executes the chosen species attack, using the same shared specs as the player.
# -----------------------------------------------------------------------------

func _try_ai_attack(attacker: WildDashCharacterController, target: WildDashCharacterController, _personality: StringName) -> void:
	if attacker == null or target == null or not _r2_species_active():
		return
	var id: int = attacker.get_instance_id()
	if float(ai_attack_cooldown_by_id.get(id, 0.0)) > 0.0 or _is_stunned(attacker):
		return
	var distance: float = attacker.global_position.distance_to(target.global_position)
	match attacker.animal_id:
		&"bear":
			var bear_spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"bear")
			if bear_spec != null and distance <= bear_spec.range + 0.35:
				_r2_bear_wide_shove(attacker)
		&"crocodile":
			var tail_spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"crocodile")
			if tail_spec != null and distance <= tail_spec.range + 0.35:
				_r2_crocodile_tail_sweep(attacker)
		&"wolf", &"boar", &"cat":
			var heavy_spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(attacker.animal_id)
			if heavy_spec != null and distance <= heavy_spec.range + 0.35:
				_phase3_round2_profile_attack(attacker, true)
		&"elephant", &"dog", &"fox", &"rabbit", &"deer", &"monkey", &"raccoon":
			var basic_spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(attacker.animal_id)
			if basic_spec != null and distance <= basic_spec.range + 0.35:
				_phase3_round2_profile_attack(attacker, false)

func _update_final_ai_aerial_combat() -> void:
	if not _r2_species_active():
		return
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished or not FINAL_AERIAL_AI_IDS.has(racer.animal_id):
			continue
		var id: int = racer.get_instance_id()
		var canopy: WildDashCanopyTraversalSystem = _phase3_ai_canopy_by_id.get(id, null) as WildDashCanopyTraversalSystem
		if canopy != null and canopy.is_swinging():
			continue
		var target: WildDashCharacterController = _final_ai_aerial_target(racer)
		if target == null:
			_final_ai_aerial_armed[id] = false
			continue
		var planar_distance: float = Vector2(target.global_position.x - racer.global_position.x, target.global_position.z - racer.global_position.z).length()
		if racer.is_on_floor():
			if float(_final_ai_aerial_cooldown.get(id, 0.0)) > 0.0:
				continue
			if planar_distance >= 1.9 and planar_distance <= 4.8:
				var phase: int = int(Time.get_ticks_msec() / 420) + id
				if phase % 5 == 0:
					racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * _final_ai_jump_scale(racer.animal_id))
					_final_ai_aerial_armed[id] = true
					_r2_jump_armed_by_id[id] = true
			continue
		if not bool(_final_ai_aerial_armed.get(id, false)) or racer.velocity.y > -0.30:
			continue
		var height: float = racer.global_position.y - target.global_position.y
		if height < 0.38 or height > 3.45:
			continue
		var applied: bool = false
		if racer.animal_id == &"deer":
			applied = _r2_apply_deer_stomp(racer, target)
		elif racer.animal_id == &"monkey":
			applied = _r2_apply_monkey_ground_slam(racer)
		else:
			applied = _r2_apply_legacy_ai_aerial(racer, target)
		if applied:
			_final_ai_aerial_armed[id] = false
			_r2_jump_armed_by_id[id] = false
			_final_ai_aerial_cooldown[id] = FINAL_AERIAL_AI_REARM

func _r2_apply_legacy_ai_aerial(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(source.animal_id)
	if spec == null:
		return false
	var height: float = source.global_position.y - target.global_position.y
	var horizontal_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(source, source.velocity.y, height, horizontal_speed)
	var context: Dictionary = {"airborne": true, "in_water": _is_river_position(source.global_position), "momentum_multiplier": aerial_scale}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	if not result.applied:
		return false
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = Vector3.FORWARD
	target.apply_knockback(offset.normalized(), result.knockback)
	_combat_v2_try_spill(target, 1, "AI %s" % spec.display_name)
	_r2_short_hit_feedback(target, 0.28)
	source.velocity.y = maxf(source.velocity.y, source.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(source.animal_id))
	ai_attack_cooldown_by_id[source.get_instance_id()] = maxf(0.72, minf(spec.cooldown, R2_SIGNATURE_RECOVERY_MAX))
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.45, &"stomp", 0.90)
	return true

# -----------------------------------------------------------------------------
# Utility helpers
# -----------------------------------------------------------------------------

func _r2_collect_arc_targets(source: WildDashCharacterController, attack_range: float, arc_dot: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source == null:
		return result
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		if absf(offset.y) > 1.9:
			continue
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > attack_range:
			continue
		if forward.dot(offset.normalized()) < arc_dot:
			continue
		result.append({"target": target, "distance": distance})
	result.sort_custom(Callable(self, "_r2_sort_target_distance"))
	return result

func _r2_sort_target_distance(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("distance", INF)) < float(b.get("distance", INF))

func _r2_short_hit_feedback(target: WildDashCharacterController, seconds: float) -> void:
	if target == null:
		return
	var visual: WildDashCharacterVisual = target.get_visual()
	if visual != null:
		visual.play_action(&"Hit", clampf(seconds, 0.20, 0.40))

func _r2_finish_signature_attack(source: WildDashCharacterController, recovery: float) -> void:
	if source == null:
		return
	var bounded: float = clampf(recovery, 0.18, R2_SIGNATURE_RECOVERY_MAX)
	if source == player:
		_player_body_check_cooldown = maxf(_player_body_check_cooldown, bounded)
		_combat_v2_heavy_recovery_remaining = maxf(_combat_v2_heavy_recovery_remaining, bounded)
	else:
		ai_attack_cooldown_by_id[source.get_instance_id()] = maxf(float(ai_attack_cooldown_by_id.get(source.get_instance_id(), 0.0)), bounded)
