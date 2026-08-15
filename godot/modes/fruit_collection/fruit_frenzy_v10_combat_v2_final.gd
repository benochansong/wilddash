extends "res://modes/fruit_collection/fruit_frenzy_v9_canopy_safety.gd"

## Round 2 Combat V2 final adapter.
## Character data lives in typed shared profiles; this layer only translates the
## abilities into Fruit Frenzy's carry/spill authority and character-aware AI.

const PHASE3_PLAYER_IDS: Array[StringName] = [&"dog", &"wolf", &"boar", &"elephant", &"bear", &"raccoon"]
const RACCOON_STEAL_COOLDOWN: float = 1.85
const PHASE3_AI_COMBAT_RANGE: float = 10.5
const PHASE3_AI_MAX_CHASERS: int = 2
const PHASE3_BEAR_AERIAL_RADIUS: float = 2.80

var _phase3_steal_cooldown_by_id: Dictionary = {}
var _phase3_aerial_cooldown_remaining: float = 0.0
var _phase3_ai_canopy_by_id: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		_phase3_steal_cooldown_by_id[racer.get_instance_id()] = 0.0
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.animal_id != &"monkey":
			continue
		var system: WildDashCanopyTraversalSystem = WildDashCanopyTraversalSystem.new()
		system.set_routes(_canopy_routes)
		_phase3_ai_canopy_by_id[racer.get_instance_id()] = system
	print("FRUIT FRENZY COMBAT V2 FINAL READY heavy=true hunter=true thief=true water_ambush=true ai_roles=true monkey_ai_canopy=true")

func _exit_tree() -> void:
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var system: WildDashCanopyTraversalSystem = _phase3_ai_canopy_by_id.get(racer.get_instance_id(), null) as WildDashCanopyTraversalSystem
		if system != null and system.is_swinging():
			system.cancel_vine(racer)
	super()

func _physics_process(delta: float) -> void:
	super(delta)
	_phase3_aerial_cooldown_remaining = maxf(0.0, _phase3_aerial_cooldown_remaining - delta)
	_phase3_update_monkey_ai_canopy(delta)

func _register_racer_state(racer: WildDashCharacterController) -> void:
	super(racer)
	if racer != null:
		_phase3_steal_cooldown_by_id[racer.get_instance_id()] = 0.0

func _update_runtime_cooldowns(delta: float) -> void:
	super(delta)
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		_phase3_steal_cooldown_by_id[id] = maxf(0.0, float(_phase3_steal_cooldown_by_id.get(id, 0.0)) - delta)

func _try_player_body_check() -> void:
	if player != null and PHASE3_PLAYER_IDS.has(player.animal_id):
		if _player_body_check_cooldown <= 0.0 and not _is_stunned(player):
			_phase3_round2_profile_attack(player, false)
		return
	super()

func _on_round2_combat_gesture(action: Dictionary) -> void:
	if player != null and PHASE3_PLAYER_IDS.has(player.animal_id):
		if mode_finished or not GameManager.round_active:
			return
		var kind: StringName = StringName(action.get("kind", &""))
		if kind == &"hold" and _combat_v2_heavy_recovery_remaining <= 0.0 and not _is_stunned(player):
			_phase3_round2_profile_attack(player, true)
		return
	super(action)

func _phase3_round2_profile_attack(source: WildDashCharacterController, heavy: bool) -> bool:
	if source == null:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(source.animal_id) if heavy else WildDashCombatAbilitySystem.get_basic_attack(source.animal_id)
	if spec == null:
		return false
	var target: WildDashCharacterController = _combat_v2_front_target(source, spec.range, spec.arc_dot)
	var momentum_ratio: float = clampf(Vector2(source.velocity.x, source.velocity.z).length() / maxf(1.0, source.arena_move_speed), 0.0, 1.0)
	var momentum_multiplier: float = WildDashCombatAbilitySystem.get_momentum_effect_multiplier(spec, momentum_ratio)
	var context: Dictionary = {
		"in_water": _is_river_position(source.global_position),
		"momentum_multiplier": momentum_multiplier,
	}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	if not result.applied:
		return false

	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	if result.mobility_impulse > 0.01:
		source.apply_knockback(forward, result.mobility_impulse)

	if target == null:
		if source == player and hud != null:
			hud.set_message("%s · NO TARGET" % spec.display_name)
		if source.animal_id == &"boar" and heavy:
			_combat_v2_heavy_recovery_remaining = maxf(_combat_v2_heavy_recovery_remaining, 0.78)
		return false

	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return false
	var behind: bool = WildDashCombatV2AIBrain.is_behind_target(source, target)
	if source.animal_id == &"wolf" and heavy and behind:
		result.knockback *= 1.22
		result.stagger *= 1.24

	# Raccoon converts a successful rear hit into a direct steal instead of
	# spawning a loose fruit. This makes the thief identity mechanically distinct.
	var stole: bool = false
	if source.animal_id == &"raccoon" and behind:
		stole = _phase3_try_quick_steal(source, target)

	target.apply_knockback(offset.normalized(), result.knockback)
	var spilled: int = 0
	if not stole:
		spilled = _combat_v2_try_spill(target, result.fruit_spill, spec.display_name)
	_apply_power_stun(source, target)
	AudioManager.play_sfx_id("hit", 1.0 if heavy else 0.88)
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.65, _phase3_fx_kind(source.animal_id, heavy), 1.0 if not heavy else 1.18)

	if source == player and hud != null:
		if stole:
			hud.set_message("FRUIT STOLEN! · QUICK STEAL +1")
		elif source.animal_id == &"wolf" and heavy and behind:
			hud.set_message("REAR POUNCE! · FRUIT SPILL +%d" % spilled)
		elif source.animal_id == &"boar" and heavy:
			hud.set_message("BOAR CHARGE! · FRUIT SPILL +%d" % spilled)
		elif source.animal_id == &"elephant":
			hud.set_message("%s! · PUSH · SPILL +%d" % [spec.display_name, spilled])
		else:
			hud.set_message("%s!%s" % [spec.display_name, " · FRUIT SPILL +%d" % spilled if spilled > 0 else ""])

	if source == player:
		if heavy:
			_combat_v2_heavy_recovery_remaining = maxf(0.20, spec.recovery)
		else:
			_player_body_check_cooldown = maxf(0.18, minf(0.82, spec.cooldown))
	else:
		ai_attack_cooldown_by_id[source.get_instance_id()] = maxf(0.72, spec.cooldown)
	return true

func _update_round2_aerial_combat() -> void:
	super()
	if player == null or player.animal_id != &"bear" or _phase3_aerial_cooldown_remaining > 0.0:
		return
	if player.is_on_floor() or player.velocity.y > ROUND2_STOMP_MIN_FALL_SPEED:
		return
	var target: WildDashCharacterController = _nearest_round2_target(player, PHASE3_BEAR_AERIAL_RADIUS)
	if target == null:
		return
	var height_difference: float = player.global_position.y - target.global_position.y
	if height_difference < 0.55 or height_difference > 3.2:
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"bear")
	if spec == null:
		return
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(player, player.velocity.y, height_difference, horizontal_speed)
	var context: Dictionary = {"airborne": true, "in_water": _is_river_position(player.global_position), "momentum_multiplier": aerial_scale}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, target, spec, &"fruit_collection", context)
	if not result.applied:
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = Vector3.FORWARD
	target.apply_knockback(offset.normalized(), result.knockback)
	var spilled: int = _combat_v2_try_spill(target, 1, "BEAR BELLY DROP")
	player.velocity.y = maxf(player.velocity.y, player.jump_velocity * 0.28)
	_phase3_aerial_cooldown_remaining = spec.cooldown
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.35, &"stomp", 1.35)
	if hud != null:
		hud.set_message("BELLY DROP! · FRUIT SPILL +%d" % spilled)

func _try_use_round2_special(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return false
	if racer.animal_id == &"crocodile":
		return _phase3_crocodile_water_ambush(racer)
	if racer.animal_id == &"elephant":
		return _phase3_elephant_ground_stomp(racer)
	return super(racer)

func _phase3_crocodile_water_ambush(source: WildDashCharacterController) -> bool:
	var id: int = source.get_instance_id()
	if float(_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"crocodile")
	if spec == null:
		return false
	var in_water: bool = _is_river_position(source.global_position)
	var attack_range: float = WildDashCombatAbilitySystem.get_effective_range(spec, in_water)
	var target: WildDashCharacterController = _combat_v2_front_target(source, attack_range, spec.arc_dot)
	var context: Dictionary = {"in_water": in_water}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var lunge: float = result.mobility_impulse if in_water else result.mobility_impulse * 0.55
	source.apply_knockback(forward, lunge)
	_special_cooldown_by_id[id] = spec.cooldown
	WildDashCombatV2FX.spawn_trail(self, source.global_position + Vector3.UP * 0.55, forward, &"water", 1.15)
	if target == null:
		if source == player and hud != null:
			hud.set_message("WATER AMBUSH · NO TARGET%s" % ("" if in_water else " · LAND 55%"))
		return true
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() > 0.001:
		target.apply_knockback(offset.normalized(), result.knockback)
	var spilled: int = _combat_v2_try_spill(target, 2, "CROCODILE WATER AMBUSH")
	_apply_power_stun(source, target)
	AudioManager.play_sfx_id("hit", 1.0)
	if source == player and hud != null:
		hud.set_message("WATER AMBUSH! · FRUIT SPILL +%d%s" % [spilled, " · WATER POWER" if in_water else " · LAND 55%"])
	return true

func _phase3_elephant_ground_stomp(source: WildDashCharacterController) -> bool:
	var id: int = source.get_instance_id()
	if float(_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"elephant")
	if spec == null:
		return false
	_special_cooldown_by_id[id] = spec.cooldown
	var spill_budget: int = 1
	var hits: int = 0
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > spec.range:
			continue
		var context: Dictionary = {"in_water": _is_river_position(source.global_position)}
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
		target.apply_knockback(offset.normalized(), result.knockback * lerpf(1.0, 0.60, distance / spec.range))
		if spill_budget > 0:
			var spilled: int = _combat_v2_try_spill(target, 1, "ELEPHANT GROUND STOMP")
			spill_budget -= spilled
		hits += 1
	WildDashCombatV2FX.spawn_impact(self, source.global_position + Vector3.UP * 0.15, &"stomp", 1.65)
	AudioManager.play_sfx_id("hit", 0.95)
	if source == player and hud != null:
		hud.set_message("GROUND STOMP! · TARGETS %d" % hits)
	return true

func _phase3_try_quick_steal(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var source_id: int = source.get_instance_id()
	if float(_phase3_steal_cooldown_by_id.get(source_id, 0.0)) > 0.0:
		return false
	if _get_carry(target) <= 0 or _get_carry(source) >= MAX_CARRY:
		return false
	carried_by_id[target.get_instance_id()] = _get_carry(target) - 1
	_add_carry(source, 1)
	_phase3_steal_cooldown_by_id[source_id] = RACCOON_STEAL_COOLDOWN
	AudioManager.play_sfx_id("item", 0.78)
	if target == player:
		_show_event("FRUIT STOLEN! -1", 0.9)
	return true

func _update_ai_decisions() -> void:
	super()
	_phase3_update_round2_combat_ai()

func _phase3_update_round2_combat_ai() -> void:
	var assigned: Dictionary = {}
	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			continue
		var source: WildDashCharacterController = ai_racers[i]
		if source == null or source.finished or _get_carry(source) >= 4:
			continue
		if float(ai_attack_cooldown_by_id.get(source.get_instance_id(), 0.0)) > 0.0:
			continue
		var target: WildDashCharacterController = _phase3_best_round2_ai_target(source, assigned)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		assigned[target_id] = int(assigned.get(target_id, 0)) + 1
		ai_drivers[i].set_arena_target(target.global_position)
		var distance: float = source.global_position.distance_to(target.global_position)
		if source.animal_id == &"crocodile" and _is_river_position(source.global_position) and distance <= 4.8:
			_phase3_crocodile_water_ambush(source)
			continue
		var behind: bool = WildDashCombatV2AIBrain.is_behind_target(source, target)
		var tick: int = int(Time.get_ticks_msec() / 800)
		var kind: StringName = WildDashCombatV2AIBrain.preferred_attack_kind(source.animal_id, 0.0, distance, behind, tick + i)
		var heavy: bool = kind == &"hold"
		var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(source.animal_id) if heavy else WildDashCombatAbilitySystem.get_basic_attack(source.animal_id)
		if spec == null or distance > spec.range + 0.45:
			continue
		_phase3_round2_profile_attack(source, heavy)

func _phase3_best_round2_ai_target(source: WildDashCharacterController, assigned: Dictionary) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_score: float = INF
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished or _get_carry(target) <= 0:
			continue
		var direct_chasers: int = int(assigned.get(target.get_instance_id(), 0))
		if direct_chasers >= PHASE3_AI_MAX_CHASERS:
			continue
		var distance: float = source.global_position.distance_to(target.global_position)
		if distance > PHASE3_AI_COMBAT_RANGE:
			continue
		var terrain_advantage: float = 1.0 if source.animal_id == &"crocodile" and _is_river_position(source.global_position) else 0.0
		var score: float = WildDashCombatV2AIBrain.target_score(source, target, &"fruit_collection", _get_carry(target), 0.0, 0.0, false, terrain_advantage, direct_chasers)
		if score < best_score:
			best_score = score
			best = target
	return best

func _phase3_update_monkey_ai_canopy(delta: float) -> void:
	if _canopy_routes.is_empty():
		return
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished or racer.animal_id != &"monkey":
			continue
		var system: WildDashCanopyTraversalSystem = _phase3_ai_canopy_by_id.get(racer.get_instance_id(), null) as WildDashCanopyTraversalSystem
		if system == null:
			continue
		if system.is_swinging():
			var reached_end: bool = system.update_swing(racer, delta, 0.55)
			var nearby: WildDashCharacterController = _nearest_round2_target(racer, 3.0)
			if nearby != null and _get_carry(nearby) > 0 and float(ai_attack_cooldown_by_id.get(racer.get_instance_id(), 0.0)) <= 0.0:
				_phase3_monkey_ai_swing_kick(racer, nearby, system)
			if reached_end:
				racer.velocity = system.release_vine(racer, false) + Vector3.UP * 1.05
			continue
		if _get_carry(racer) >= 4:
			continue
		var tree_fruit: MeshInstance3D = _phase3_nearest_tree_fruit(racer)
		if tree_fruit == null or racer.global_position.distance_to(tree_fruit.global_position) > 12.0:
			continue
		var route: WildDashCanopyVineRoute = system.find_nearest_vine(racer.global_position, 3.9)
		if route != null:
			system.grab_vine(racer, route)

func _phase3_nearest_tree_fruit(racer: WildDashCharacterController) -> MeshInstance3D:
	var best: MeshInstance3D
	var best_distance: float = INF
	for i: int in range(fruits.size()):
		if not fruit_active[i]:
			continue
		if WildDashFruitAccessSystem.get_access_type(fruits[i]) != WildDashFruitAccessSystem.FruitAccessType.TREE:
			continue
		var distance: float = racer.global_position.distance_squared_to(fruits[i].global_position)
		if distance < best_distance:
			best_distance = distance
			best = fruits[i]
	return best

func _phase3_monkey_ai_swing_kick(source: WildDashCharacterController, target: WildDashCharacterController, system: WildDashCanopyTraversalSystem) -> void:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_mobility_attack(&"monkey")
	if spec == null:
		return
	var scale: float = WildDashCombatAbilitySystem.get_monkey_swing_impact_scale(system.get_swing_speed_ratio())
	var context: Dictionary = {"airborne": true, "in_water": false, "momentum_multiplier": scale}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if result.applied and offset.length_squared() > 0.001:
		target.apply_knockback(offset.normalized(), result.knockback)
		_combat_v2_try_spill(target, 1, "AI MONKEY SWING KICK")
		ai_attack_cooldown_by_id[source.get_instance_id()] = 0.82

func _phase3_fx_kind(animal_id: StringName, heavy: bool) -> StringName:
	if animal_id == &"boar" and heavy:
		return &"charge"
	if animal_id == &"elephant":
		return &"push"
	if animal_id == &"raccoon":
		return &"control"
	return &"impact"
