class_name WildDashGrandPrixV3ObstacleRecovery
extends Node3D

## Grand Prix V3.0 static-first obstacle recovery.
##
## The V2.8 isolation controller hid Stage3 visually but visibility alone does
## not disable CollisionObject3D physics. V3.0 explicitly disables the legacy
## Stage3 obstacle/hazard tree, then installs a small visible/static route-based
## set with simple primitive collisions. Dynamic hazards stay at zero until the
## flow/audio/start-grid pass is manually proven stable.

const DEBUG_LABEL_NAME := "V30ObstacleRecoveryLabel"
const PERF_SAMPLE_DELAY := 2.0

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _obstacle_root: Node3D
var _obstacle_count := 0
var _legacy_collision_disabled := 0
var _label: Label

func _ready() -> void:
	call_deferred("_initialize_after_track")

func _initialize_after_track() -> void:
	for _frame: int in range(10):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3ObstacleRecovery: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return

	_disable_legacy_stage3()
	_obstacle_root = Node3D.new()
	_obstacle_root.name = "V30StaticObstacleField"
	add_child(_obstacle_root)

	_build_meadow()
	_build_forest()
	_build_river()
	_build_mountain_approach()
	_build_mountain_ascent()
	_build_summit()
	_build_descent()
	_build_canyon()
	_build_final()
	_build_debug_label()

	print("GRAND PRIX V3.0 OBSTACLE RECOVERY READY static=%d dynamic=0 legacy_stage3_collisions_disabled=%d route_based=true primitive_collision=true" % [
		_obstacle_count,
		_legacy_collision_disabled,
	])
	_sample_perf_after_delay()

func _disable_legacy_stage3() -> void:
	var stage3: Node = get_parent().get_node_or_null("V2Stage3")
	if stage3 == null:
		return
	stage3.process_mode = Node.PROCESS_MODE_DISABLED
	if stage3 is Node3D:
		(stage3 as Node3D).visible = false
	_legacy_collision_disabled = _disable_collisions_recursive(stage3)
	print("GRAND PRIX V3.0 LEGACY STAGE3 DISABLED collision_nodes=%d dynamic_processing=false" % _legacy_collision_disabled)

func _disable_collisions_recursive(root: Node) -> int:
	var count := 0
	if root is CollisionShape3D:
		(root as CollisionShape3D).disabled = true
		count += 1
	elif root is CollisionObject3D:
		var object := root as CollisionObject3D
		object.collision_layer = 0
		object.collision_mask = 0
		if object is Area3D:
			(object as Area3D).monitoring = false
			(object as Area3D).monitorable = false
		count += 1
	for child: Node in root.get_children():
		count += _disable_collisions_recursive(child)
	return count

func _build_meadow() -> void:
	# Warm-up: first obstacle stays well after the start grid.
	_spawn_box(&"meadow_start", 0.36, -3.4, "MeadowHayLeft", Vector3(2.0, 1.35, 1.8), Color(0.76, 0.59, 0.20))
	_spawn_rock(&"meadow_start", 0.64, 3.3, "MeadowRockRight", 1.15)

func _build_forest() -> void:
	# Dodge: alternating partial-lane blockers with a clear opposite line.
	_spawn_rock(&"forest_obstacle", 0.18, -3.3, "ForestRockLeft", 1.15)
	_spawn_box(&"forest_obstacle", 0.37, 3.0, "ForestLogRight", Vector3(3.8, 0.72, 1.1), Color(0.34, 0.18, 0.07))
	_spawn_rock(&"forest_obstacle", 0.58, 3.2, "ForestBoulderRight", 1.45)
	_spawn_box(&"forest_obstacle", 0.78, -3.0, "ForestLogLeft", Vector3(3.6, 0.68, 1.0), Color(0.31, 0.16, 0.06))

func _build_river() -> void:
	# Line choice: staggered bank/river rocks and driftwood; never seal all lanes.
	_spawn_rock(&"long_river", 0.24, -3.1, "RiverRockLeft", 1.10)
	_spawn_box(&"long_river", 0.50, 3.0, "RiverDriftwoodRight", Vector3(3.4, 0.62, 1.0), Color(0.29, 0.18, 0.10))
	_spawn_rock(&"long_river", 0.74, -2.8, "RiverRockLeft2", 1.25)

func _build_mountain_approach() -> void:
	_spawn_rock(&"mountain_approach", 0.34, 3.0, "MountainApproachBoulderRight", 1.45)
	_spawn_rock(&"mountain_approach", 0.68, -3.0, "MountainApproachRockLeft", 1.10)

func _build_mountain_ascent() -> void:
	# Precision: smaller alternating rocks, static-only during stabilization.
	_spawn_rock(&"mountain_ascent", 0.24, -2.7, "MountainAscentRockLeft", 1.05)
	_spawn_rock(&"mountain_ascent", 0.49, 2.8, "MountainAscentBoulderRight", 1.40)
	_spawn_rock(&"mountain_ascent", 0.74, -2.6, "MountainAscentRockLeft2", 1.05)

func _build_summit() -> void:
	# Breathing section: one alignment cue only.
	_spawn_rock(&"summit_ridge", 0.50, 2.8, "SummitMarkerRock", 1.05)

func _build_descent() -> void:
	# Speed control: alternating static clusters; terrain roughness still owns slowdown.
	_spawn_rock(&"rough_descent", 0.30, -3.0, "DescentRockLeft", 1.10)
	_spawn_rock(&"rough_descent", 0.55, 3.0, "DescentBoulderRight", 1.45)
	_spawn_rock(&"rough_descent", 0.78, -2.8, "DescentRockLeft2", 1.05)

func _build_canyon() -> void:
	# Reaction: alternating boulders while natural cliff geometry remains boundary.
	_spawn_rock(&"canyon_obstacle", 0.22, 2.8, "CanyonBoulderRight", 1.40)
	_spawn_rock(&"canyon_obstacle", 0.48, -2.8, "CanyonRockLeft", 1.15)
	_spawn_rock(&"canyon_obstacle", 0.73, 2.7, "CanyonRockRight", 1.15)

func _build_final() -> void:
	# Sprint: sparse farm obstacles and an open center/overtake line.
	_spawn_box(&"final_sprint", 0.34, -3.6, "FinalHayLeft", Vector3(2.0, 1.3, 1.8), Color(0.78, 0.61, 0.20))
	_spawn_box(&"final_sprint", 0.60, 3.6, "FinalHayRight", Vector3(2.0, 1.3, 1.8), Color(0.78, 0.61, 0.20))

func _spawn_box(section_id: StringName, progress: float, lateral: float, node_name: String, size: Vector3, color: Color) -> void:
	var pose := _sample_section_pose(section_id, progress, lateral, size.x * 0.5)
	if pose.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	_obstacle_root.add_child(body)
	body.global_position = (pose["position"] as Vector3) + Vector3.UP * (size.y * 0.5)
	var forward := pose["forward"] as Vector3
	body.look_at(body.global_position + forward, Vector3.UP)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_obstacle_count += 1

func _spawn_rock(section_id: StringName, progress: float, lateral: float, node_name: String, radius: float) -> void:
	var pose := _sample_section_pose(section_id, progress, lateral, radius)
	if pose.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	_obstacle_root.add_child(body)
	body.global_position = (pose["position"] as Vector3) + Vector3.UP * radius

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.08, 0.88, 1.0)
	mesh_instance.material_override = _material(Color(0.34, 0.32, 0.29))
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.88
	collision.shape = shape
	body.add_child(collision)
	_obstacle_count += 1

func _sample_section_pose(section_id: StringName, progress: float, lateral: float, obstacle_half_width: float) -> Dictionary:
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
	var safe_limit := maxf(1.5, road_width * 0.5 - obstacle_half_width - 1.15)
	var safe_lateral := clampf(lateral, -safe_limit, safe_limit)
	var center := a.lerp(b, 0.5)
	return {
		"position": center + right * safe_lateral,
		"forward": forward,
		"right": right,
		"segment_index": segment_index,
		"road_width": road_width,
	}

func _find_v2_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found := _find_v2_track(child)
		if found != null:
			return found
	return null

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material

func _build_debug_label() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_label = Label.new()
	_label.name = DEBUG_LABEL_NAME
	_label.position = Vector2(24.0, 326.0)
	_label.z_index = 1000
	_label.add_theme_font_size_override("font_size", 15)
	_label.text = "V3.0 STATIC OBSTACLES %d | Dynamic 0 | Legacy Stage3 OFF" % _obstacle_count
	get_parent().add_child(_label)

func _sample_perf_after_delay() -> void:
	await get_tree().create_timer(PERF_SAMPLE_DELAY).timeout
	print("GRAND PRIX V3.0 OBSTACLE PERF fps=%.1f draw_calls=%.0f physics_active=%.0f nodes=%.0f static_obstacles=%d dynamic_obstacles=0" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		_obstacle_count,
	])
