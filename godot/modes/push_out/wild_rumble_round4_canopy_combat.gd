extends "res://modes/push_out/wild_rumble_round4_combat_v2.gd"

## Round 4 Combat V2 phase 2. Monkey gains limited canopy routes and agile
## characters use typed Basic/Heavy/Aerial profiles while ArenaCombatCore remains
## authoritative for real Stagger, Break, Back Attack and survival balance.

const ROUND4_AGILE_PROFILE_IDS: Array[StringName] = [&"monkey", &"rabbit", &"deer", &"cat", &"fox"]
const ROUND4_CAT_ESCAPE_SCALE: float = 1.15
const ROUND4_CAT_ESCAPE_SECONDS: float = 0.60
const ROUND4_FOX_ESCAPE_SCALE: float = 1.12
const ROUND4_FOX_ESCAPE_SECONDS: float = 0.50
const ROUND4_MONKEY_FLOW_SCALE: float = 1.10
const ROUND4_MONKEY_FLOW_SECONDS: float = 0.50

var _round4_canopy: WildDashCanopyTraversalSystem = WildDashCanopyTraversalSystem.new()
var _round4_canopy_routes: Array[WildDashCanopyVineRoute] = []
var _round4_canopy_visuals: Array[Node3D] = []
var _round4_canopy_root: Node3D
var _round4_canopy_allowed_count: int = 0
var _round4_canopy_attack_suppress_hold_remaining: float = 0.0
var _round4_profile_speed_bonus_remaining: float = 0.0
var _round4_profile_speed_bonus_scale: float = 1.0
var _round4_rabbit_chain_remaining: float = 0.0
var _round4_rabbit_chain_count: int = 0

func _ready() -> void:
	await super()
	if player != null and player.animal_id == &"monkey":
		_build_round4_canopy_network()
	print("WILD RUMBLE CANOPY COMBAT READY monkey_vines=%d agile_profiles=true final_duel_vines_off=true" % _round4_canopy_routes.size())

func _physics_process(delta: float) -> void:
	super(delta)
	_round4_canopy_attack_suppress_hold_remaining = maxf(0.0, _round4_canopy_attack_suppress_hold_remaining - delta)
	_round4_profile_speed_bonus_remaining = maxf(0.0, _round4_profile_speed_bonus_remaining - delta)
	_round4_rabbit_chain_remaining = maxf(0.0, _round4_rabbit_chain_remaining - delta)
	if _round4_rabbit_chain_remaining <= 0.0:
		_round4_rabbit_chain_count = 0
	if mode_finished or not GameManager.round_active or player == null:
		return
	if player.animal_id == &"monkey":
		_update_round4_vine_availability()
		_update_round4_monkey_canopy(delta)

func _round4_objective_speed_multiplier(racer: WildDashCharacterController) -> float:
	var multiplier: float = super(racer)
	if racer != null and racer == player and _round4_profile_speed_bonus_remaining > 0.0:
		multiplier *= _round4_profile_speed_bonus_scale
	return multiplier

func _on_phase1_combat_action(action: Dictionary) -> void:
	if player == null:
		return
	if not ROUND4_AGILE_PROFILE_IDS.has(player.animal_id):
		super(action)
		return
	if _round4_brace_consumed_press or _round4_brace_signal_suppress_remaining > 0.0:
		return
	var kind: StringName = StringName(action.get("kind", &"tap"))
	if player.animal_id == &"monkey" and _round4_canopy.is_swinging():
		if kind == &"hold" and _round4_canopy_attack_suppress_hold_remaining > 0.0:
			return
		if kind == &"tap":
			_perform_monkey_swing_kick_round4()
		return
	_perform_round4_profile_attack(kind)

func _perform_round4_profile_attack(kind: StringName) -> void:
	if player == null or _combat_core == null or not _is_combatant_active(player):
		return
	var heavy: bool = kind == &"hold"
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(player.animal_id) if heavy else WildDashCombatAbilitySystem.get_basic_attack(player.animal_id)
	if spec == null:
		return
	var core_kind: StringName = &"hold" if heavy else &"tap"
	if not _combat_core.try_begin_attack(player, core_kind):
		return
	var momentum_ratio: float = _round4_player_planar_speed_ratio()
	var momentum_multiplier: float = WildDashCombatAbilitySystem.get_momentum_effect_multiplier(spec, momentum_ratio)
	var context: Dictionary = {"in_water": false, "momentum_multiplier": momentum_multiplier}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, null, spec, &"push_out", context)
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	if preview.mobility_impulse > 0.01:
		player.apply_knockback(forward, preview.mobility_impulse)
	var target: WildDashCharacterController = _combat_v2_round4_front_target(spec.range, spec.arc_dot)
	if target == null:
		if hud != null:
			hud.set_message("%s · NO TARGET" % spec.display_name)
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var result: Dictionary = _combat_core.apply_hit(player, target, offset, core_kind, 0)
	if not bool(result.get("applied", false)):
		return
	_record_phase2_hit_credit(player, target)
	var back_attack: bool = bool(result.get("back_attack", false))
	if player.animal_id == &"cat" and back_attack:
		_combat_core.add_environment_stagger(target, 6.0)
		_set_round4_profile_speed_bonus(ROUND4_CAT_ESCAPE_SCALE, ROUND4_CAT_ESCAPE_SECONDS)
		if hud != null:
			hud.set_message("AMBUSH! · STAGGER %.0f/100" % _combat_core.get_stagger(target))
	elif player.animal_id == &"fox":
		_set_round4_profile_speed_bonus(ROUND4_FOX_ESCAPE_SCALE, ROUND4_FOX_ESCAPE_SECONDS)
		if hud != null:
			hud.set_message("%s! · HIT & RUN" % spec.display_name)
	elif hud != null:
		hud.set_message("%s! · STAGGER %.0f/100" % [spec.display_name, _combat_core.get_stagger(target)])
	if player.animal_id == &"deer" and momentum_multiplier > 1.0:
		target.apply_knockback(offset.normalized(), (momentum_multiplier - 1.0) * 2.2)
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.09 if not heavy else 0.12)
	print("COMBAT V2 ROUND4 PROFILE animal=%s ability=%s heavy=%s momentum=%.2f back=%s" % [
		String(player.animal_id), String(spec.ability_id), str(heavy), momentum_multiplier, str(back_attack),
	])

func _update_round4_player_stomp() -> void:
	if player == null or not ROUND4_AGILE_PROFILE_IDS.has(player.animal_id):
		super()
		return
	if _combat_core == null or not is_instance_valid(player):
		return
	if player.is_on_floor() or player.velocity.y > ROUND4_STOMP_MIN_FALL_SPEED:
		return
	if not _combat_core.can_attack(player):
		return
	var target: WildDashCharacterController = _round4_profile_stomp_target()
	if target == null:
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(player.animal_id)
	if spec == null:
		return
	var height_delta: float = player.global_position.y - target.global_position.y
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(player, player.velocity.y, height_delta, horizontal_speed)
	var context: Dictionary = {"airborne": true, "momentum_multiplier": aerial_scale, "in_water": false}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, target, spec, &"push_out", context)
	if not preview.applied or not _combat_core.try_begin_attack(player, &"stomp"):
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = -player.global_transform.basis.z
	var result: Dictionary = _combat_core.apply_hit(player, target, offset, &"stomp", 0)
	if not bool(result.get("applied", false)):
		return
	_record_phase2_hit_credit(player, target)
	player.velocity.y = maxf(player.velocity.y, player.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(player.animal_id))
	var extra_stagger: float = 0.0
	if player.animal_id == &"rabbit":
		_round4_rabbit_chain_count = mini(3, _round4_rabbit_chain_count + 1) if _round4_rabbit_chain_remaining > 0.0 else 1
		_round4_rabbit_chain_remaining = WildDashAerialCombatSystem.get_chain_window(&"rabbit")
		extra_stagger = WildDashAerialCombatSystem.get_chain_stagger_bonus(_round4_rabbit_chain_count)
		if extra_stagger > 0.0:
			_combat_core.add_environment_stagger(target, extra_stagger)
		if hud != null:
			hud.set_message("CHAIN STOMP x%d! · STAGGER %.0f/100" % [_round4_rabbit_chain_count, _combat_core.get_stagger(target)])
	elif player.animal_id == &"monkey":
		_set_round4_profile_speed_bonus(ROUND4_MONKEY_FLOW_SCALE, ROUND4_MONKEY_FLOW_SECONDS)
		if hud != null:
			hud.set_message("CANOPY STOMP! · STAGGER %.0f/100" % _combat_core.get_stagger(target))
	elif player.animal_id == &"deer":
		target.apply_knockback(offset.normalized(), maxf(0.0, aerial_scale - 0.95) * 1.4)
		if hud != null:
			hud.set_message("HOOF DROP! · MOMENTUM %.0f%%" % (aerial_scale * 100.0))
	elif player.animal_id == &"cat" and bool(result.get("back_attack", false)):
		_combat_core.add_environment_stagger(target, 4.0)
		_set_round4_profile_speed_bonus(ROUND4_CAT_ESCAPE_SCALE, ROUND4_CAT_ESCAPE_SECONDS)
		if hud != null:
			hud.set_message("AERIAL AMBUSH! · STAGGER %.0f/100" % _combat_core.get_stagger(target))
	elif hud != null:
		hud.set_message("%s! · STAGGER %.0f/100" % [spec.display_name, _combat_core.get_stagger(target)])
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.10)
	_spawn_round4_canopy_puff(target.global_position + Vector3.UP * 0.55, 0.80)

func _round4_profile_stomp_target() -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance: float = INF
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		if float(_spawn_protection.get(target.get_instance_id(), 0.0)) > 0.0:
			continue
		var height_delta: float = player.global_position.y - target.global_position.y
		if height_delta < ROUND4_STOMP_MIN_HEIGHT or height_delta > ROUND4_STOMP_MAX_HEIGHT:
			continue
		var planar: Vector2 = Vector2(target.global_position.x - player.global_position.x, target.global_position.z - player.global_position.z)
		var distance: float = planar.length()
		if distance > ROUND4_STOMP_RADIUS:
			continue
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _build_round4_canopy_network() -> void:
	_round4_canopy_root = Node3D.new()
	_round4_canopy_root.name = "Round4MonkeyCanopy"
	add_child(_round4_canopy_root)
	var starts: Array[Vector3] = [
		Vector3(-8.0, 4.6, -4.0),
		Vector3(8.0, 4.6, -4.0),
		Vector3(-6.2, 4.4, 6.2),
	]
	var ends: Array[Vector3] = [
		Vector3(0.0, 5.3, 4.2),
		Vector3(0.0, 5.3, 4.2),
		Vector3(6.2, 4.4, 6.2),
	]
	for i: int in range(starts.size()):
		var route: WildDashCanopyVineRoute = WildDashCanopyVineRoute.new().configure(
			StringName("titan_vine_%02d" % i), starts[i], ends[i], 1.9 + float(i) * 0.15, 10.2, 4.2
		)
		_round4_canopy_routes.append(route)
		var visual_root: Node3D = _add_round4_vine_visual(route)
		_round4_canopy_visuals.append(visual_root)
	_round4_canopy.set_routes(_round4_canopy_routes)
	_round4_canopy_allowed_count = _round4_canopy_routes.size()

func _update_round4_vine_availability() -> void:
	if _round4_canopy_routes.is_empty():
		return
	var alive: int = _round4_alive_count()
	var allowed: int = 3
	if alive <= 2:
		allowed = 0
	elif alive <= 3:
		allowed = 1
	elif alive <= 5:
		allowed = 2
	allowed = mini(allowed, _round4_canopy_routes.size())
	if allowed == _round4_canopy_allowed_count:
		return
	var active_id: StringName = _round4_canopy.get_active_vine_id()
	for i: int in range(_round4_canopy_routes.size()):
		var enabled: bool = i < allowed
		_round4_canopy_routes[i].enabled = enabled
		if i < _round4_canopy_visuals.size() and _round4_canopy_visuals[i] != null:
			_round4_canopy_visuals[i].visible = enabled
	if active_id != &"":
		var active_still_enabled: bool = false
		for i: int in range(allowed):
			if _round4_canopy_routes[i].vine_id == active_id:
				active_still_enabled = true
				break
		if not active_still_enabled:
			_round4_canopy.clear_active_vine()
			player.velocity.y = maxf(player.velocity.y, 2.0)
	_round4_canopy_allowed_count = allowed
	print("MONKEY CANOPY R4 availability alive=%d vines=%d" % [alive, allowed])

func _update_round4_monkey_canopy(delta: float) -> void:
	if player == null or player.animal_id != &"monkey" or _round4_canopy_routes.is_empty():
		return
	if _round4_canopy.is_swinging():
		if InputManager.consume_jump():
			player.velocity = _round4_canopy.release_vine(player, true)
			if hud != null:
				hud.set_message("VINE RELEASE · AERIAL ATTACK READY")
			return
		var move: Vector2 = InputManager.get_move_vector()
		var reached_end: bool = _round4_canopy.update_swing(player, delta, move.x)
		if reached_end:
			player.velocity = _round4_canopy.release_vine(player, false) + Vector3.UP * 1.0
		return
	if _round4_canopy_allowed_count > 0 and InputManager.consume_skill():
		var nearest: WildDashCanopyVineRoute = _round4_canopy.find_nearest_vine(player.global_position, 3.8)
		if nearest != null and _round4_canopy.grab_vine(player, nearest):
			if hud != null:
				hud.set_message("VINE GRAB! · F SWING KICK")

func _perform_monkey_swing_kick_round4() -> void:
	if player == null or _combat_core == null or not _round4_canopy.is_swinging():
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_mobility_attack(&"monkey")
	if spec == null or not _combat_core.try_begin_attack(player, &"stomp"):
		return
	var target: WildDashCharacterController = _nearest_round4_canopy_target(spec.range)
	var speed_ratio: float = _round4_canopy.get_swing_speed_ratio()
	var impact_scale: float = WildDashCombatAbilitySystem.get_monkey_swing_impact_scale(speed_ratio)
	var context: Dictionary = {"airborne": true, "in_water": false, "momentum_multiplier": impact_scale}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, target, spec, &"push_out", context)
	_round4_canopy_attack_suppress_hold_remaining = 0.56
	if target == null or not preview.applied:
		if hud != null:
			hud.set_message("SWING KICK · NO TARGET")
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var result: Dictionary = _combat_core.apply_hit(player, target, offset, &"stomp", 0)
	if not bool(result.get("applied", false)):
		return
	_combat_core.add_environment_stagger(target, preview.stagger * 0.18)
	target.apply_knockback(offset.normalized(), preview.knockback * 0.16)
	_record_phase2_hit_credit(player, target)
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.11)
	_spawn_round4_canopy_puff(target.global_position + Vector3.UP * 0.75, 1.0)
	if hud != null:
		hud.set_message("SWING KICK! · MOMENTUM %.0f%% · STAGGER %.0f/100" % [impact_scale * 100.0, _combat_core.get_stagger(target)])
	print("MONKEY SWING KICK mode=push_out ratio=%.2f impact=%.2f" % [speed_ratio, impact_scale])

func _nearest_round4_canopy_target(radius: float) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance: float = radius * radius
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var distance: float = player.global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _round4_player_planar_speed_ratio() -> float:
	if player == null:
		return 0.0
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	return clampf(speed / maxf(1.0, player.arena_move_speed), 0.0, 1.0)

func _set_round4_profile_speed_bonus(scale: float, seconds: float) -> void:
	_round4_profile_speed_bonus_scale = maxf(_round4_profile_speed_bonus_scale, scale)
	_round4_profile_speed_bonus_remaining = maxf(_round4_profile_speed_bonus_remaining, seconds)

func _add_round4_vine_visual(route: WildDashCanopyVineRoute) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "VineVisual_%s" % String(route.vine_id)
	_round4_canopy_root.add_child(root)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.37, 0.58, 0.17, 1.0)
	material.roughness = 1.0
	var previous: Vector3 = route.sample(0.0)
	for i: int in range(1, 13):
		var point: Vector3 = route.sample(float(i) / 12.0)
		var segment: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.10, 0.10, maxf(0.05, previous.distance_to(point)))
		mesh.material = material
		segment.mesh = mesh
		segment.position = previous.lerp(point, 0.5)
		segment.look_at(point, Vector3.UP)
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(segment)
		previous = point
	return root

func _spawn_round4_canopy_puff(position: Vector3, scale_factor: float) -> void:
	var puff: MeshInstance3D = MeshInstance3D.new()
	puff.name = "CanopyImpactPuff"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.40 * scale_factor
	mesh.height = 0.80 * scale_factor
	mesh.radial_segments = 6
	mesh.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.97, 1.0, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.mesh = mesh
	puff.material_override = material
	puff.global_position = position
	add_child(puff)
	_expire_round4_effect_node(puff, 0.22)
