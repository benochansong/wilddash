class_name WildDashRaceCombatCoreV3
extends WildDashRaceCombatCoreV2

## Round 1 / Round 3 race-impact layer.
## Keeps Combat V2 command compatibility while making item/body impacts create a
## short, readable passing window. Phase 2 AI can query this API without owning
## another damage/knockback implementation.

const BODY_CHECK_QUERY_RANGE: float = 3.45
const SHOCKWAVE_REINFORCE_RADIUS: float = 9.0
const SHOCKWAVE_INNER_EXTRA_PUSH: float = 1.05
const SHOCKWAVE_OUTER_PUSH: float = 1.65
const CONTROL_META_UNTIL: StringName = &"race_v3_control_until"
const CONTROL_META_YAW: StringName = &"race_v3_yaw_instability"
const CONTROL_META_ACCEL: StringName = &"race_v3_acceleration_multiplier"
const CONTROL_META_HANDLING: StringName = &"race_v3_handling_multiplier"
const BODY_META_NEXT: StringName = &"race_v3_body_next"

const ROUND1_ROCKET_KNOCKBACK_MULTIPLIER: float = 1.40
const ROUND1_BOMB_INNER_IMPACT_MULTIPLIER: float = 1.45
const ROUND1_BOMB_OUTER_IMPACT_MULTIPLIER: float = 1.20
const ROUND1_BOMB_KNOCKBACK_MULTIPLIER: float = 1.20
const ROUND1_TRAP_KNOCKBACK_MULTIPLIER: float = 1.20
const ROUND1_BANANA_KNOCKBACK_MULTIPLIER: float = 1.25
const ROUND1_MAX_ITEM_KNOCKBACK: float = 8.40

func _ready() -> void:
	super._ready()
	if not ItemSystem.item_used.is_connected(_on_item_used_v3):
		ItemSystem.item_used.connect(_on_item_used_v3)
	print("RACE COMBAT CORE V3 READY strong_impact=true hit_protection=0.75s phase2_api=true")

func _exit_tree() -> void:
	if ItemSystem.item_used.is_connected(_on_item_used_v3):
		ItemSystem.item_used.disconnect(_on_item_used_v3)
	super._exit_tree()

func _process(delta: float) -> void:
	_update_control_reactions(delta)

func _on_race_combat_action_resolved(action: Dictionary) -> void:
	# Preserve the exact V2 command signal for Bear/Elephant/species controllers.
	super._on_race_combat_action_resolved(action)
	_resolve_player()
	if _racer == null or _racer.finished or not RaceManager.active:
		return
	# Bear and Elephant already own dedicated V2 heavy controllers. Their existing
	# attacks remain authoritative so V3 does not double-hit the same F/Y command.
	if _racer.animal_id == &"elephant" or _racer.animal_id == &"bear":
		return
	var now_seconds: float = Time.get_ticks_msec() * 0.001
	var next_value: Variant = _racer.get_meta(BODY_META_NEXT, 0.0)
	if float(next_value) > now_seconds:
		return
	var target: WildDashCharacterController = _find_body_target(_racer, BODY_CHECK_QUERY_RANGE)
	if target == null:
		return
	var profile: WildDashRaceImpactProfile = build_body_check_profile(_racer, target)
	var applied: bool = apply_race_impact(_racer, target, &"body_check", profile, _racer.global_position)
	if applied:
		_racer.set_meta(BODY_META_NEXT, now_seconds + 1.15)
		print("BODY CHECK V3 attacker=%s victim=%s relative_speed=%.2f impact=%s knockback=%.2f" % [
			String(_racer.animal_id), String(target.animal_id),
			maxf(0.0, _racer.current_speed - target.current_speed),
			String(profile.impact_label), profile.knockback,
		])

static func apply_race_impact(
	attacker: Node,
	victim: WildDashCharacterController,
	source_id: StringName,
	profile: WildDashRaceImpactProfile,
	impact_origin: Vector3
) -> bool:
	if victim == null or profile == null or victim.finished:
		return false
	if attacker == victim:
		return false

	var round1_chain_scale: float = _round1_chain_scale_for(victim, source_id)
	var effective_profile: WildDashRaceImpactProfile = _round1_tune_item_profile(profile, source_id, round1_chain_scale)
	var shielded_before: bool = ItemSystem.has_shield(victim)
	var effective_speed_multiplier: float = minf(
		effective_profile.slow_multiplier,
		1.0 - clampf(effective_profile.speed_loss_ratio, 0.0, 0.48)
	)
	var applied: bool = ItemSystem.apply_attack(
		victim,
		attacker,
		source_id,
		effective_profile.slow_duration,
		clampf(effective_speed_multiplier, 0.52, 1.0),
		0.0
	)
	if not applied:
		return false
	# apply_attack() returns true when Bubble Shield consumes the hit. Do not add
	# V3 knockback/control after a successful block.
	if shielded_before:
		print("RACE IMPACT BLOCKED victim=%s source=%s shield=true" % [RaceManager.get_racer_label(victim), String(source_id)])
		return true

	var push_direction: Vector3 = victim.global_position - impact_origin
	push_direction.y = 0.0
	if push_direction.length_squared() <= 0.001 and attacker is Node3D:
		push_direction = victim.global_position - (attacker as Node3D).global_position
		push_direction.y = 0.0
	if push_direction.length_squared() <= 0.001:
		push_direction = -victim.global_transform.basis.z
		push_direction.y = 0.0
	var knockback_cap: float = ROUND1_MAX_ITEM_KNOCKBACK if _round1_item_source_active(source_id) else 7.2
	victim.apply_knockback(push_direction.normalized(), clampf(effective_profile.knockback, 0.0, knockback_cap))
	if effective_profile.air_pop > 0.0:
		victim.velocity.y = maxf(victim.velocity.y, effective_profile.air_pop)

	var control_duration: float = maxf(effective_profile.stagger_duration, effective_profile.slow_duration)
	if control_duration > 0.0:
		var until_seconds: float = Time.get_ticks_msec() * 0.001 + minf(control_duration, 1.5)
		victim.set_meta(CONTROL_META_UNTIL, until_seconds)
		victim.set_meta(CONTROL_META_YAW, clampf(effective_profile.yaw_instability, 0.0, 0.85))
		victim.set_meta(CONTROL_META_ACCEL, clampf(effective_profile.acceleration_multiplier, 0.60, 1.0))
		victim.set_meta(CONTROL_META_HANDLING, clampf(effective_profile.handling_multiplier, 0.72, 1.0))

	var visual: WildDashCharacterVisual = victim.get_visual()
	if visual != null:
		visual.play_action(&"Hit", clampf(maxf(0.22, effective_profile.stagger_duration), 0.22, 0.72))
	_spawn_impact_fx(victim, impact_origin, effective_profile)
	_try_camera_feedback(victim, effective_profile.camera_strength)
	_play_impact_audio(source_id, victim)
	print("RACE IMPACT attacker=%s victim=%s source=%s impact=%s speed_loss=%.2f knockback=%.2f stagger=%.2f protection=%.2f" % [
		_label_node(attacker), RaceManager.get_racer_label(victim), String(source_id),
		String(effective_profile.impact_label), effective_profile.speed_loss_ratio, effective_profile.knockback,
		effective_profile.stagger_duration, effective_profile.protection_seconds,
	])
	if _round1_item_source_active(source_id):
		var direct_hit: int = 1 if source_id == &"rocket_nut" else 0
		var area_hit: int = 1 if source_id == &"acorn_bomb" else 0
		print("ROUND1 ITEM IMPACT PROFILE item_hit=1 effect=%s direct_hit=%d area_hit=%d knockback_applied=%.2f stagger_applied=%.2f chain_protection=%.2f multi_hit=%d" % [
			String(source_id), direct_hit, area_hit, effective_profile.knockback,
			effective_profile.stagger_duration, round1_chain_scale,
			1 if round1_chain_scale < 0.999 else 0,
		])
	return true

static func _round1_chain_scale_for(victim: WildDashCharacterController, source_id: StringName) -> float:
	if not _round1_item_source_active(source_id) or victim == null:
		return 1.0
	if not ItemSystem.has_method("get_round1_chain_scale"):
		return 1.0
	return clampf(float(ItemSystem.call("get_round1_chain_scale", victim)), 0.25, 1.0)

static func _round1_item_source_active(source_id: StringName) -> bool:
	if GameManager.get_current_round_id() != &"grand_prix" or not RaceManager.active:
		return false
	return source_id in [&"rocket_nut", &"acorn_bomb", &"banana_peel", &"sticky_fruit"]

static func _round1_tune_item_profile(
	profile: WildDashRaceImpactProfile,
	source_id: StringName,
	chain_scale: float
) -> WildDashRaceImpactProfile:
	if not _round1_item_source_active(source_id):
		return profile
	var tuned: WildDashRaceImpactProfile = profile.copy_profile()
	match source_id:
		&"rocket_nut":
			tuned.impact_strength *= ROUND1_ROCKET_KNOCKBACK_MULTIPLIER
			tuned.knockback *= ROUND1_ROCKET_KNOCKBACK_MULTIPLIER
			tuned.speed_loss_ratio = minf(0.34, tuned.speed_loss_ratio + 0.04)
			tuned.slow_multiplier = minf(tuned.slow_multiplier, 1.0 - tuned.speed_loss_ratio)
			tuned.slow_duration = minf(tuned.slow_duration, 0.65)
			tuned.stagger_duration = minf(0.62, tuned.stagger_duration + 0.04)
			tuned.camera_strength = minf(0.25, tuned.camera_strength * 1.15)
		&"acorn_bomb":
			var inner: bool = tuned.impact_label == &"HEAVY"
			tuned.impact_strength *= ROUND1_BOMB_INNER_IMPACT_MULTIPLIER if inner else ROUND1_BOMB_OUTER_IMPACT_MULTIPLIER
			tuned.knockback *= ROUND1_BOMB_KNOCKBACK_MULTIPLIER
			tuned.speed_loss_ratio = clampf(tuned.speed_loss_ratio * (1.10 if inner else 1.05), 0.0, 0.45)
			tuned.slow_multiplier = minf(tuned.slow_multiplier, 1.0 - tuned.speed_loss_ratio)
			tuned.slow_duration = minf(tuned.slow_duration, 0.82 if inner else 0.68)
			tuned.air_pop *= 1.15 if inner else 1.0
			tuned.camera_strength = minf(0.28, tuned.camera_strength * 1.15)
		&"banana_peel":
			tuned.impact_strength *= 1.15
			tuned.knockback *= ROUND1_BANANA_KNOCKBACK_MULTIPLIER
			tuned.speed_loss_ratio = minf(0.40, tuned.speed_loss_ratio + 0.02)
			tuned.slow_multiplier = minf(tuned.slow_multiplier, 1.0 - tuned.speed_loss_ratio)
			tuned.slow_duration = minf(tuned.slow_duration, 0.72)
			tuned.stagger_duration = minf(tuned.stagger_duration, 0.66)
		&"sticky_fruit":
			tuned.impact_strength *= 1.10
			tuned.knockback *= ROUND1_TRAP_KNOCKBACK_MULTIPLIER
			tuned.speed_loss_ratio = minf(0.29, tuned.speed_loss_ratio + 0.03)
			tuned.slow_multiplier = minf(tuned.slow_multiplier, 1.0 - tuned.speed_loss_ratio)
			tuned.slow_duration = minf(tuned.slow_duration, 1.10)
			tuned.stagger_duration = minf(tuned.stagger_duration, 0.34)

	if chain_scale < 0.999:
		tuned.knockback *= chain_scale
		tuned.impact_strength *= lerpf(0.70, 1.0, chain_scale)
		tuned.stagger_duration *= maxf(0.35, chain_scale)
		tuned.slow_duration *= maxf(0.45, chain_scale)
		tuned.yaw_instability *= maxf(0.45, chain_scale)
		tuned.air_pop *= maxf(0.45, chain_scale)
		tuned.camera_strength *= maxf(0.55, chain_scale)
	return tuned

static func build_body_check_profile(
	attacker: WildDashCharacterController,
	victim: WildDashCharacterController
) -> WildDashRaceImpactProfile:
	var profile: WildDashRaceImpactProfile = WildDashRaceImpactProfile.new()
	if attacker == null or victim == null:
		return profile
	var attacker_mass: float = clampf(attacker.knockback_decay / 16.0, 0.78, 1.55)
	var victim_mass: float = clampf(victim.knockback_decay / 16.0, 0.78, 1.55)
	var mass_ratio: float = clampf(attacker_mass / maxf(0.55, victim_mass), 0.62, 1.75)
	var relative_speed: float = maxf(0.0, attacker.current_speed - victim.current_speed)
	var speed_ratio: float = clampf(attacker.current_speed / maxf(1.0, attacker.max_speed), 0.0, 1.35)
	var offset: Vector3 = victim.global_position - attacker.global_position
	offset.y = 0.0
	var forward: Vector3 = -attacker.global_transform.basis.z
	forward.y = 0.0
	var alignment: float = 0.0
	if offset.length_squared() > 0.001 and forward.length_squared() > 0.001:
		alignment = forward.normalized().dot(offset.normalized())
	var angle_factor: float = lerpf(0.86, 1.10, clampf((alignment + 0.20) / 1.20, 0.0, 1.0))
	var relative_factor: float = 0.92 + clampf(relative_speed / 10.0, 0.0, 0.38) + speed_ratio * 0.16
	var species_factor: float = _species_body_factor(attacker.animal_id)
	var power: float = clampf(mass_ratio * relative_factor * angle_factor * species_factor, 0.72, 1.75)

	profile.impact_strength = power
	profile.knockback = clampf(3.0 + power * 2.15, 3.2, 6.75)
	profile.speed_loss_ratio = clampf(0.12 + power * 0.085, 0.14, 0.30)
	profile.slow_multiplier = 1.0 - profile.speed_loss_ratio
	profile.slow_duration = clampf(0.28 + power * 0.15, 0.36, 0.58)
	profile.stagger_duration = clampf(0.22 + power * 0.11, 0.26, 0.46)
	profile.yaw_instability = clampf(0.08 + power * 0.08, 0.10, 0.24)
	profile.camera_strength = clampf(0.05 + power * 0.045, 0.07, 0.14)
	profile.hitstop_seconds = clampf(0.025 + power * 0.010, 0.028, 0.045)
	profile.protection_seconds = 0.62
	profile.impact_label = &"HEAVY" if power >= 1.28 else (&"STRONG" if power >= 1.0 else &"NORMAL")
	return profile

static func get_nearby_racers(
	source: WildDashCharacterController,
	radius: float
) -> Array[WildDashCharacterController]:
	var result: Array[WildDashCharacterController] = []
	if source == null:
		return result
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or racer == source or racer.finished:
			continue
		if source.global_position.distance_to(racer.global_position) <= radius:
			result.append(racer)
	return result

static func get_attackable_racers(
	source: WildDashCharacterController,
	radius: float = 36.0
) -> Array[WildDashCharacterController]:
	var result: Array[WildDashCharacterController] = []
	for racer: WildDashCharacterController in get_nearby_racers(source, radius):
		if not get_recent_hit_protection(racer):
			result.append(racer)
	return result

static func can_body_check_target(
	attacker: WildDashCharacterController,
	victim: WildDashCharacterController,
	max_distance: float = BODY_CHECK_QUERY_RANGE
) -> bool:
	if attacker == null or victim == null or attacker == victim or victim.finished:
		return false
	var offset: Vector3 = victim.global_position - attacker.global_position
	if absf(offset.y) > 1.9:
		return false
	offset.y = 0.0
	return offset.length() <= max_distance and offset.length() > 0.05

static func get_recent_hit_protection(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return false
	return ItemSystem.has_effect(racer, &"slow") or ItemSystem.has_effect(racer, &"spin")

static func can_use_race_item(racer: WildDashCharacterController) -> bool:
	return racer != null and not racer.finished and racer.get_held_item() != &""

static func get_race_item_target(
	racer: WildDashCharacterController,
	max_distance: float = 52.0
) -> WildDashCharacterController:
	if racer == null:
		return null
	return ItemSystem.find_target_ahead(racer, max_distance) as WildDashCharacterController

func _on_item_used_v3(character: Node, item_id: StringName) -> void:
	if item_id != ItemSystem.SHOCKWAVE or not character is WildDashCharacterController:
		return
	var source: WildDashCharacterController = character as WildDashCharacterController
	# Base ItemSystem resolves the inner 7.5 m blast. V3 adds a small force boost
	# inside and extends the readable escape ring to 9 m without another stagger.
	for racer: WildDashCharacterController in get_nearby_racers(source, SHOCKWAVE_REINFORCE_RADIUS):
		var distance: float = source.global_position.distance_to(racer.global_position)
		var direction: Vector3 = racer.global_position - source.global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		var extra_push: float = SHOCKWAVE_INNER_EXTRA_PUSH if distance <= 7.5 else SHOCKWAVE_OUTER_PUSH
		racer.apply_knockback(direction.normalized(), extra_push)
		racer.current_speed *= 0.95 if distance <= 7.5 else 0.92
	_spawn_shockwave_ring(source.global_position)
	print("SHOCKWAVE V3 REINFORCE radius=%.1f inner_extra=%.2f outer_push=%.2f" % [
		SHOCKWAVE_REINFORCE_RADIUS, SHOCKWAVE_INNER_EXTRA_PUSH, SHOCKWAVE_OUTER_PUSH,
	])

func _update_control_reactions(delta: float) -> void:
	if not RaceManager.active:
		return
	var now_seconds: float = Time.get_ticks_msec() * 0.001
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or racer.finished or not racer.has_meta(CONTROL_META_UNTIL):
			continue
		var until_value: Variant = racer.get_meta(CONTROL_META_UNTIL, 0.0)
		if float(until_value) <= now_seconds:
			racer.remove_meta(CONTROL_META_UNTIL)
			racer.remove_meta(CONTROL_META_YAW)
			racer.remove_meta(CONTROL_META_ACCEL)
			racer.remove_meta(CONTROL_META_HANDLING)
			continue
		var yaw_value: Variant = racer.get_meta(CONTROL_META_YAW, 0.0)
		var handling_value: Variant = racer.get_meta(CONTROL_META_HANDLING, 1.0)
		var yaw_strength: float = float(yaw_value) + (1.0 - float(handling_value)) * 0.18
		if yaw_strength > 0.001:
			var phase: float = now_seconds * 20.0 + float(racer.get_instance_id() % 11)
			racer.rotation.y += sin(phase) * yaw_strength * delta
		var accel_value: Variant = racer.get_meta(CONTROL_META_ACCEL, 1.0)
		if float(accel_value) < 0.99:
			# Effective acceleration loss without mutating canonical/water-adjusted stats.
			var recovery_drag: float = (1.0 - float(accel_value)) * racer.acceleration * delta * 0.35
			racer.current_speed = maxf(0.0, racer.current_speed - recovery_drag)

static func _find_body_target(
	attacker: WildDashCharacterController,
	max_distance: float
) -> WildDashCharacterController:
	if attacker == null:
		return null
	var best: WildDashCharacterController = null
	var best_score: float = INF
	var forward: Vector3 = -attacker.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	for racer: WildDashCharacterController in get_nearby_racers(attacker, max_distance):
		var offset: Vector3 = racer.global_position - attacker.global_position
		if absf(offset.y) > 1.9:
			continue
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05:
			continue
		var alignment: float = forward.dot(offset / distance)
		if alignment < -0.25:
			continue
		var score: float = distance - maxf(0.0, alignment) * 0.45
		if score < best_score:
			best_score = score
			best = racer
	return best

static func _species_body_factor(animal_id: StringName) -> float:
	match animal_id:
		&"elephant": return 1.30
		&"boar": return 1.22
		&"bear": return 1.18
		&"wolf": return 1.08
		&"dog": return 1.00
		&"crocodile": return 1.08
		&"raccoon": return 0.94
		&"monkey": return 0.94
		&"deer": return 0.92
		&"fox": return 0.86
		&"rabbit": return 0.82
		&"cat": return 0.84
		_: return 1.0

static func _spawn_impact_fx(
	victim: WildDashCharacterController,
	impact_origin: Vector3,
	profile: WildDashRaceImpactProfile
) -> void:
	if victim == null or victim.get_parent() == null:
		return
	var root: Node3D = Node3D.new()
	root.name = "RaceImpactV3FX"
	victim.get_parent().add_child(root)
	root.global_position = victim.global_position + Vector3.UP * 0.65
	var water: bool = victim.has_meta(&"wild_tide_terrain")
	var color: Color = Color(0.10, 0.82, 1.0) if water else Color(1.0, 0.50, 0.08)
	var flash: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.75
	flash.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6 + profile.impact_strength * 0.65
	material.roughness = 0.35
	flash.material_override = material
	root.add_child(flash)
	var tween: Tween = root.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * (1.5 + profile.impact_strength), 0.16)
	tween.tween_callback(Callable(root, "queue_free"))

static func _spawn_shockwave_ring(position: Vector3) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "RaceShockwaveV3OuterRing"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.045
	ring.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.12, 0.78)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.48, 0.04)
	material.emission_energy_multiplier = 1.25
	ring.material_override = material
	tree.current_scene.add_child(ring)
	ring.global_position = position + Vector3.UP * 0.18
	ring.scale = Vector3(0.4, 1.0, 0.4)
	var tween: Tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(9.0, 1.0, 9.0), 0.30)
	tween.tween_callback(Callable(ring, "queue_free"))

static func _try_camera_feedback(victim: WildDashCharacterController, strength: float) -> void:
	if victim == null or not victim.is_player or strength <= 0.0:
		return
	var viewport: Viewport = victim.get_viewport()
	if viewport == null:
		return
	var camera: Camera3D = viewport.get_camera_3d()
	if camera != null and camera.has_method("add_trauma"):
		camera.call("add_trauma", clampf(strength, 0.0, 0.28))

static func _play_impact_audio(source_id: StringName, victim: WildDashCharacterController) -> void:
	var volume: float = 0.82
	if source_id == &"acorn_bomb" or source_id == &"pack_buster":
		volume = 1.0
	elif source_id == &"body_check":
		volume = 0.92
	AudioManager.play_sfx_id("hit", volume)
	if victim != null and victim.has_meta(&"wild_tide_terrain"):
		AudioManager.play_sfx_id("splash", 0.48)

static func _label_node(node: Node) -> String:
	if node == null:
		return "WORLD"
	if node is Node3D and RaceManager.racers.has(node):
		return RaceManager.get_racer_label(node as Node3D)
	return node.name