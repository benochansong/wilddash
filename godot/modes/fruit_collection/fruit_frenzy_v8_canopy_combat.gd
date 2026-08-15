extends "res://modes/fruit_collection/fruit_frenzy_v7_combat_v2.gd"

## Round 2 V8: Monkey canopy traversal + agile/aerial Combat V2 identities.
## Heavy-character specialization stays for the next phase. Fruit Frenzy remains
## authoritative for carry/spill and the legacy Q fart specials stay untouched.

const AGILE_COMBAT_IDS: Array[StringName] = [&"monkey", &"rabbit", &"deer", &"cat", &"fox"]
const ROUND2_STOMP_MIN_HEIGHT: float = 0.36
const ROUND2_STOMP_MAX_HEIGHT: float = 2.75
const ROUND2_STOMP_MIN_FALL_SPEED: float = -0.42
const ROUND2_STOMP_RADIUS: float = 2.35
const CAT_AMBUSH_SPEED_SCALE: float = 1.15
const CAT_AMBUSH_SPEED_SECONDS: float = 0.60
const FOX_ESCAPE_SPEED_SCALE: float = 1.12
const FOX_ESCAPE_SPEED_SECONDS: float = 0.50
const MONKEY_AIR_FLOW_SPEED_SCALE: float = 1.10
const MONKEY_AIR_FLOW_SECONDS: float = 0.50

var _canopy: WildDashCanopyTraversalSystem = WildDashCanopyTraversalSystem.new()
var _canopy_routes: Array[WildDashCanopyVineRoute] = []
var _canopy_visual_root: Node3D
var _combat_v2_heavy_recovery_remaining: float = 0.0
var _combat_v2_speed_bonus_remaining: float = 0.0
var _combat_v2_speed_bonus_scale: float = 1.0
var _canopy_attack_suppress_hold_remaining: float = 0.0
var _rabbit_chain_remaining: float = 0.0
var _rabbit_chain_count: int = 0

func _ready() -> void:
	await super()
	_build_round2_canopy_network()
	print("FRUIT FRENZY V8 CANOPY COMBAT READY vines=4 monkey_swing=true rabbit_chain=true deer_aerial=true cat_ambush=true fox_hit_run=true")

func _physics_process(delta: float) -> void:
	super(delta)
	_combat_v2_heavy_recovery_remaining = maxf(0.0, _combat_v2_heavy_recovery_remaining - delta)
	_combat_v2_speed_bonus_remaining = maxf(0.0, _combat_v2_speed_bonus_remaining - delta)
	_canopy_attack_suppress_hold_remaining = maxf(0.0, _canopy_attack_suppress_hold_remaining - delta)
	_rabbit_chain_remaining = maxf(0.0, _rabbit_chain_remaining - delta)
	if _rabbit_chain_remaining <= 0.0:
		_rabbit_chain_count = 0
	if mode_finished or not GameManager.round_active or player == null:
		return
	_update_round2_monkey_canopy(delta)
	_update_round2_aerial_combat()

func _update_speed_profiles() -> void:
	super()
	if player != null and _combat_v2_speed_bonus_remaining > 0.0:
		player.arena_move_speed *= _combat_v2_speed_bonus_scale

func _try_player_body_check() -> void:
	if player == null:
		return
	if player.animal_id == &"monkey" and _canopy.is_swinging():
		_perform_monkey_swing_kick_round2()
		return
	if AGILE_COMBAT_IDS.has(player.animal_id):
		if _player_body_check_cooldown > 0.0 or _is_stunned(player):
			return
		var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(player.animal_id)
		_perform_round2_profile_attack(spec, false)
		return
	super()

func _on_round2_combat_gesture(action: Dictionary) -> void:
	if player == null or mode_finished or not GameManager.round_active:
		return
	if not AGILE_COMBAT_IDS.has(player.animal_id):
		super(action)
		return
	var kind: StringName = StringName(action.get("kind", &""))
	if kind != &"hold" or _canopy_attack_suppress_hold_remaining > 0.0:
		return
	if _combat_v2_heavy_recovery_remaining > 0.0 or _is_stunned(player):
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(player.animal_id)
	_perform_round2_profile_attack(spec, true)

func _perform_round2_profile_attack(spec: WildDashCombatAbilitySpec, heavy: bool) -> void:
	if player == null or spec == null:
		return
	var target: WildDashCharacterController = _combat_v2_front_target(player, spec.range, spec.arc_dot)
	var normalized_momentum: float = _player_planar_speed_ratio()
	var momentum_multiplier: float = WildDashCombatAbilitySystem.get_momentum_effect_multiplier(spec, normalized_momentum)
	var context: Dictionary = {
		"in_water": _is_river_position(player.global_position),
		"momentum_multiplier": momentum_multiplier,
	}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, target, spec, &"fruit_collection", context)
	if not result.applied:
		return

	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	if result.mobility_impulse > 0.01:
		player.apply_knockback(forward, result.mobility_impulse)

	if target == null:
		if hud != null:
			hud.set_message("%s · NO TARGET" % spec.display_name)
		if heavy:
			_combat_v2_heavy_recovery_remaining = maxf(0.25, spec.recovery)
		else:
			_player_body_check_cooldown = minf(0.34, maxf(0.18, spec.cooldown))
		return

	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var is_ambush: bool = player.animal_id == &"cat" and _combat_v2_is_back_attack(player, target)
	if is_ambush:
		result.knockback *= 1.18
	\	result.stagger *= 1.24
	target.apply_knockback(offset.normalized(), result.knockback)

	var spill_count: int = result.fruit_spill
	if is_ambush:
		spill_count = maxi(1, spill_count)
	_combat_v2_try_spill(target, spill_count, spec.display_name)
	_apply_power_stun(player, target)
	AudioManager.play_sfx_id("hit", 0.90 if not heavy else 1.0)

	if is_ambush:
		_set_round2_speed_bonus(CAT_AMBUSH_SPEED_SCALE, CAT_AMBUSH_SPEED_SECONDS)
		if hud != null:
			hud.set_message("AMBUSH! · FRUIT SPILL %d" % mini(spill_count, _get_carry(target) + spill_count))
	elif player.animal_id == &"fox":
		_set_round2_speed_bonus(FOX_ESCAPE_SPEED_SCALE, FOX_ESCAPE_SPEED_SECONDS)
		if hud != null:
			hud.set_message("%s! · HIT & RUN" % spec.display_name)
	elif hud != null:
		hud.set_message("%s!" % spec.display_name)

	if heavy:
		_combat_v2_heavy_recovery_remaining = maxf(0.20, spec.recovery)
	else:
		_player_body_check_cooldown = minf(0.34, maxf(0.18, spec.cooldown))
	print("COMBAT V2 ROUND2 animal=%s ability=%s heavy=%s momentum=%.2f kb=%.2f" % [
		String(player.animal_id), String(spec.ability_id), str(heavy), momentum_multiplier, result.knockback,
	])

func _update_round2_aerial_combat() -> void:
	if player == null or not AGILE_COMBAT_IDS.has(player.animal_id):
		return
	if player.is_on_floor() or player.velocity.y > ROUND2_STOMP_MIN_FALL_SPEED:
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(player.animal_id)
	if spec == null:
		return
	var target: WildDashCharacterController = _round2_stomp_target(player)
	if target == null:
		return
	var height_difference: float = player.global_position.y - target.global_position.y
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(player, player.velocity.y, height_difference, horizontal_speed)
	var context: Dictionary = {
		"airborne": true,
		"in_water": _is_river_position(player.global_position),
		"momentum_multiplier": aerial_scale,
	}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, target, spec, &"fruit_collection", context)
	if not result.applied:
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = -player.global_transform.basis.z
	target.apply_knockback(offset.normalized(), result.knockback)
	_combat_v2_try_spill(target, maxi(1, result.fruit_spill), spec.display_name)
	player.velocity.y = maxf(player.velocity.y, player.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(player.animal_id))
	AudioManager.play_sfx_id("hit", 0.92)
	_spawn_round2_attack_puff(target.global_position + Vector3.UP * 0.5, 0.75)

	if player.animal_id == &"rabbit":
		_rabbit_chain_count = mini(3, _rabbit_chain_count + 1) if _rabbit_chain_remaining > 0.0 else 1
		_rabbit_chain_remaining = WildDashAerialCombatSystem.get_chain_window(&"rabbit")
		if hud != null:
			hud.set_message("CHAIN STOMP x%d!" % _rabbit_chain_count)
	elif player.animal_id == &"monkey":
		_set_round2_speed_bonus(MONKEY_AIR_FLOW_SPEED_SCALE, MONKEY_AIR_FLOW_SECONDS)
		if hud != null:
			hud.set_message("CANOPY STOMP! · BOUNCE")
	elif hud != null:
		hud.set_message("%s!" % spec.display_name)
	print("COMBAT V2 AERIAL mode=fruit_collection animal=%s scale=%.2f ability=%s" % [
		String(player.animal_id), aerial_scale, String(spec.ability_id),
	])

func _round2_stomp_target(source: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance: float = INF
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var height_delta: float = source.global_position.y - target.global_position.y
		if height_delta < ROUND2_STOMP_MIN_HEIGHT or height_delta > ROUND2_STOMP_MAX_HEIGHT:
			continue
		var planar: Vector2 = Vector2(target.global_position.x - source.global_position.x, target.global_position.z - source.global_position.z)
		var distance: float = planar.length()
		if distance > ROUND2_STOMP_RADIUS:
			continue
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _build_round2_canopy_network() -> void:
	_canopy_visual_root = Node3D.new()
	_canopy_visual_root.name = "MonkeyCanopyNetwork"
	add_child(_canopy_visual_root)

	var points: Array[Vector3] = [
		Vector3(-19.35, 4.20, -19.20),
		Vector3(-14.85, 4.55, -19.00),
		Vector3(-10.25, 4.35, -18.85),
		Vector3(-14.35, 4.72, -10.90),
		Vector3(-19.55, 4.30, -11.05),
	]
	for i: int in range(points.size()):
		create_box("CanopyLanding_%02d" % i, points[i] - Vector3.UP * 0.24, Vector3(2.2, 0.28, 1.5), Color(0.34, 0.19, 0.07), true)
	for i: int in range(points.size() - 1):
		var route: WildDashCanopyVineRoute = WildDashCanopyVineRoute.new().configure(
			StringName("orchard_vine_%02d" % i),
			points[i],
			points[i + 1],
			1.75 + float(i % 2) * 0.35,
			10.6 + float(i) * 0.25,
			4.35
		)
		_canopy_routes.append(route)
		_add_round2_vine_visual(route)
	_canopy.set_routes(_canopy_routes)

func _update_round2_monkey_canopy(delta: float) -> void:
	if player == null or player.animal_id != &"monkey":
		if _canopy.is_swinging():
			_canopy.clear_active_vine()
		return
	if _canopy.is_swinging():
		if InputManager.consume_jump():
			var release_velocity: Vector3 = _canopy.release_vine(player, true)
			player.velocity = release_velocity
			if hud != null:
				hud.set_message("VINE RELEASE · STOMP WINDOW")
			return
		var move: Vector2 = InputManager.get_move_vector()
		var reached_end: bool = _canopy.update_swing(player, delta, move.x)
		if reached_end:
			var endpoint_velocity: Vector3 = _canopy.release_vine(player, false)
			player.velocity = endpoint_velocity + Vector3.UP * 1.15
		return
	if InputManager.consume_skill():
		var nearest: WildDashCanopyVineRoute = _canopy.find_nearest_vine(player.global_position)
		if nearest != null and _canopy.grab_vine(player, nearest):
			if hud != null:
				hud.set_message("VINE GRAB! · F SWING KICK · SPACE RELEASE")
			print("MONKEY CANOPY GRAB mode=fruit_collection vine=%s" % String(nearest.vine_id))

func _perform_monkey_swing_kick_round2() -> void:
	if player == null or not _canopy.is_swinging():
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_mobility_attack(&"monkey")
	if spec == null:
		return
	var target: WildDashCharacterController = _nearest_round2_target(player, spec.range)
	var swing_ratio: float = _canopy.get_swing_speed_ratio()
	var impact_scale: float = WildDashCombatAbilitySystem.get_monkey_swing_impact_scale(swing_ratio)
	var context: Dictionary = {"momentum_multiplier": impact_scale, "airborne": true, "in_water": false}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, target, spec, &"fruit_collection", context)
	_canopy_attack_suppress_hold_remaining = 0.56
	if target == null or not result.applied:
		if hud != null:
			hud.set_message("SWING KICK · NO TARGET")
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	target.apply_knockback(offset.normalized(), result.knockback)
	_combat_v2_try_spill(target, 1, "MONKEY SWING KICK")
	AudioManager.play_sfx_id("hit", 0.94)
	_spawn_round2_attack_puff(target.global_position + Vector3.UP * 0.75, 0.95)
	if hud != null:
		hud.set_message("SWING KICK! · MOMENTUM %.0f%%" % (impact_scale * 100.0))
	print("MONKEY SWING KICK mode=fruit_collection ratio=%.2f impact=%.2f" % [swing_ratio, impact_scale])

func _nearest_round2_target(source: WildDashCharacterController, radius: float) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance: float = radius * radius
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var distance: float = source.global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _combat_v2_try_spill(target: WildDashCharacterController, requested: int, reason: String) -> int:
	if target == null or requested <= 0 or _get_carry(target) <= 0:
		return 0
	var id: int = target.get_instance_id()
	if float(spill_hit_cooldown_by_id.get(id, 0.0)) > 0.0:
		return 0
	var spill_count: int = mini(requested, _get_carry(target))
	_spill_racer(target, spill_count, reason)
	spill_hit_cooldown_by_id[id] = COMBAT_SPILL_COOLDOWN
	return spill_count

func _combat_v2_is_back_attack(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var target_forward: Vector3 = -target.global_transform.basis.z
	target_forward.y = 0.0
	if target_forward.length_squared() <= 0.001:
		return false
	target_forward = target_forward.normalized()
	var target_to_source: Vector3 = source.global_position - target.global_position
	target_to_source.y = 0.0
	if target_to_source.length_squared() <= 0.001:
		return false
	return target_forward.dot(target_to_source.normalized()) <= -0.34

func _player_planar_speed_ratio() -> float:
	if player == null:
		return 0.0
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	return clampf(speed / maxf(1.0, player.arena_move_speed), 0.0, 1.0)

func _set_round2_speed_bonus(scale: float, seconds: float) -> void:
	_combat_v2_speed_bonus_scale = maxf(_combat_v2_speed_bonus_scale, scale)
	_combat_v2_speed_bonus_remaining = maxf(_combat_v2_speed_bonus_remaining, seconds)

func _add_round2_vine_visual(route: WildDashCanopyVineRoute) -> void:
	if route == null or _canopy_visual_root == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.48, 0.13, 1.0)
	material.roughness = 1.0
	var previous: Vector3 = route.sample(0.0)
	for i: int in range(1, 13):
		var point: Vector3 = route.sample(float(i) / 12.0)
		var segment: MeshInstance3D = MeshInstance3D.new()
		segment.name = "%s_Segment_%02d" % [String(route.vine_id), i]
		var mesh: BoxMesh = BoxMesh.new()
		var length: float = previous.distance_to(point)
		mesh.size = Vector3(0.11, 0.11, maxf(0.05, length))
		mesh.material = material
		segment.mesh = mesh
		segment.position = previous.lerp(point, 0.5)
		segment.look_at(point, Vector3.UP)
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_canopy_visual_root.add_child(segment)
		previous = point

func _spawn_round2_attack_puff(position: Vector3, scale_factor: float) -> void:
	var puff: MeshInstance3D = MeshInstance3D.new()
	puff.name = "CombatV2AirPuff"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.38 * scale_factor
	mesh.height = 0.76 * scale_factor
	mesh.radial_segments = 6
	mesh.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.96, 1.0, 0.44)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.mesh = mesh
	puff.material_override = material
	puff.global_position = position
	add_child(puff)
	_expire_effect_node(puff, 0.22)
