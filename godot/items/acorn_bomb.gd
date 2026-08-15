class_name WildDashAcornBomb
extends Node3D

## Pack Buster Bomb V2.
##
## This is a committed ballistic throw, not a homing missile. Target selection is
## handled by LongBombItemSupport using race rank. The bomb samples the rival once,
## predicts a short lead point, then follows a fast cinematic parabola with an
## explicit apex. If no racer is available it still throws to a fallback point;
## there is no slow straight-flight mode anymore.

const LIFE_SECONDS: float = 3.0
const HIT_RADIUS: float = 1.55
const EXPLOSION_RADIUS: float = 5.5
const MIN_FLIGHT_SECONDS: float = 0.78
const MAX_FLIGHT_SECONDS: float = 1.35
const MIN_APEX_HEIGHT: float = 5.5
const MAX_APEX_HEIGHT: float = 15.0
const TARGET_LEAD_FACTOR: float = 0.58
const TARGET_GROUND_AHEAD: float = 2.0
const MIN_DYNAMIC_GRAVITY: float = 28.0
const MAX_DYNAMIC_GRAVITY: float = 88.0

var owner_racer: WildDashCharacterController
var target_racer: WildDashCharacterController
var velocity: Vector3 = Vector3.ZERO
var explosion_environment: StringName = &"land"
var _gravity: float = 52.0
var _life: float = 0.0
var _exploded: bool = false
var _visual: Node3D
var _planned_target_point: Vector3 = Vector3.ZERO
var _planned_flight_seconds: float = 1.0
var _planned_apex_height: float = 7.0

func configure(
	racer: WildDashCharacterController,
	target: Node3D = null,
	fallback_target: Vector3 = Vector3.ZERO
) -> void:
	owner_racer = racer
	target_racer = target as WildDashCharacterController
	if racer == null:
		return

	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var launch_origin: Vector3 = racer.global_position + forward * 1.8 + Vector3.UP * 1.25

	var target_point: Vector3 = fallback_target
	var target_label: String = "AHEAD PACK"
	var target_rank: int = 0
	if target_racer != null and is_instance_valid(target_racer):
		target_label = RaceManager.get_racer_label(target_racer)
		target_rank = RaceManager.get_rank(target_racer)
		target_point = _predict_target_ground_point(target_racer, launch_origin)
	elif target_point == Vector3.ZERO:
		target_point = launch_origin + forward * 24.0 + Vector3.DOWN * 1.0

	_planned_target_point = target_point
	var planar_distance: float = Vector2(
		target_point.x - launch_origin.x,
		target_point.z - launch_origin.z
	).length()
	_planned_flight_seconds = _flight_seconds_for_distance(planar_distance)
	_planned_apex_height = _apex_height_for_distance(planar_distance)
	velocity = _calculate_ballistic_velocity(
		launch_origin,
		target_point,
		_planned_apex_height,
		_planned_flight_seconds
	)

	print("PACK BUSTER LOCK source=%s rank=%d/%d target=%s target_rank=%d distance=%.1f flight=%.2f apex=%.1f gravity=%.1f" % [
		RaceManager.get_racer_label(racer),
		RaceManager.get_rank(racer),
		RaceManager.racers.size(),
		target_label,
		target_rank,
		planar_distance,
		_planned_flight_seconds,
		_planned_apex_height,
		_gravity,
	])

func set_explosion_environment(environment_id: StringName) -> void:
	explosion_environment = environment_id

func _ready() -> void:
	_build_visual()

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_life += delta
	if _life >= LIFE_SECONDS:
		_explode()
		return

	var previous: Vector3 = global_position
	velocity.y -= _gravity * delta
	var next_position: Vector3 = previous + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous, next_position, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if owner_racer != null and is_instance_valid(owner_racer):
		query.exclude = [owner_racer.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_value: Variant = hit.get("position", next_position)
		if hit_value is Vector3:
			global_position = hit_value
		else:
			global_position = next_position
		_explode()
		return

	global_position = next_position
	if _visual != null:
		_visual.rotate_x(delta * 10.0)
		_visual.rotate_z(delta * 7.0)

	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position + Vector3.UP * 0.7) <= HIT_RADIUS:
			_explode()
			return

func _predict_target_ground_point(target: WildDashCharacterController, launch_origin: Vector3) -> Vector3:
	var raw_point: Vector3 = target.global_position + Vector3.UP * 0.25
	var initial_distance: float = Vector2(
		raw_point.x - launch_origin.x,
		raw_point.z - launch_origin.z
	).length()
	var lead_seconds: float = _flight_seconds_for_distance(initial_distance)
	var target_velocity: Vector3 = Vector3(target.velocity.x, 0.0, target.velocity.z)
	raw_point += target_velocity * lead_seconds * TARGET_LEAD_FACTOR

	var ahead: Vector3 = target_velocity
	if ahead.length_squared() <= 0.04:
		ahead = -target.global_transform.basis.z
		ahead.y = 0.0
	if ahead.length_squared() > 0.001:
		ahead = ahead.normalized()
		raw_point += ahead * TARGET_GROUND_AHEAD
	return raw_point

func _flight_seconds_for_distance(distance: float) -> float:
	var ratio: float = clampf((distance - 15.0) / 95.0, 0.0, 1.0)
	return lerpf(MIN_FLIGHT_SECONDS, MAX_FLIGHT_SECONDS, ratio)

func _apex_height_for_distance(distance: float) -> float:
	var ratio: float = clampf((distance - 20.0) / 80.0, 0.0, 1.0)
	return lerpf(MIN_APEX_HEIGHT, MAX_APEX_HEIGHT, ratio)

func _calculate_ballistic_velocity(
	origin: Vector3,
	target_point: Vector3,
	apex_height: float,
	flight_seconds: float
) -> Vector3:
	var apex_y: float = maxf(origin.y, target_point.y) + maxf(1.0, apex_height)
	var rise: float = maxf(0.25, apex_y - origin.y)
	var fall: float = maxf(0.25, apex_y - target_point.y)
	var rise_root: float = sqrt(rise)
	var fall_root: float = sqrt(fall)
	var root_sum: float = maxf(0.001, rise_root + fall_root)
	var time_up: float = maxf(0.05, flight_seconds * rise_root / root_sum)
	_gravity = clampf(2.0 * rise / (time_up * time_up), MIN_DYNAMIC_GRAVITY, MAX_DYNAMIC_GRAVITY)

	# If gravity was clamped, recompute the true rise/fall times so the horizontal
	# component still lands close to the authored target point.
	time_up = sqrt(2.0 * rise / _gravity)
	var time_down: float = sqrt(2.0 * fall / _gravity)
	var actual_flight: float = maxf(0.10, time_up + time_down)
	_planned_flight_seconds = actual_flight

	var delta: Vector3 = target_point - origin
	var result: Vector3 = Vector3(delta.x / actual_flight, _gravity * time_up, delta.z / actual_flight)
	return result

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_resolve_explosion_environment()
	var water_impact: bool = explosion_environment == &"water"
	var hits: int = 0
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer == owner_racer or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		if global_position.distance_to(racer.global_position) <= EXPLOSION_RADIUS:
			var slow_multiplier: float = 0.78 if water_impact else 0.74
			var knockback: float = 4.6 if water_impact else 4.3
			# Use the bomb node as attack source so knockback radiates from the actual
			# impact point instead of from the thrower's current position.
			if ItemSystem.apply_attack(racer, self, &"acorn_bomb", 1.0, slow_multiplier, knockback):
				hits += 1

	_spawn_explosion_fx()
	AudioManager.play_sfx_id("bomb_explosion", 1.0)
	if water_impact:
		AudioManager.play_sfx_id("splash", 0.92)
	else:
		AudioManager.play_sfx_id("hit", 0.82)
	_try_camera_shake()
	print("PACK BUSTER EXPLOSION position=%s hits=%d radius=%.1f environment=%s radial=true" % [
		str(global_position), hits, EXPLOSION_RADIUS, String(explosion_environment),
	])
	queue_free()

func _resolve_explosion_environment() -> void:
	if explosion_environment == &"water":
		return
	var worlds: Array[Node] = get_tree().get_nodes_in_group("wild_tide_world")
	for node: Node in worlds:
		if node == null or not node.has_method("is_position_water"):
			continue
		var water_value: Variant = node.call("is_position_water", global_position)
		if bool(water_value):
			explosion_environment = &"water"
			return
	explosion_environment = &"land"

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 1.02
	sphere.radial_segments = 12
	sphere.rings = 7
	body.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.16, 0.025)
	material.roughness = 0.62
	material.emission_enabled = true
	material.emission = Color(1.0, 0.20, 0.015) * 0.85
	body.material_override = material
	_visual.add_child(body)

	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = 0.20
	cap_mesh.bottom_radius = 0.36
	cap_mesh.height = 0.26
	cap.mesh = cap_mesh
	cap.position.y = 0.57
	cap.material_override = material
	_visual.add_child(cap)

func _spawn_explosion_fx() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var fx_root: Node3D = Node3D.new()
	fx_root.name = "PackBusterExplosionFX"
	parent_node.add_child(fx_root)
	fx_root.global_position = global_position + Vector3.UP * 0.28

	var water_impact: bool = explosion_environment == &"water"
	var flash_color: Color = Color(0.20, 0.86, 1.0) if water_impact else Color(1.0, 0.42, 0.035)
	var flash: MeshInstance3D = MeshInstance3D.new()
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.72
	flash_mesh.height = 1.35
	flash.mesh = flash_mesh
	flash.scale = Vector3.ONE * 0.25
	flash.material_override = _make_emissive_material(flash_color, 2.8)
	fx_root.add_child(flash)

	var shock: MeshInstance3D = MeshInstance3D.new()
	var shock_mesh: CylinderMesh = CylinderMesh.new()
	shock_mesh.top_radius = 1.0
	shock_mesh.bottom_radius = 1.0
	shock_mesh.height = 0.06
	shock.mesh = shock_mesh
	shock.position.y = -0.18
	shock.scale = Vector3(0.35, 1.0, 0.35)
	shock.material_override = _make_emissive_material(flash_color.lightened(0.18), 1.8)
	fx_root.add_child(shock)

	var puff_count: int = 8 if water_impact else 5
	for i: int in range(puff_count):
		var puff: MeshInstance3D = MeshInstance3D.new()
		var puff_mesh: SphereMesh = SphereMesh.new()
		puff_mesh.radius = 0.38 + float(i % 2) * 0.12
		puff_mesh.height = puff_mesh.radius * 1.7
		puff.mesh = puff_mesh
		var angle: float = float(i) / float(puff_count) * TAU
		var radial_distance: float = 1.05 if water_impact else 0.75
		puff.position = Vector3(cos(angle) * radial_distance, 0.15 + float(i % 3) * 0.18, sin(angle) * radial_distance)
		var puff_color: Color = Color(0.16, 0.58, 0.76) if water_impact else Color(0.32, 0.24, 0.18)
		puff.material_override = _make_emissive_material(puff_color, 0.42 if water_impact else 0.35)
		fx_root.add_child(puff)

	var tween: Tween = fx_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * (4.0 if water_impact else 3.3), 0.22)
	tween.tween_property(shock, "scale", Vector3(6.8, 1.0, 6.8) if water_impact else Vector3(5.8, 1.0, 5.8), 0.34)
	for child: Node in fx_root.get_children():
		if child == flash or child == shock or not (child is MeshInstance3D):
			continue
		var puff_node: MeshInstance3D = child as MeshInstance3D
		puff_node.scale = Vector3.ONE * 0.65
		tween.tween_property(puff_node, "scale", Vector3.ONE * (2.0 if water_impact else 1.65), 0.38)
	tween.chain().tween_callback(Callable(fx_root, "queue_free"))

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = color * energy
	return material

func _try_camera_shake() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.20)
	elif camera.has_method("shake"):
		camera.call("shake", 0.16)