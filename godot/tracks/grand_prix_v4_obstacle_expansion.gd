class_name WildDashGrandPrixV4ObstacleExpansion
extends Node3D

## Round 1 V4 obstacle-density pass.
## Adds 12 route-aware static obstacles on top of the proven V3 field without
## sealing every lane. Low hurdles reward jump timing while rocks preserve the
## existing dodge/readability language. No dynamic physics objects are added.

const EXTRA_OBSTACLE_TARGET := 12

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _root: Node3D
var _count := 0

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	for _frame: int in range(12):
		await get_tree().process_frame
	_track = _find_track(get_parent())
	if _track == null:
		push_warning("Grand Prix V4 obstacle expansion: track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return

	_root = Node3D.new()
	_root.name = "V4ObstacleExpansionField"
	add_child(_root)

	# Meadow: introduce jump timing before the course becomes technical.
	_spawn_hurdle(&"meadow_start", 0.48, 2.8, "V4MeadowHurdleRight")
	_spawn_rock(&"meadow_start", 0.82, -2.8, "V4MeadowRockLeft", 1.0)

	# Forest: alternating jump/dodge choices, always leaving an opposite line.
	_spawn_hurdle(&"forest_obstacle", 0.28, -2.7, "V4ForestHurdleLeft")
	_spawn_rock(&"forest_obstacle", 0.88, 2.5, "V4ForestRockRight", 1.05)

	# River: one low drift hurdle, avoiding the recovery edge itself.
	_spawn_hurdle(&"long_river", 0.88, 2.7, "V4RiverDriftHurdle")

	# Mountain approach/ascent: readable partial-lane blockers, not walls.
	_spawn_hurdle(&"mountain_approach", 0.52, -2.6, "V4MountainApproachHurdle")
	_spawn_hurdle(&"mountain_ascent", 0.62, 2.5, "V4MountainAscentHurdle")

	# Summit: previously almost empty; add one jump cue and one dodge cue.
	_spawn_hurdle(&"summit_ridge", 0.30, -2.5, "V4SummitHurdleLeft")
	_spawn_rock(&"summit_ridge", 0.70, 2.6, "V4SummitRockRight", 1.0)

	# Descent/canyon: reaction checks while preserving recovery space.
	_spawn_hurdle(&"rough_descent", 0.42, 2.5, "V4DescentHurdleRight")
	_spawn_hurdle(&"canyon_obstacle", 0.61, -2.5, "V4CanyonHurdleLeft")

	# Final: one obvious center hurdle that can be jumped or driven around.
	_spawn_hurdle(&"final_sprint", 0.78, 0.0, "V4FinalCenterHurdle", 3.0)

	print("GRAND PRIX V4.1 OBSTACLE EXPANSION READY extra=%d expected=%d static_only=true hurdles=true route_open=true" % [
		_count, EXTRA_OBSTACLE_TARGET,
	])

func _spawn_hurdle(section_id: StringName, progress: float, lateral: float, node_name: String, width: float = 3.2) -> void:
	var pose := _sample_pose(section_id, progress, lateral, width * 0.5)
	if pose.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	_root.add_child(body)
	body.global_position = (pose["position"] as Vector3)
	var forward := pose["forward"] as Vector3
	body.look_at(body.global_position + forward, Vector3.UP)

	# One low collision bar: jumpable, but never a full-lane wall.
	var collision := CollisionShape3D.new()
	collision.position = Vector3(0.0, 0.48, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.76, 0.34)
	collision.shape = shape
	body.add_child(collision)

	_add_box_visual(body, "Crossbar", Vector3(0.0, 0.62, 0.0), Vector3(width, 0.24, 0.30), Color(0.92, 0.55, 0.12))
	_add_box_visual(body, "PostL", Vector3(-width * 0.43, 0.36, 0.0), Vector3(0.20, 0.72, 0.24), Color(0.92, 0.88, 0.70))
	_add_box_visual(body, "PostR", Vector3(width * 0.43, 0.36, 0.0), Vector3(0.20, 0.72, 0.24), Color(0.92, 0.88, 0.70))
	_count += 1

func _spawn_rock(section_id: StringName, progress: float, lateral: float, node_name: String, radius: float) -> void:
	var pose := _sample_pose(section_id, progress, lateral, radius)
	if pose.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	_root.add_child(body)
	body.global_position = (pose["position"] as Vector3) + Vector3.UP * radius

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.08, 0.88, 1.0)
	mesh_instance.material_override = _material(Color(0.36, 0.33, 0.29))
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.88
	collision.shape = shape
	body.add_child(collision)
	_count += 1

func _add_box_visual(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = local_position
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(visual)

func _sample_pose(section_id: StringName, progress: float, lateral: float, half_width: float) -> Dictionary:
	if not _ranges.has(section_id):
		return {}
	var section_range: Vector2i = _ranges[section_id] as Vector2i
	var start_segment := clampi(section_range.x, 0, _route.size() - 2)
	var end_segment := clampi(section_range.y, start_segment, _route.size() - 2)
	var segment_index := clampi(roundi(lerpf(float(start_segment), float(end_segment), clampf(progress, 0.0, 1.0))), start_segment, end_segment)
	var a := _route[segment_index]
	var b := _route[segment_index + 1]
	var forward := b - a
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var road_width := _track.get_v2_width_for_segment(segment_index)
	var safe_limit := maxf(1.5, road_width * 0.5 - half_width - 1.15)
	var safe_lateral := clampf(lateral, -safe_limit, safe_limit)
	var center := a.lerp(b, 0.5)
	return {
		"position": center + right * safe_lateral,
		"forward": forward,
		"segment_index": segment_index,
	}

func _find_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found := _find_track(child)
		if found != null:
			return found
	return null

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material
