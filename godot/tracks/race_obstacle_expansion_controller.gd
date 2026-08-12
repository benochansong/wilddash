class_name WildDashRaceObstacleExpansionController
extends Node3D

const TELEGRAPH_DISTANCE_T := 0.16

var _installed := false
var _obstacle_count := 0
var _warning_count := 0

func _ready() -> void:
	call_deferred("_install_after_track_ready")

func _install_after_track_ready() -> void:
	for _frame in range(5):
		await get_tree().physics_frame
	if _installed or not is_inside_tree():
		return
	var track := _find_track()
	if track == null:
		push_warning("RACE OBSTACLE EXPANSION: no race track found")
		return
	var route: Array[Vector3] = track.get_route_points()
	if route.size() < 8:
		push_warning("RACE OBSTACLE EXPANSION: route too short")
		return
	if track is WildDashGrandPrixTrack:
		_build_round1(route)
	elif track is WildDashNeonHarborTrack:
		_build_round3(route)
	elif track is WildDashSnowpeakWinterTrack:
		_build_round5(route)
	_installed = true
	print("RACE OBSTACLE EXPANSION READY track=%s obstacles=%d warnings=%d full_block=false telegraph>=1s" % [
		track.name, _obstacle_count, _warning_count,
	])

func get_obstacle_count() -> int:
	return _obstacle_count

func get_warning_count() -> int:
	return _warning_count

func _find_track() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WildDashGrandPrixTrack or child is WildDashNeonHarborTrack or child is WildDashSnowpeakWinterTrack:
			return child as Node3D
	return null

func _build_round1(route: Array[Vector3]) -> void:
	_add_sphere_obstacle(route, 8, 0.54, 2.55, "R1_RollingBoulder", 1.18, WildDashDynamicObstacle.MotionType.CROSS, 0.72, 3.0, Color(0.34, 0.25, 0.18))
	_add_box_obstacle(route, 3, 0.64, -2.65, "R1_FallingLog", Vector3(4.1, 0.62, 0.72), WildDashDynamicObstacle.MotionType.ROTATE, 0.88, 0.0, Color(0.34, 0.18, 0.08))
	_add_box_obstacle(route, 12, 0.46, 2.55, "R1_SwingingBranch", Vector3(3.8, 0.48, 0.58), WildDashDynamicObstacle.MotionType.ROTATE, 1.05, 0.0, Color(0.18, 0.28, 0.08))
	_add_box_obstacle(route, 18, 0.43, -2.75, "R1_RockGateMover", Vector3(2.5, 2.2, 0.85), WildDashDynamicObstacle.MotionType.CROSS, 0.62, 2.4, Color(0.38, 0.33, 0.28))

func _build_round3(route: Array[Vector3]) -> void:
	_add_box_obstacle(route, 7, 0.50, -2.65, "R3_ForkliftCrossing", Vector3(2.7, 1.45, 1.7), WildDashDynamicObstacle.MotionType.CROSS, 0.72, 3.0, Color(0.94, 0.55, 0.06))
	_add_box_obstacle(route, 9, 0.56, 2.80, "R3_SlidingContainerGate", Vector3(3.0, 2.35, 0.72), WildDashDynamicObstacle.MotionType.CROSS, 0.62, 2.5, Color(0.18, 0.55, 0.72))
	_add_box_obstacle(route, 11, 0.48, -2.70, "R3_CraneCargoSwing", Vector3(2.5, 1.7, 2.5), WildDashDynamicObstacle.MotionType.CROSS, 0.55, 2.75, Color(0.76, 0.36, 0.08))
	_add_box_obstacle(route, 17, 0.53, 2.70, "R3_DockBarrier", Vector3(3.6, 0.55, 0.58), WildDashDynamicObstacle.MotionType.ROTATE, 0.78, 0.0, Color(0.9, 0.18, 0.12))
	_add_box_obstacle(route, 20, 0.46, -2.80, "R3_WarehouseDoor", Vector3(3.15, 2.55, 0.62), WildDashDynamicObstacle.MotionType.OPEN_CLOSE, 0.72, 3.15, Color(0.32, 0.36, 0.42))

func _build_round5(route: Array[Vector3]) -> void:
	_add_sphere_obstacle(route, 6, 0.52, 2.65, "R5_FallingSnowChunk", 1.05, WildDashDynamicObstacle.MotionType.CROSS, 0.68, 2.8, Color(0.90, 0.96, 1.0))
	_add_box_obstacle(route, 14, 0.47, -2.65, "R5_IceSpinner", Vector3(3.9, 0.48, 0.56), WildDashDynamicObstacle.MotionType.ROTATE, 0.92, 0.0, Color(0.42, 0.78, 0.95))
	_add_box_obstacle(route, 20, 0.55, 2.75, "R5_SkiGateMover", Vector3(2.65, 2.0, 0.55), WildDashDynamicObstacle.MotionType.CROSS, 0.64, 2.3, Color(0.92, 0.14, 0.18))
	_add_box_obstacle(route, 25, 0.49, -2.80, "R5_BlizzardRidgeGate", Vector3(3.0, 1.35, 0.62), WildDashDynamicObstacle.MotionType.CROSS, 0.58, 2.4, Color(0.72, 0.88, 1.0))

func _add_box_obstacle(
	route: Array[Vector3],
	segment: int,
	t: float,
	lateral: float,
	obstacle_name: String,
	size: Vector3,
	motion: WildDashDynamicObstacle.MotionType,
	speed: float,
	amplitude: float,
	color: Color,
) -> void:
	if segment < 0 or segment + 1 >= route.size():
		return
	var body := WildDashDynamicObstacle.new()
	body.name = obstacle_name
	body.motion_type = motion
	body.motion_speed = speed
	body.amplitude = amplitude
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("wilddash_race_obstacle_expansion")
	body.set_meta(&"telegraph_seconds", 1.0)
	body.set_meta(&"safe_lane_preserved", true)
	_apply_route_transform(body, route, segment, t, lateral, size.y * 0.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color, false)
	body.add_child(visual)
	add_child(body)
	_obstacle_count += 1
	_add_warning(route, segment, maxf(0.06, t - TELEGRAPH_DISTANCE_T), lateral, color)

func _add_sphere_obstacle(
	route: Array[Vector3],
	segment: int,
	t: float,
	lateral: float,
	obstacle_name: String,
	radius: float,
	motion: WildDashDynamicObstacle.MotionType,
	speed: float,
	amplitude: float,
	color: Color,
) -> void:
	if segment < 0 or segment + 1 >= route.size():
		return
	var body := WildDashDynamicObstacle.new()
	body.name = obstacle_name
	body.motion_type = motion
	body.motion_speed = speed
	body.amplitude = amplitude
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("wilddash_race_obstacle_expansion")
	body.set_meta(&"telegraph_seconds", 1.0)
	body.set_meta(&"safe_lane_preserved", true)
	_apply_route_transform(body, route, segment, t, lateral, radius)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	visual.mesh = mesh
	visual.material_override = _material(color, false)
	body.add_child(visual)
	add_child(body)
	_obstacle_count += 1
	_add_warning(route, segment, maxf(0.06, t - TELEGRAPH_DISTANCE_T), lateral, color)

func _add_warning(route: Array[Vector3], segment: int, t: float, lateral: float, color: Color) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "HazardWarning_%02d_%02d" % [segment, _warning_count]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.24, 1.35, 0.24)
	marker.mesh = mesh
	marker.material_override = _material(color.lightened(0.20), true)
	_apply_route_transform(marker, route, segment, t, lateral, 0.68)
	marker.add_to_group("wilddash_race_obstacle_warning")
	add_child(marker)
	_warning_count += 1

func _apply_route_transform(node: Node3D, route: Array[Vector3], segment: int, t: float, lateral: float, height: float) -> void:
	var a := route[segment]
	var b := route[segment + 1]
	var forward := b - a
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var origin := a.lerp(b, clampf(t, 0.0, 1.0)) + right * lateral + Vector3.UP * height
	node.position = origin
	node.rotation.y = atan2(-forward.x, -forward.z)

func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	if emissive:
		material.emission_enabled = true
		material.emission = color * 0.55
		material.emission_energy_multiplier = 1.6
	return material
