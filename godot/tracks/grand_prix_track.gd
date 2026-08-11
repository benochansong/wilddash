class_name WildDashGrandPrixTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")
const TRACK_GUIDE_FACTORY: Script = preload("res://tracks/track_guide_factory.gd")

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0, 0, 80),
	Vector3(0, 0, 0),
	Vector3(-45, 0, -70),
	Vector3(-70, 0, -150),
	Vector3(-40, 6, -220),
	Vector3(20, 6, -285),
	Vector3(80, 2, -350),
	Vector3(134, 4, -408),
	Vector3(187, 7, -474),
	Vector3(154, 9, -544),
	Vector3(92, 5, -598),
	Vector3(55, 4, -664),
	Vector3(39, -8, -754),
	Vector3(2, -21, -849),
	Vector3(-44, -24, -911),
	Vector3(6, -23, -985),
	Vector3(59, -18, -1051),
	Vector3(190, -15, -1090),
	Vector3(167, -11, -1150),
	Vector3(138, -8, -1216),
	Vector3(72, -6, -1245),
	Vector3(18, -3, -1307),
	Vector3(-31, 1, -1373),
	Vector3(-85, 2, -1431),
	Vector3(-140, 4, -1510),
	Vector3(-64, 0, -1567),
	Vector3(-2, -1, -1633),
	Vector3(59, 0, -1695),
	Vector3(35, 0, -1769),
	Vector3(14, 0, -1852),
]

const SEGMENT_WIDTHS: Array[float] = [
	18, 18, 14, 14, 12, 8, 16, 14, 11, 10,
	18, 17, 18, 16, 10, 20, 18, 18, 22, 22,
	20, 15, 14, 13, 13, 12, 11, 12, 18,
]
const SEGMENT_NAMES: Array[String] = [
	"Meadow Straight", "First Bend", "Forest Run", "Uphill", "Jump Approach",
	"Narrow Bridge", "Obstacle Field", "Canyon Entry", "Cliff S Curve", "Canyon Squeeze",
	"Rally Straight", "Downhill Crest", "Long Downhill", "River Approach", "River Bridge",
	"Gate Approach", "Moving Gate Detour In", "Moving Gate Detour Out", "Spiral Entry", "Wide Hairpin",
	"Hairpin Exit", "Multi Jump Approach", "Multi Jump Ridge", "Shortcut B Detour In", "Shortcut B Detour Out",
	"Tunnel", "Final S Curve", "Final Chicane", "Final Straight",
]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 4, 6, 9, 12, 15, 18, 21, 23, 26, 28]
const RAIL_SEGMENT_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 7, 8, 9, 12, 14, 18, 19, 23, 25, 26, 27, 28]

const SHORTCUT_A_ENTRY_ROUTE_INDEX := 16
const SHORTCUT_A_SKIP_ROUTE_INDEX := 17
const SHORTCUT_A_EXIT_ROUTE_INDEX := 18
const SHORTCUT_B_ENTRY_ROUTE_INDEX := 23
const SHORTCUT_B_SKIP_ROUTE_INDEX := 24
const SHORTCUT_B_EXIT_ROUTE_INDEX := 25

var _track_length := 0.0
var _materials: Dictionary
var _road_material: Material
var _dirt_material: Material
var _grass_material: Material
var _rail_material: Material
var _marker_material: Material
var _obstacle_material: Material
var _shortcut_material: Material
var _water_material: Material
var _rock_material: Material
var _bridge_material: Material
var _tunnel_material: Material
var _wood_material: Material
var _decoration_root: Node3D
var _collision_root: Node3D
var _road_visual_batches: Dictionary
var _road_rock_border_transforms: Array[Transform3D] = []

func _ready() -> void:
	_materials = WildDashEnvironmentMaterialLibrary.get_palette()
	_road_material = _materials[&"asphalt"]
	_dirt_material = _materials[&"dirt"]
	_grass_material = _materials[&"grass"]
	_rail_material = _materials[&"guardrail"]
	_marker_material = _make_material(Color(0.9, 1.0, 0.18), 0.55, true)
	_obstacle_material = _make_material(Color(1.0, 0.28, 0.42), 0.72)
	_shortcut_material = _materials[&"dirt"]
	_water_material = _materials[&"water"]
	_rock_material = _materials[&"rock"]
	_bridge_material = _materials[&"bridge"]
	_tunnel_material = _materials[&"tunnel"]
	_wood_material = _materials[&"wood"]
	_build_environment_lighting()
	_build_track()
	_configure_environment_lod_and_visibility()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("GRAND PRIX TRACK READY route_points=%d checkpoints=%d length=%.1fm nodes=%d" % [
		ROUTE_POINTS.size(), CHECKPOINT_ROUTE_INDICES.size(), _track_length, get_runtime_node_count(),
	])

func get_route_points() -> Array[Vector3]:
	return ROUTE_POINTS.duplicate()

func get_checkpoint_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for route_index in CHECKPOINT_ROUTE_INDICES:
		result.append(ROUTE_POINTS[route_index])
	return result

func get_track_length() -> float:
	return _track_length

func get_start_position() -> Vector3:
	return ROUTE_POINTS[0]

func get_finish_position() -> Vector3:
	return ROUTE_POINTS[ROUTE_POINTS.size() - 1]

func get_shortcut_a_saving() -> float:
	return _shortcut_saving(SHORTCUT_A_ENTRY_ROUTE_INDEX, SHORTCUT_A_SKIP_ROUTE_INDEX, SHORTCUT_A_EXIT_ROUTE_INDEX)

func get_shortcut_b_saving() -> float:
	return _shortcut_saving(SHORTCUT_B_ENTRY_ROUTE_INDEX, SHORTCUT_B_SKIP_ROUTE_INDEX, SHORTCUT_B_EXIT_ROUTE_INDEX)

func get_runtime_node_count() -> int:
	return _count_nodes_recursive(self)

func _build_track() -> void:
	_decoration_root = Node3D.new()
	_decoration_root.name = "DecorationGeometry"
	_decoration_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_decoration_root)
	_collision_root = Node3D.new()
	_collision_root.name = "GameplayCollision"
	add_child(_collision_root)
	var asphalt_visuals: Array[Transform3D] = []
	var dirt_visuals: Array[Transform3D] = []
	var bridge_visuals: Array[Transform3D] = []
	var tunnel_visuals: Array[Transform3D] = []
	var shortcut_visuals: Array[Transform3D] = []
	_road_visual_batches = {
		&"asphalt": asphalt_visuals,
		&"dirt": dirt_visuals,
		&"bridge": bridge_visuals,
		&"tunnel": tunnel_visuals,
		&"shortcut": shortcut_visuals,
	}

	_track_length = 0.0
	for i in range(ROUTE_POINTS.size() - 1):
		var a := ROUTE_POINTS[i]
		var b := ROUTE_POINTS[i + 1]
		var width := SEGMENT_WIDTHS[i]
		_track_length += a.distance_to(b)
		_create_segment(
			"Road_%02d_%s" % [i, SEGMENT_NAMES[i].replace(" ", "_")],
			a, b, width, 0.5, _road_material_for_segment(i), true, -0.22,
			_road_material_key_for_segment(i)
		)
		if RAIL_SEGMENT_INDICES.has(i):
			_create_guardrails(i, a, b, width)

	_flush_road_visual_batches()
	_build_road_surface_details()
	_build_start_line()
	_build_checkpoints()
	_build_finish_line()
	_build_static_obstacles()
	_build_dynamic_obstacles()
	_build_bridge_details()
	_build_canyon_section()
	_build_multi_jump()
	_build_tunnel()
	_build_shortcuts()
	_build_forest_dressing()
	_build_environment_pass_2()
	_build_track_guides()

func _create_segment(
	node_name: String,
	a: Vector3,
	b: Vector3,
	width: float,
	height: float,
	material: Material,
	collision: bool,
	vertical_offset := 0.0,
	visual_batch: StringName = &""
) -> CSGBox3D:
	var visual: CSGBox3D = null
	var segment_size := Vector3(width, height, a.distance_to(b))
	if visual_batch != &"":
		_road_visual_batches[visual_batch].append(_track_transform_at(
			a, b, 0.5, 0.0, vertical_offset, segment_size
		))
	else:
		visual = CSGBox3D.new()
		visual.name = node_name + "_Visual"
		visual.size = segment_size
		visual.use_collision = false
		visual.material = material
		visual.position = (a + b) * 0.5 + Vector3.UP * vertical_offset
		_decoration_root.add_child(visual)
		visual.look_at(b + Vector3.UP * vertical_offset, Vector3.UP)
	if collision:
		var collision_shape := CSGBox3D.new()
		collision_shape.name = node_name + "_Collision"
		collision_shape.size = segment_size
		collision_shape.use_collision = true
		collision_shape.visible = false
		collision_shape.position = (a + b) * 0.5 + Vector3.UP * vertical_offset
		_collision_root.add_child(collision_shape)
		collision_shape.look_at(b + Vector3.UP * vertical_offset, Vector3.UP)
	return visual

func _road_material_for_segment(index: int) -> Material:
	if index == 5 or index == 14:
		return _materials[&"bridge_road"]
	if index == 25:
		return _materials[&"tunnel_road"]
	if index >= 7 and index <= 13:
		return _materials[&"dirt_road"]
	return _road_material

func _road_material_key_for_segment(index: int) -> StringName:
	if index == 5 or index == 14:
		return &"bridge"
	if index == 25:
		return &"tunnel"
	if index >= 7 and index <= 13:
		return &"dirt"
	return &"asphalt"

func _flush_road_visual_batches() -> void:
	for material_key: StringName in _road_visual_batches:
		var transforms: Array[Transform3D] = _road_visual_batches[material_key]
		var palette_key := material_key
		if material_key == &"shortcut":
			palette_key = &"dirt"
		elif material_key == &"dirt":
			palette_key = &"dirt_road"
		elif material_key == &"bridge":
			palette_key = &"bridge_road"
		elif material_key == &"tunnel":
			palette_key = &"tunnel_road"
		_add_box_multimesh(
			"RoadSurface_%s" % String(material_key).capitalize(),
			transforms,
			_materials[palette_key]
		)

func _build_road_surface_details() -> void:
	var grass_shoulder_transforms: Array[Transform3D] = []
	var dirt_shoulder_transforms: Array[Transform3D] = []
	var painted_edge_transforms: Array[Transform3D] = []
	var curb_warning_transforms: Array[Transform3D] = []
	var line_transforms: Array[Transform3D] = []
	var hazard_transforms: Array[Transform3D] = []
	var guardrail_post_transforms: Array[Transform3D] = []
	var fence_post_transforms: Array[Transform3D] = []
	for index in range(ROUTE_POINTS.size() - 1):
		var a := ROUTE_POINTS[index]
		var b := ROUTE_POINTS[index + 1]
		var width := SEGMENT_WIDTHS[index]
		var length := a.distance_to(b)
		var is_bridge := index == 5 or index == 14
		var is_tunnel := index == 25
		var is_canyon := index >= 7 and index <= 13
		var is_forest := index >= 2 and index <= 4
		if not is_bridge and not is_tunnel:
			for side in [-1.0, 1.0]:
				if is_forest:
					dirt_shoulder_transforms.append(_track_transform_at(
						a, b, 0.5, side * (width * 0.5 + 0.78), -0.25,
						Vector3(1.55, 0.22, length)
					))
					grass_shoulder_transforms.append(_track_transform_at(
						a, b, 0.5, side * (width * 0.5 + 2.10), -0.30,
						Vector3(1.10, 0.20, length)
					))
				elif is_canyon:
					dirt_shoulder_transforms.append(_track_transform_at(
						a, b, 0.5, side * (width * 0.5 + 0.92), -0.28,
						Vector3(1.85, 0.20, length)
					))
					for rock_index in range(3):
						var rock_t := 0.18 + float(rock_index) * 0.32
						var rock_scale := Vector3(
							0.75 + float((index + rock_index) % 3) * 0.18,
							0.38 + float((index + rock_index) % 2) * 0.12,
							0.88 + float((index * 2 + rock_index) % 3) * 0.16
						)
						var rock_transform := _track_transform_at(
							a, b, rock_t, side * (width * 0.5 + 1.75), 0.02 + rock_scale.y * 0.35,
							rock_scale
						)
						rock_transform.basis = rock_transform.basis.rotated(Vector3.UP, float(index + rock_index) * 0.31 * side)
						_road_rock_border_transforms.append(rock_transform)
				else:
					grass_shoulder_transforms.append(_track_transform_at(
						a, b, 0.5, side * (width * 0.5 + 1.15), -0.28,
						Vector3(2.3, 0.24, length)
					))
		for side in [-1.0, 1.0]:
			painted_edge_transforms.append(_track_transform_at(
				a, b, 0.5, side * (width * 0.5 - 0.42), 0.105,
				Vector3(0.20, 0.045, maxf(0.5, length - 0.35))
			))
		if not is_tunnel:
			for side in [-1.0, 1.0]:
				var curb_transform := _track_transform_at(
					a, b, 0.5, side * (width * 0.5 - 0.18), 0.09,
					Vector3(0.34, 0.12, length)
				)
				if is_canyon or is_bridge:
					curb_warning_transforms.append(curb_transform)
		if not is_canyon:
			var dash_count := maxi(2, int(length / 14.0))
			for dash_index in range(dash_count):
				var t := (float(dash_index) + 0.5) / float(dash_count)
				line_transforms.append(_track_transform_at(
					a, b, t, 0.0, 0.10, Vector3(0.18, 0.055, 4.2)
				))
		if is_bridge or is_tunnel:
			for stripe_index in range(4):
				hazard_transforms.append(_track_transform_at(
					a, b, 0.06 + float(stripe_index) * 0.025, 0.0, 0.105,
					Vector3(width * 0.82, 0.06, 0.28)
				))
		if RAIL_SEGMENT_INDICES.has(index):
			for side in [-1.0, 1.0]:
				var beam_transform := _track_transform_at(
					a, b, 0.5, side * (width * 0.5 + 0.2), 1.0,
					Vector3(0.22, 0.42, length)
				)
				if index >= 2 and index <= 4:
					fence_post_transforms.append(beam_transform)
				else:
					guardrail_post_transforms.append(beam_transform)
				for post_index in range(3):
					var post_transform := _track_transform_at(
						a, b, 0.15 + float(post_index) * 0.35,
						side * (width * 0.5 + 0.2), 0.55,
						Vector3(0.26, 1.2, 0.26)
					)
					if index >= 2 and index <= 4:
						fence_post_transforms.append(post_transform)
					else:
						guardrail_post_transforms.append(post_transform)
	# Edge lines and center dashes share one static paint batch, freeing the node
	# budget needed by the two reusable guide MultiMeshes.
	painted_edge_transforms.append_array(line_transforms)
	# Bridge/tunnel entry strips use the same warm warning family as structural
	# curbs, so they can share one draw batch without losing their visual role.
	curb_warning_transforms.append_array(hazard_transforms)
	_add_box_multimesh("GrassShoulders", grass_shoulder_transforms, _grass_material)
	_add_box_multimesh("RoadDustyShoulders", dirt_shoulder_transforms, _dirt_material)
	_add_box_multimesh("RoadPaintedEdgeLines", painted_edge_transforms, _materials[&"road_edge"])
	_add_box_multimesh("RoadCurbsWarning", curb_warning_transforms, _materials[&"curb_warning"])
	_add_box_multimesh("GuardrailPosts", guardrail_post_transforms, _rail_material)
	_add_box_multimesh("WoodStructuresAndProps", fence_post_transforms, _wood_material)

func _track_transform_at(
	a: Vector3,
	b: Vector3,
	t: float,
	lateral_offset: float,
	vertical_offset: float,
	size: Vector3
) -> Transform3D:
	var direction := b - a
	var planar := Vector3(direction.x, 0.0, direction.z).normalized()
	var right := Vector3(-planar.z, 0.0, planar.x)
	var origin := a.lerp(b, t) + right * lateral_offset + Vector3.UP * vertical_offset
	var transform := Transform3D(Basis.IDENTITY, origin)
	transform = transform.looking_at(origin + direction.normalized(), Vector3.UP)
	transform.basis = transform.basis.scaled(size)
	return transform

func _build_track_guides() -> void:
	var road_arrows: Array[Transform3D] = []
	# Sparse anticipation marks: no arrows are placed on ordinary straights.
	_append_road_arrows(road_arrows, 2, 3, [0.64, 0.82]) # Forest sharp bend.
	_append_road_arrows(road_arrows, 3, 4, [0.72, 0.88]) # Main jump entry.
	_append_road_arrows(road_arrows, 4, 5, [0.72, 0.88]) # Narrow bridge landing/entry.
	_append_road_arrows(road_arrows, 6, 7, [0.58]) # Continuation behind obstacle field.
	_append_road_arrows(road_arrows, 7, 8, [0.62, 0.82]) # Canyon S-curve entry.
	_append_road_arrows(road_arrows, 9, 10, [0.72]) # Canyon S-curve return.
	_append_road_arrows(road_arrows, 13, 14, [0.58, 0.78]) # River bridge approach.
	_append_road_arrows(road_arrows, 15, 16, [0.68]) # Shortcut A/main-route fork.
	_append_road_arrows(road_arrows, 16, 17, [0.64, 0.82]) # Gate detour sharp turn.
	_append_road_arrows(road_arrows, 18, 19, [0.58, 0.78]) # Wide hairpin.
	_append_road_arrows(road_arrows, 20, 21, [0.76, 0.90]) # Multi-jump entry.
	_append_road_arrows(road_arrows, 22, 23, [0.74]) # Shortcut B/main-route fork.
	_append_road_arrows(road_arrows, 23, 24, [0.64, 0.82]) # Shortcut B detour turn.
	_append_road_arrows(road_arrows, 24, 25, [0.66, 0.84]) # Tunnel approach.
	_append_road_arrows(road_arrows, 26, 27, [0.58, 0.78]) # Final technical section.
	var arrow_batch: MultiMeshInstance3D = TRACK_GUIDE_FACTORY.create_direction_arrow(
		_decoration_root, "RoadDirectionArrows", road_arrows, _materials[&"guide_arrow"]
	)
	arrow_batch.set_meta(&"coverage", PackedStringArray([
		"sharp_curve", "hairpin", "s_curve", "branch", "bridge", "tunnel",
		"jump", "obstacle", "final",
	]))

	var trackside_guides: Array[Transform3D] = []
	_append_curve_chevrons(trackside_guides, 3, 3, 0.92) # Forest bend.
	_append_curve_chevrons(trackside_guides, 8, 4, 1.02) # Canyon S entry.
	_append_curve_chevrons(trackside_guides, 10, 3, 0.88) # Canyon S return.
	_append_curve_chevrons(trackside_guides, 14, 5, 1.10) # River bridge turn.
	_append_curve_chevrons(trackside_guides, 17, 5, 1.14) # Gate detour sharp turn.
	_append_curve_chevrons(trackside_guides, 19, 4, 1.02) # Wide hairpin.
	_append_curve_chevrons(trackside_guides, 24, 5, 1.12) # Shortcut B detour.
	_append_curve_chevrons(trackside_guides, 27, 4, 1.08) # Final chicane.
	_append_trackside_direction_marker(trackside_guides, 4, 0.78, 0.92) # Jump entry.
	_append_trackside_direction_marker(trackside_guides, 16, 0.74, 0.94) # Fork A.
	_append_trackside_direction_marker(trackside_guides, 23, 0.76, 0.94) # Fork B.
	_append_trackside_direction_marker(trackside_guides, 25, 0.76, 0.92) # Tunnel entry.
	var trackside_batch: MultiMeshInstance3D = TRACK_GUIDE_FACTORY.create_curve_chevrons(
		_decoration_root, "TracksideDirectionGuides", trackside_guides,
		_materials[&"guide_backing"], _materials[&"guide_arrow"]
	)
	trackside_batch.set_meta(&"coverage", PackedStringArray([
		"sharp_curve", "hairpin", "s_curve", "branch", "bridge", "tunnel", "jump", "final",
	]))

func _append_road_arrows(
	result: Array[Transform3D],
	approach_segment: int,
	direction_segment: int,
	samples: Array,
	lateral_offset := 0.0
) -> void:
	var approach_a := ROUTE_POINTS[approach_segment]
	var approach_b := ROUTE_POINTS[approach_segment + 1]
	var guide_direction := ROUTE_POINTS[direction_segment + 1] - ROUTE_POINTS[direction_segment]
	for sample in samples:
		var origin := approach_a.lerp(approach_b, float(sample))
		origin += _segment_right(approach_segment) * lateral_offset + Vector3.UP * 0.13
		var transform := Transform3D(Basis.IDENTITY, origin)
		transform = transform.looking_at(origin + guide_direction.normalized(), Vector3.UP)
		transform.basis = transform.basis.scaled(Vector3(2.35, 1.0, 3.15))
		result.append(transform)

func _append_curve_chevrons(
	result: Array[Transform3D],
	turn_route_index: int,
	count: int,
	scale: float
) -> void:
	var point := ROUTE_POINTS[turn_route_index]
	var next := ROUTE_POINTS[turn_route_index + 1]
	var turn_sign := _turn_sign(turn_route_index)
	var outside_side := -turn_sign
	var outgoing_right := _segment_right(turn_route_index)
	var width := SEGMENT_WIDTHS[turn_route_index]
	var face_target := ROUTE_POINTS[turn_route_index - 1].lerp(point, 0.88) + Vector3.UP * 1.25
	for index in range(count):
		var t := 0.10 + float(index) * 0.085
		var origin := point.lerp(next, t) + outgoing_right * outside_side * (width * 0.5 + 1.25)
		var transform := Transform3D(Basis.IDENTITY, origin)
		transform = transform.looking_at(face_target, Vector3.UP)
		transform.basis = transform.basis.scaled(Vector3(turn_sign * scale, scale, turn_sign * scale))
		result.append(transform)

func _append_trackside_direction_marker(
	result: Array[Transform3D],
	turn_route_index: int,
	approach_t: float,
	scale: float
) -> void:
	var approach_index := turn_route_index - 1
	var approach_a := ROUTE_POINTS[approach_index]
	var approach_b := ROUTE_POINTS[turn_route_index]
	var turn_sign := _turn_sign(turn_route_index)
	var outside_side := -turn_sign
	var origin := approach_a.lerp(approach_b, approach_t)
	origin += _segment_right(approach_index) * outside_side * (SEGMENT_WIDTHS[approach_index] * 0.5 + 1.20)
	var face_target := approach_a.lerp(approach_b, maxf(0.0, approach_t - 0.28)) + Vector3.UP * 1.25
	var transform := Transform3D(Basis.IDENTITY, origin)
	transform = transform.looking_at(face_target, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(turn_sign * scale, scale, turn_sign * scale))
	result.append(transform)

func _segment_right(segment_index: int) -> Vector3:
	var direction := ROUTE_POINTS[segment_index + 1] - ROUTE_POINTS[segment_index]
	direction.y = 0.0
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)

func _turn_sign(route_index: int) -> float:
	var outgoing := ROUTE_POINTS[route_index + 1] - ROUTE_POINTS[route_index]
	outgoing.y = 0.0
	return 1.0 if outgoing.normalized().dot(_segment_right(route_index - 1)) >= 0.0 else -1.0

func _add_box_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	_decoration_root.add_child(instance)

func _create_guardrails(index: int, a: Vector3, b: Vector3, width: float) -> void:
	var planar := b - a
	planar.y = 0.0
	if planar.length_squared() < 0.01:
		return
	var direction := planar.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x)
	var midpoint := (a + b) * 0.5 + Vector3.UP * 0.65
	for side in [-1.0, 1.0]:
		var rail_position: Vector3 = midpoint + right * (width * 0.5 + 0.2) * side
		var rail_target: Vector3 = b + right * (width * 0.5 + 0.2) * side + Vector3.UP * 0.65
		var rail_collision := CSGBox3D.new()
		rail_collision.name = "Rail_%02d_%s_Collision" % [index, "L" if side < 0.0 else "R"]
		rail_collision.size = Vector3(0.35, 1.35, a.distance_to(b))
		rail_collision.use_collision = true
		rail_collision.visible = false
		rail_collision.position = rail_position
		_collision_root.add_child(rail_collision)
		rail_collision.look_at(rail_target, Vector3.UP)

func _build_start_line() -> void:
	_create_marker("StartLine", ROUTE_POINTS[0], ROUTE_POINTS[1], SEGMENT_WIDTHS[0])

func _build_checkpoints() -> void:
	for checkpoint_index in range(CHECKPOINT_ROUTE_INDICES.size()):
		var route_index := CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point := ROUTE_POINTS[route_index]
		var next_point := ROUTE_POINTS[min(route_index + 1, ROUTE_POINTS.size() - 1)]
		var width := SEGMENT_WIDTHS[min(route_index, SEGMENT_WIDTHS.size() - 1)]
		var area := Area3D.new()
		area.name = "Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.7
		area.collision_mask = 2
		add_child(area)
		area.look_at(next_point + Vector3.UP * 1.7, Vector3.UP)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width + 1.5, 4.0, 6.0)
		shape.shape = box
		area.add_child(shape)
		_create_marker("CheckpointStripe_%02d" % (checkpoint_index + 1), point, next_point, width)

func _build_finish_line() -> void:
	var finish := ROUTE_POINTS[ROUTE_POINTS.size() - 1]
	var previous := ROUTE_POINTS[ROUTE_POINTS.size() - 2]
	var direction := (finish - previous).normalized()
	var next_point := finish + direction * 8.0
	var area := Area3D.new()
	area.name = "FinishLine"
	area.set_script(FINISH_SCRIPT)
	area.position = finish + Vector3.UP * 1.8
	area.collision_mask = 2
	add_child(area)
	area.look_at(next_point + Vector3.UP * 1.8, Vector3.UP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SEGMENT_WIDTHS[SEGMENT_WIDTHS.size() - 1] + 1.5, 4.2, 7.0)
	shape.shape = box
	area.add_child(shape)
	_create_marker("FinishStripe", finish, next_point, SEGMENT_WIDTHS[SEGMENT_WIDTHS.size() - 1])

func _create_marker(node_name: String, point: Vector3, look_target: Vector3, width: float) -> void:
	var marker := CSGBox3D.new()
	marker.name = node_name
	marker.size = Vector3(width, 0.07, 1.2)
	marker.use_collision = false
	marker.material = _marker_material
	marker.position = point + Vector3.UP * 0.04
	_decoration_root.add_child(marker)
	marker.look_at(look_target + Vector3.UP * 0.04, Vector3.UP)

func _build_static_obstacles() -> void:
	_add_static_box("ForestBlockA", ROUTE_POINTS[3] + Vector3(3.2, 1.0, 0), Vector3(2.4, 2.0, 2.4))
	_add_static_box("ForestBlockB", ROUTE_POINTS[3] + Vector3(-3.0, 0.8, -12), Vector3(2.0, 1.6, 3.0))
	_add_static_box("ObstacleFieldA", ROUTE_POINTS[6] + Vector3(-4.0, 0.9, 2.0), Vector3(2.4, 1.8, 2.4))
	_add_static_box("ObstacleFieldB", ROUTE_POINTS[6] + Vector3(3.6, 0.7, -8.0), Vector3(3.0, 1.4, 2.2))
	# Wide hairpin stays collision-heavy enough for Elephant Stampede body battles.
	_add_static_box("HairpinIsland", ROUTE_POINTS[19] + Vector3(6.0, 1.4, -3.0), Vector3(4.2, 2.8, 4.2))
	# Cat's late technical section rewards precise Shadow Step without making it mandatory.
	_add_static_box("FinalChicaneA", ROUTE_POINTS[27] + Vector3(-3.3, 0.8, 7.0), Vector3(2.2, 1.6, 3.0))
	_add_static_box("FinalChicaneB", ROUTE_POINTS[27] + Vector3(3.3, 0.8, -5.0), Vector3(2.2, 1.6, 3.0))

func _add_static_box(node_name: String, world_position: Vector3, size: Vector3) -> void:
	var obstacle := CSGBox3D.new()
	obstacle.name = node_name
	obstacle.position = world_position
	obstacle.size = size
	obstacle.use_collision = true
	obstacle.visible = false
	_collision_root.add_child(obstacle)

func _build_dynamic_obstacles() -> void:
	_add_dynamic_box(
		"RotatingSweeper", ROUTE_POINTS[6] + Vector3.UP * 1.0, Vector3(10.0, 0.65, 0.8),
		WildDashDynamicObstacle.MotionType.ROTATE, 1.35, 0.0
	)
	# Three staggered gates create a readable timing section rather than a wall.
	_add_dynamic_box(
		"MovingGateA", ROUTE_POINTS[16] + Vector3.UP * 1.1, Vector3(3.2, 2.2, 0.9),
		WildDashDynamicObstacle.MotionType.SWEEP, 1.15, 5.2
	)
	_add_dynamic_box(
		"MovingGateB", ROUTE_POINTS[17] + Vector3.UP * 1.1, Vector3(3.6, 2.4, 0.9),
		WildDashDynamicObstacle.MotionType.SWEEP, 1.30, 6.0
	)
	_add_dynamic_box(
		"MovingGateC", ROUTE_POINTS[18] + Vector3.UP * 1.0, Vector3(3.0, 2.0, 0.9),
		WildDashDynamicObstacle.MotionType.SWEEP, 1.45, 4.8
	)

func _add_dynamic_box(
	node_name: String,
	world_position: Vector3,
	size: Vector3,
	motion: WildDashDynamicObstacle.MotionType,
	speed: float,
	amplitude: float
) -> void:
	var body := WildDashDynamicObstacle.new()
	body.name = node_name
	body.position = world_position
	body.motion_type = motion
	body.motion_speed = speed
	body.amplitude = amplitude
	body.collision_layer = 1
	body.collision_mask = 2
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MechanicalVisual"
	mesh_instance.mesh = _build_dynamic_obstacle_mesh(size, motion)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "GameplayCollision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_collision_root.add_child(body)

func _build_dynamic_obstacle_mesh(
	size: Vector3,
	motion: WildDashDynamicObstacle.MotionType
) -> ArrayMesh:
	var result := ArrayMesh.new()
	var body_transforms: Array[Transform3D] = []
	var warning_transforms: Array[Transform3D] = []
	var metal_transforms: Array[Transform3D] = []
	body_transforms.append(_local_box_transform(Vector3.ZERO, size))
	if motion == WildDashDynamicObstacle.MotionType.ROTATE:
		metal_transforms.append(_local_box_transform(Vector3.ZERO, Vector3(0.85, 1.25, 1.35)))
		for side in [-1.0, 1.0]:
			metal_transforms.append(_local_box_transform(
				Vector3(side * size.x * 0.48, 0.0, 0.0), Vector3(0.48, size.y * 1.25, size.z * 1.3)
			))
		for stripe in range(5):
			warning_transforms.append(_local_box_transform(
				Vector3(-size.x * 0.32 + float(stripe) * size.x * 0.16, size.y * 0.52, 0.0),
				Vector3(size.x * 0.075, 0.07, size.z * 1.05),
				Vector3(0.0, 0.0, -0.55 if stripe % 2 == 0 else 0.55)
			))
	else:
		metal_transforms.append(_local_box_transform(
			Vector3(0.0, -size.y * 0.42, 0.0), Vector3(size.x * 1.18, 0.20, size.z * 1.35)
		))
		for stripe in range(4):
			warning_transforms.append(_local_box_transform(
				Vector3(-size.x * 0.32 + float(stripe) * size.x * 0.21, 0.0, size.z * 0.52),
				Vector3(size.x * 0.12, size.y * 0.82, 0.08),
				Vector3(0.0, 0.0, -0.48)
			))
	_append_box_surface(result, body_transforms, _obstacle_material)
	_append_box_surface(result, metal_transforms, _bridge_material)
	_append_box_surface(result, warning_transforms, _materials[&"curb_warning"])
	return result

func _append_box_surface(mesh: ArrayMesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var primitive := BoxMesh.new()
	primitive.size = Vector3.ONE
	var surface := SurfaceTool.new()
	surface.set_material(material)
	for transform in transforms:
		surface.append_from(primitive, 0, transform)
	surface.commit(mesh)

func _local_box_transform(
	position: Vector3,
	size: Vector3,
	rotation := Vector3.ZERO
) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation).scaled(size), position)

func _build_bridge_details() -> void:
	var first_midpoint := (ROUTE_POINTS[5] + ROUTE_POINTS[6]) * 0.5
	_add_visual_box(
		"BridgeRiver", Vector3(first_midpoint.x, -5.0, first_midpoint.z),
		Vector3(95, 0.3, 95), _water_material
	)
	var river_midpoint := (ROUTE_POINTS[14] + ROUTE_POINTS[15]) * 0.5
	_add_visual_box(
		"LongRiver", Vector3(river_midpoint.x, -28.0, river_midpoint.z),
		Vector3(140, 0.35, 125), _water_material
	)
	var structure_transforms: Array[Transform3D] = []
	var brace_transforms: Array[Transform3D] = []
	for bridge_data in [[5, -5.0], [14, -28.0]]:
		var index := int(bridge_data[0])
		var water_height := float(bridge_data[1])
		var a := ROUTE_POINTS[index]
		var b := ROUTE_POINTS[index + 1]
		var width := SEGMENT_WIDTHS[index]
		var length := a.distance_to(b)
		for side in [-1.0, 1.0]:
			structure_transforms.append(_track_transform_at(
				a, b, 0.5, side * (width * 0.5 - 0.35), -0.62,
				Vector3(0.55, 0.75, length)
			))
			structure_transforms.append(_track_transform_at(
				a, b, 0.5, side * width * 0.28, -0.92,
				Vector3(0.38, 0.42, length)
			))
		for support_index in range(3):
			var t := 0.2 + float(support_index) * 0.3
			var deck_height := a.lerp(b, t).y
			var support_height := maxf(2.0, deck_height - water_height - 0.4)
			for side in [-1.0, 1.0]:
				structure_transforms.append(_track_transform_at(
					a, b, t, side * width * 0.34, -support_height * 0.5,
					Vector3(0.58, support_height, 0.58)
				))
			var center := a.lerp(b, t)
			var direction := (b - a).normalized()
			var planar := Vector3(direction.x, 0.0, direction.z).normalized()
			var right := Vector3(-planar.z, 0.0, planar.x)
			var left_top := center - right * width * 0.34 + Vector3.DOWN * 0.7
			var right_low := center + right * width * 0.34 + Vector3.DOWN * (support_height - 0.4)
			var right_top := center + right * width * 0.34 + Vector3.DOWN * 0.7
			var left_low := center - right * width * 0.34 + Vector3.DOWN * (support_height - 0.4)
			brace_transforms.append(_beam_transform(left_top, right_low, 0.18))
			brace_transforms.append(_beam_transform(right_top, left_low, 0.18))
	_add_box_multimesh("BridgeStructure", structure_transforms, _bridge_material)
	_add_box_multimesh("BridgeCrossBraces", brace_transforms, _materials[&"curb_warning"])

func _beam_transform(from: Vector3, to: Vector3, thickness: float) -> Transform3D:
	var midpoint := (from + to) * 0.5
	var transform := Transform3D(Basis.IDENTITY, midpoint)
	transform = transform.looking_at(to, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(thickness, thickness, from.distance_to(to)))
	return transform

func _build_canyon_section() -> void:
	# Low-sided tapered columns read as layered rock instead of stacked boxes.
	# They are visual-only; the existing hidden rails remain the gameplay boundary.
	var cliff_mesh := CylinderMesh.new()
	cliff_mesh.top_radius = 0.68
	cliff_mesh.bottom_radius = 1.0
	cliff_mesh.height = 1.0
	cliff_mesh.radial_segments = 6
	cliff_mesh.rings = 1
	var cliff_multimesh := MultiMesh.new()
	cliff_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cliff_multimesh.mesh = cliff_mesh
	cliff_multimesh.instance_count = 28
	for i in range(cliff_multimesh.instance_count):
		var anchor_index := 7 + (i % 7)
		var anchor := ROUTE_POINTS[anchor_index]
		var side := -1.0 if i % 2 == 0 else 1.0
		var width_scale := 5.2 + float((i * 5) % 7) * 0.72
		var depth_scale := 4.5 + float((i * 3) % 6) * 0.66
		var height_scale := 9.0 + float((i * 7) % 9) * 1.35
		var rotation := float((i * 37) % 180) * PI / 180.0
		var basis := Basis(Vector3.UP, rotation).scaled(Vector3(width_scale, height_scale, depth_scale))
		var lateral := side * (15.0 + float(i % 4) * 4.2)
		var along_offset := float((i % 5) - 2) * 4.5
		var cliff_direction := _route_direction(anchor_index)
		var cliff_right := Vector3(-cliff_direction.z, 0.0, cliff_direction.x)
		var position := anchor + cliff_right * lateral + cliff_direction * along_offset + Vector3.UP * (height_scale * 0.42 - 2.0)
		cliff_multimesh.set_instance_transform(i, Transform3D(basis, position))
	var cliffs := MultiMeshInstance3D.new()
	cliffs.name = "CanyonLayeredCliffs"
	cliffs.multimesh = cliff_multimesh
	cliffs.material_override = _rock_material
	_decoration_root.add_child(cliffs)

	var outcrop_mesh := SphereMesh.new()
	outcrop_mesh.radius = 1.0
	outcrop_mesh.height = 2.0
	outcrop_mesh.radial_segments = 7
	outcrop_mesh.rings = 4
	var outcrop_transforms: Array[Transform3D] = []
	for i in range(34):
		var anchor_index := 7 + (i % 7)
		var anchor := ROUTE_POINTS[anchor_index]
		var side := -1.0 if i % 2 == 0 else 1.0
		var scale := Vector3(
			1.0 + float((i * 3) % 5) * 0.35,
			0.65 + float((i * 7) % 4) * 0.26,
			1.15 + float((i * 5) % 6) * 0.31
		)
		var basis := Basis(Vector3.UP, float(i) * 0.63).scaled(scale)
		var road_edge := SEGMENT_WIDTHS[min(anchor_index, SEGMENT_WIDTHS.size() - 1)] * 0.5
		var distance := road_edge + 1.6 + float(i % 4) * 4.1
		var outcrop_direction := _route_direction(anchor_index)
		var outcrop_right := Vector3(-outcrop_direction.z, 0.0, outcrop_direction.x)
		var position := anchor + outcrop_right * side * distance + outcrop_direction * float((i % 5) - 2) * 3.8 + Vector3.UP * (0.1 + scale.y * 0.45)
		outcrop_transforms.append(Transform3D(basis, position))
	# Road-border stones share this visual-only rock batch so the Canyon reads
	# as Road -> Dusty Shoulder -> Rock Border without adding collision or nodes.
	outcrop_transforms.append_array(_road_rock_border_transforms)
	_add_mesh_multimesh("CanyonOutcropsAndLooseRock", outcrop_mesh, outcrop_transforms, _rock_material)

func _build_multi_jump() -> void:
	# Low hurdles make the normal jump viable while Rabbit can clear them with
	# Spring Leap and maintain more speed. They are intentionally not character locked.
	for i in range(3):
		var anchor_index := 21 + mini(i, 1)
		var a := ROUTE_POINTS[anchor_index]
		var b := ROUTE_POINTS[anchor_index + 1]
		var t := 0.28 + float(i) * 0.23
		var point := a.lerp(b, clampf(t, 0.15, 0.82))
		var tangent := b - a
		tangent.y = 0.0
		var hurdle := CSGBox3D.new()
		hurdle.name = "MultiJumpHurdle_%02d" % (i + 1)
		hurdle.size = Vector3(7.2, 0.65 + float(i) * 0.12, 0.85)
		hurdle.position = point + Vector3.UP * 0.22
		hurdle.use_collision = true
		hurdle.visible = false
		_collision_root.add_child(hurdle)
		hurdle.look_at(point + tangent.normalized() * 5.0 + Vector3.UP * 0.22, Vector3.UP)

func _build_tunnel() -> void:
	var a := ROUTE_POINTS[25]
	var b := ROUTE_POINTS[26]
	var midpoint := (a + b) * 0.5
	var planar := b - a
	planar.y = 0.0
	var direction := planar.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x)
	var length := a.distance_to(b)
	for side in [-1.0, 1.0]:
		var wall := CSGBox3D.new()
		wall.name = "TunnelWall_%s" % ("L" if side < 0.0 else "R")
		wall.size = Vector3(0.6, 5.0, length)
		wall.position = midpoint + right * 6.0 * side + Vector3.UP * 2.0
		wall.use_collision = true
		wall.visible = false
		_collision_root.add_child(wall)
		wall.look_at(b + right * 6.0 * side + Vector3.UP * 2.0, Vector3.UP)
	var roof := CSGBox3D.new()
	roof.name = "TunnelRoof"
	roof.size = Vector3(12.5, 0.6, length)
	roof.position = midpoint + Vector3.UP * 4.6
	roof.use_collision = true
	roof.visible = false
	_collision_root.add_child(roof)
	roof.look_at(b + Vector3.UP * 4.6, Vector3.UP)

	var wall_panel_transforms: Array[Transform3D] = []
	var ceiling_panel_transforms: Array[Transform3D] = []
	var support_transforms: Array[Transform3D] = []
	var light_transforms: Array[Transform3D] = []
	var edge_marking_transforms: Array[Transform3D] = []
	var exit_glow_transforms: Array[Transform3D] = []
	var panel_count := 8
	for panel_index in range(panel_count):
		var t := (float(panel_index) + 0.5) / float(panel_count)
		ceiling_panel_transforms.append(_track_transform_at(
			a, b, t, 0.0, 4.58,
			Vector3(12.0, 0.34, length / float(panel_count) * 0.91)
		))
		for side in [-1.0, 1.0]:
			wall_panel_transforms.append(_track_transform_at(
				a, b, t, side * 6.0, 2.0,
				Vector3(0.38, 4.7, length / float(panel_count) * 0.91)
			))
			edge_marking_transforms.append(_track_transform_at(
				a, b, t, side * 5.68, 0.22,
				Vector3(0.22, 0.28, length / float(panel_count) * 0.70)
			))
		if panel_index % 2 == 0:
			support_transforms.append(_track_transform_at(
				a, b, t, 0.0, 4.48, Vector3(12.4, 0.36, 0.42)
			))
		for side in [-1.0, 1.0]:
			light_transforms.append(_track_transform_at(
				a, b, t, side * 4.35, 4.18, Vector3(0.34, 0.10, 1.35)
			))
	for portal_t in [0.015, 0.985]:
		for side in [-1.0, 1.0]:
			support_transforms.append(_track_transform_at(
				a, b, portal_t, side * 5.75, 2.1, Vector3(0.78, 4.8, 0.78)
			))
		support_transforms.append(_track_transform_at(
			a, b, portal_t, 0.0, 4.65, Vector3(12.4, 0.72, 0.78)
		))
	exit_glow_transforms.append(_track_transform_at(
		a, b, 0.975, 0.0, 4.08, Vector3(9.6, 0.12, 0.26)
	))
	_add_box_multimesh("TunnelWallSegments", wall_panel_transforms, _tunnel_material)
	_add_box_multimesh("TunnelCeilingPanels", ceiling_panel_transforms, _tunnel_material)
	_add_box_multimesh("TunnelFramesAndCeilingSupports", support_transforms, _materials[&"bridge"])
	_add_box_multimesh("TunnelGuideLights", light_transforms, _materials[&"tunnel_light"])
	_add_box_multimesh("TunnelEdgeMarkings", edge_marking_transforms, _materials[&"curb_warning"])
	_add_box_multimesh("TunnelExitGlow", exit_glow_transforms, _materials[&"tunnel_light"])

func _build_shortcuts() -> void:
	var a_entry := ROUTE_POINTS[SHORTCUT_A_ENTRY_ROUTE_INDEX]
	var a_exit := ROUTE_POINTS[SHORTCUT_A_EXIT_ROUTE_INDEX]
	_create_segment("ShortcutA_RiskyMid", a_entry, a_exit, 6.2, 0.42, _shortcut_material, true, -0.18, &"shortcut")
	_add_dynamic_box(
		"ShortcutASweeper", (a_entry + a_exit) * 0.5 + Vector3.UP * 0.8,
		Vector3(5.0, 0.55, 0.7), WildDashDynamicObstacle.MotionType.ROTATE, 1.8, 0.0
	)

	var b_entry := ROUTE_POINTS[SHORTCUT_B_ENTRY_ROUTE_INDEX]
	var b_exit := ROUTE_POINTS[SHORTCUT_B_EXIT_ROUTE_INDEX]
	_create_segment("ShortcutB_ComebackLine", b_entry, b_exit, 5.8, 0.42, _shortcut_material, true, -0.18, &"shortcut")
	# A low hurdle keeps the second shortcut skill/item-friendly rather than Rabbit-only.
	var midpoint := (b_entry + b_exit) * 0.5
	_add_static_box("ShortcutBJumpBlock", midpoint + Vector3.UP * 0.45, Vector3(4.5, 0.9, 1.0))
	_add_box_multimesh("RoadSurface_Shortcuts", _road_visual_batches[&"shortcut"], _dirt_material)

func _build_forest_dressing() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.36
	trunk_mesh.bottom_radius = 0.58
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 7
	trunk_mesh.rings = 1
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	var far_crown_transforms: Array[Transform3D] = []
	var bush_transforms: Array[Transform3D] = []
	var forest_rock_transforms: Array[Transform3D] = []
	var log_transforms: Array[Transform3D] = []
	for i in range(18):
		var anchor_index := 2 + (i % 3)
		var anchor := ROUTE_POINTS[anchor_index]
		var side := -1.0 if i % 2 == 0 else 1.0
		var road_edge := SEGMENT_WIDTHS[anchor_index] * 0.5
		var distance := road_edge + 4.0 + float((i * 5) % 5) * 2.0
		var along_offset := float((i * 7) % 11 - 5) * 5.2
		var route_direction := _route_direction(anchor_index)
		var route_right := Vector3(-route_direction.z, 0.0, route_direction.x)
		var base_position := anchor + route_right * side * distance + route_direction * along_offset
		var height := 4.6 + float((i * 3) % 6) * 0.55
		var thickness := 0.72 + float((i * 7) % 4) * 0.11
		var rotation := float((i * 43) % 180) * PI / 180.0
		var trunk_basis := Basis(Vector3.UP, rotation).scaled(Vector3(thickness, height, thickness))
		trunk_transforms.append(Transform3D(trunk_basis, base_position + Vector3.UP * height * 0.5))
		var far_scale := Vector3(2.15 + float(i % 3) * 0.20, 1.75 + float(i % 2) * 0.18, 2.05 + float((i * 2) % 3) * 0.17)
		far_crown_transforms.append(Transform3D(
			Basis(Vector3.UP, rotation).scaled(far_scale),
			base_position + Vector3.UP * height * 0.84
		))
		for cluster_index in range(3):
			var cluster_angle := rotation + float(cluster_index) * TAU / 3.0
			var cluster_offset := Vector3(cos(cluster_angle), 0.0, sin(cluster_angle)) * (0.65 + float(i % 3) * 0.13)
			var cluster_scale := Vector3(
				1.7 + float((i + cluster_index) % 4) * 0.22,
				1.25 + float((i * 2 + cluster_index) % 3) * 0.20,
				1.55 + float((i * 3 + cluster_index) % 4) * 0.18
			)
			var crown_basis := Basis(Vector3.UP, cluster_angle).scaled(cluster_scale)
			var crown_height := height * (0.73 + float(cluster_index) * 0.10)
			crown_transforms.append(Transform3D(
				crown_basis, base_position + cluster_offset + Vector3.UP * crown_height
			))
		if i < 12:
			var bush_scale := Vector3(1.1 + float(i % 3) * 0.25, 0.55 + float(i % 2) * 0.16, 0.9 + float((i * 3) % 4) * 0.18)
			var bush_position := base_position + Vector3(side * 1.8, bush_scale.y * 0.55, float((i % 3) - 1) * 1.6)
			bush_transforms.append(Transform3D(Basis.IDENTITY.scaled(bush_scale), bush_position))
		if i < 10:
			var rock_scale := Vector3(0.45 + float(i % 3) * 0.2, 0.28 + float(i % 2) * 0.12, 0.55 + float((i * 2) % 3) * 0.16)
			forest_rock_transforms.append(Transform3D(
				Basis(Vector3.UP, rotation).scaled(rock_scale),
				base_position + Vector3(-side * 2.1, rock_scale.y * 0.45, float(i % 2) * 2.0)
			))
		if i < 4:
			var log_basis := Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, rotation).scaled(Vector3(0.55, 3.0, 0.55))
			log_transforms.append(Transform3D(log_basis, base_position + Vector3(side * 2.5, 0.42, -2.2)))
	_add_mesh_multimesh("ForestTrunks", trunk_mesh, trunk_transforms, _wood_material)
	_add_mesh_multimesh("ForestCrownClusters", crown_mesh, crown_transforms, _materials[&"foliage"])
	var far_crown_mesh := SphereMesh.new()
	far_crown_mesh.radius = 1.0
	far_crown_mesh.height = 2.0
	far_crown_mesh.radial_segments = 6
	far_crown_mesh.rings = 3
	_add_mesh_multimesh("ForestFarCanopies", far_crown_mesh, far_crown_transforms, _materials[&"foliage"])
	_add_mesh_multimesh("ForestBushes", crown_mesh, bush_transforms, _materials[&"foliage_light"])
	_add_mesh_multimesh("ForestFloorRocks", crown_mesh, forest_rock_transforms, _rock_material)
	_add_mesh_multimesh("ForestFallenLogs", trunk_mesh, log_transforms, _wood_material)

func _add_mesh_multimesh(
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material
) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	_decoration_root.add_child(instance)

func _route_direction(route_index: int) -> Vector3:
	var previous := ROUTE_POINTS[maxi(0, route_index - 1)]
	var next := ROUTE_POINTS[mini(ROUTE_POINTS.size() - 1, route_index + 1)]
	var direction := next - previous
	direction.y = 0.0
	return direction.normalized()

func _build_environment_pass_2() -> void:
	var structural: Array[Transform3D] = []
	var warnings: Array[Transform3D] = []
	var event_details: Array[Transform3D] = []
	var wood_props: Array[Transform3D] = []
	var dirt_banks: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	var wet_rocks: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var round_props: Array[Transform3D] = []

	# River banks sit at water level, well below the bridge driving deck.
	for bridge_data in [[5, -5.0, 42.0], [14, -28.0, 58.0]]:
		var route_index := int(bridge_data[0])
		var water_height := float(bridge_data[1])
		var bank_offset := float(bridge_data[2])
		var a := ROUTE_POINTS[route_index]
		var b := ROUTE_POINTS[route_index + 1]
		var direction := _route_direction(route_index)
		var right := Vector3(-direction.z, 0.0, direction.x)
		var river_center := (a + b) * 0.5
		var crossing_length := a.distance_to(b) + 36.0
		for side in [-1.0, 1.0]:
			var bank_position: Vector3 = Vector3(river_center.x, water_height + 0.16, river_center.z) + right * side * bank_offset
			var bank_transform := Transform3D(Basis.IDENTITY, bank_position)
			bank_transform = bank_transform.looking_at(bank_position + direction, Vector3.UP)
			bank_transform.basis = bank_transform.basis.scaled(Vector3(13.0, 0.55, crossing_length))
			dirt_banks.append(bank_transform)
			for reed_index in range(8):
				var along := (float(reed_index) - 3.5) * crossing_length / 9.0
				var reed_position: Vector3 = bank_position + direction * along - right * side * (4.5 + float(reed_index % 3))
				reeds.append(_local_box_transform(
					reed_position + Vector3.UP * (0.65 + float(reed_index % 2) * 0.18),
					Vector3(0.12, 1.3 + float(reed_index % 2) * 0.36, 0.12),
					Vector3(0.0, float(reed_index) * 0.47, 0.08 * side)
				))
		for rock_index in range(14):
			var rock_side := -1.0 if rock_index % 2 == 0 else 1.0
			var rock_position := Vector3(river_center.x, water_height + 0.38, river_center.z)
			rock_position += right * rock_side * (bank_offset - 6.0 - float(rock_index % 4) * 2.4)
			rock_position += direction * (float(rock_index) - 6.5) * crossing_length / 17.0
			var rock_scale := Vector3(1.1 + float(rock_index % 3) * 0.42, 0.55 + float(rock_index % 2) * 0.24, 1.3 + float((rock_index * 2) % 4) * 0.33)
			wet_rocks.append(Transform3D(Basis(Vector3.UP, float(rock_index) * 0.61).scaled(rock_scale), rock_position))

	# Preserve the authored river-approach safety rail silhouette as visual-only metalwork.
	structural.append(_local_box_transform(Vector3(-27.5854, -21.85, -875.1141), Vector3(0.35, 1.35, 77.2593), Vector3(-0.03884, 0.63832, 0.0)))
	structural.append(_local_box_transform(Vector3(-14.4146, -21.85, -884.8859), Vector3(0.35, 1.35, 77.2593), Vector3(-0.03884, 0.63832, 0.0)))

	# Static obstacle collision remains unchanged and hidden; these compound forms carry no collision.
	wood_props.append(_local_box_transform(ROUTE_POINTS[3] + Vector3(3.2, 1.0, 0), Vector3(2.4, 2.0, 2.4), Vector3(0.0, 0.28, 0.0)))
	wood_props.append(_local_box_transform(ROUTE_POINTS[3] + Vector3(-3.0, 0.8, -12), Vector3(2.0, 1.6, 3.0), Vector3(0.0, -0.22, 0.0)))
	structural.append(_local_box_transform(ROUTE_POINTS[6] + Vector3(-4.0, 0.9, 2.0), Vector3(2.4, 1.8, 2.4), Vector3(0.0, 0.18, 0.0)))
	structural.append(_local_box_transform(ROUTE_POINTS[6] + Vector3(3.6, 0.7, -8.0), Vector3(3.0, 1.4, 2.2), Vector3(0.0, -0.31, 0.0)))
	rocks.append(Transform3D(Basis(Vector3.UP, 0.41).scaled(Vector3(3.2, 1.8, 3.0)), ROUTE_POINTS[19] + Vector3(6.0, 1.25, -3.0)))
	for final_offset in [Vector3(-3.3, 0.8, 7.0), Vector3(3.3, 0.8, -5.0)]:
		structural.append(_local_box_transform(ROUTE_POINTS[27] + final_offset, Vector3(2.2, 1.6, 3.0)))
		warnings.append(_local_box_transform(ROUTE_POINTS[27] + final_offset + Vector3.UP * 0.84, Vector3(2.28, 0.14, 3.08)))
	wood_props.append(_local_box_transform((ROUTE_POINTS[23] + ROUTE_POINTS[25]) * 0.5 + Vector3.UP * 0.45, Vector3(4.5, 0.9, 1.0)))

	# Stationary frames make all three moving gates legible while their moving collision timing stays untouched.
	for gate_index in [16, 17, 18]:
		var gate_width := SEGMENT_WIDTHS[min(gate_index, SEGMENT_WIDTHS.size() - 1)]
		var gate_a := ROUTE_POINTS[gate_index - 1]
		var gate_b := ROUTE_POINTS[gate_index]
		for side in [-1.0, 1.0]:
			structural.append(_track_transform_at(gate_a, gate_b, 1.0, side * gate_width * 0.43, 2.35, Vector3(0.48, 4.7, 0.48)))
			warnings.append(_track_transform_at(gate_a, gate_b, 1.0, side * gate_width * 0.43, 4.65, Vector3(0.68, 0.32, 0.68)))
		structural.append(_track_transform_at(gate_a, gate_b, 1.0, 0.0, 4.55, Vector3(gate_width * 0.88, 0.42, 0.50)))
		structural.append(_track_transform_at(gate_a, gate_b, 1.0, 0.0, 0.18, Vector3(gate_width * 0.76, 0.16, 1.15)))

	# Main ramp and multi-jump dressing. Collision transforms and jump physics are not modified.
	warnings.append(_local_box_transform(Vector3(-31.9, 6.3, -228.8), Vector3(7.0, 0.50, 8.0), Vector3(0.16, -0.745, 0.0)))
	for side in [-1.0, 1.0]:
		structural.append(_local_box_transform(Vector3(-31.9, 5.78, -228.8) + Vector3(side * 2.9, 0.0, 0.0), Vector3(0.38, 0.85, 7.4), Vector3(0.16, -0.745, 0.0)))
	for arrow_index in range(3):
		event_details.append(_local_box_transform(Vector3(-31.9, 6.63, -227.4 - float(arrow_index) * 1.8), Vector3(2.2, 0.06, 0.34), Vector3(0.16, -0.745, 0.0)))
	for jump_index in range(3):
		var anchor_index := 21 + mini(jump_index, 1)
		var jump_a := ROUTE_POINTS[anchor_index]
		var jump_b := ROUTE_POINTS[anchor_index + 1]
		var jump_t := clampf(0.28 + float(jump_index) * 0.23, 0.15, 0.82)
		var jump_height := 0.65 + float(jump_index) * 0.12
		warnings.append(_track_transform_at(jump_a, jump_b, jump_t, 0.0, 0.22, Vector3(7.2, jump_height, 0.85)))
		for side in [-1.0, 1.0]:
			structural.append(_track_transform_at(jump_a, jump_b, jump_t, side * 3.25, 0.10, Vector3(0.32, jump_height + 0.25, 1.25)))
		event_details.append(_track_transform_at(jump_a, jump_b, maxf(0.12, jump_t - 0.08), 0.0, 0.12, Vector3(2.6, 0.06, 0.38)))

	# Shortcut entrances use restrained signs, broken fence rhythm, dirt banks, and rock gaps.
	for shortcut_index in [SHORTCUT_A_ENTRY_ROUTE_INDEX, SHORTCUT_B_ENTRY_ROUTE_INDEX]:
		var shortcut_a := ROUTE_POINTS[shortcut_index - 1]
		var shortcut_b := ROUTE_POINTS[shortcut_index]
		var shortcut_width := SEGMENT_WIDTHS[min(shortcut_index, SEGMENT_WIDTHS.size() - 1)]
		for side in [-1.0, 1.0]:
			wood_props.append(_track_transform_at(shortcut_a, shortcut_b, 1.0, side * (shortcut_width * 0.33), 0.75, Vector3(0.22, 1.5, 0.22)))
			event_details.append(_track_transform_at(shortcut_a, shortcut_b, 1.0, side * (shortcut_width * 0.33), 1.42, Vector3(1.15, 0.52, 0.12)))
			rocks.append(Transform3D(Basis(Vector3.UP, side * 0.36).scaled(Vector3(1.25, 0.75, 1.4)), shortcut_b + Vector3(side * shortcut_width * 0.46, 0.65, -2.0)))

	# Final straight gains stronger event rhythm while the visible stripe stays aligned to finish detection.
	var finish := ROUTE_POINTS[ROUTE_POINTS.size() - 1]
	var finish_previous := ROUTE_POINTS[ROUTE_POINTS.size() - 2]
	var finish_width := SEGMENT_WIDTHS[SEGMENT_WIDTHS.size() - 1]
	for side in [-1.0, 1.0]:
		structural.append(_track_transform_at(finish_previous, finish, 1.0, side * finish_width * 0.46, 2.65, Vector3(0.72, 5.3, 0.72)))
		event_details.append(_track_transform_at(finish_previous, finish, 0.70, side * finish_width * 0.47, 0.72, Vector3(0.52, 1.45, 7.0)))
		warnings.append(_track_transform_at(finish_previous, finish, 0.83, side * finish_width * 0.40, 1.65, Vector3(0.16, 3.3, 0.62)))
	structural.append(_track_transform_at(finish_previous, finish, 1.0, 0.0, 5.15, Vector3(finish_width * 0.94, 0.62, 0.72)))
	for checker in range(10):
		var checker_side := -finish_width * 0.42 + float(checker) * finish_width * 0.84 / 9.0
		var checker_transform := _track_transform_at(finish_previous, finish, 1.0, checker_side, 5.17, Vector3(finish_width * 0.075, 0.66, 0.76))
		if checker % 2 == 0:
			warnings.append(checker_transform)
		else:
			event_details.append(checker_transform)
	for approach_index in range(4):
		event_details.append(_track_transform_at(finish_previous, finish, 0.28 + float(approach_index) * 0.16, 0.0, 0.12, Vector3(3.8, 0.06, 0.46)))

	# Sparse trackside signs, posts, crate stacks, and cones reinforce zone identity without hiding racers.
	for prop_data in [[1, -1.0], [6, 1.0], [12, -1.0], [20, 1.0], [27, -1.0]]:
		var prop_index := int(prop_data[0])
		var prop_side := float(prop_data[1])
		var prop_a := ROUTE_POINTS[prop_index]
		var prop_b := ROUTE_POINTS[prop_index + 1]
		var prop_width := SEGMENT_WIDTHS[prop_index]
		structural.append(_track_transform_at(prop_a, prop_b, 0.52, prop_side * (prop_width * 0.5 + 2.3), 1.25, Vector3(0.22, 2.5, 0.22)))
		event_details.append(_track_transform_at(prop_a, prop_b, 0.52, prop_side * (prop_width * 0.5 + 2.3), 2.22, Vector3(1.7, 0.72, 0.16)))
		for cone_index in range(2):
			round_props.append(_track_transform_at(
				prop_a, prop_b, 0.42 + float(cone_index) * 0.19,
				prop_side * (prop_width * 0.5 + 0.85), 0.32,
				Vector3(0.82 + float(cone_index) * 0.08, 0.64 + float(cone_index) * 0.07, 0.82 + float(cone_index) * 0.08)
			))

	_append_box_multimesh("RoadSurface_Shortcuts", dirt_banks)
	_append_box_multimesh("GrassShoulders", reeds)
	_append_box_multimesh("WoodStructuresAndProps", wood_props)
	_append_mesh_multimesh("CanyonOutcropsAndLooseRock", rocks)
	_add_box_multimesh("EnvironmentStructuralProps", structural, _bridge_material)
	_add_box_multimesh("EnvironmentWarningDetails", warnings, _materials[&"hazard"])
	_add_box_multimesh("EnvironmentEventDetails", event_details, _materials[&"event_blue"])
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.14
	cone_mesh.bottom_radius = 0.38
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 7
	cone_mesh.rings = 1
	_add_mesh_multimesh("TracksideRoundProps", cone_mesh, round_props, _materials[&"hazard"])
	var wet_rock_mesh := SphereMesh.new()
	wet_rock_mesh.radius = 1.0
	wet_rock_mesh.height = 2.0
	wet_rock_mesh.radial_segments = 7
	wet_rock_mesh.rings = 4
	_add_mesh_multimesh("RiverWetRockAccents", wet_rock_mesh, wet_rocks, _materials[&"wet_rock"])

func _append_box_multimesh(node_name: String, transforms: Array[Transform3D]) -> void:
	_append_multimesh_transforms(node_name, transforms)

func _append_mesh_multimesh(node_name: String, transforms: Array[Transform3D]) -> void:
	_append_multimesh_transforms(node_name, transforms)

func _append_multimesh_transforms(node_name: String, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var instance := _decoration_root.get_node_or_null(node_name) as MultiMeshInstance3D
	if instance == null or instance.multimesh == null:
		push_warning("Missing environment batch: %s" % node_name)
		return
	var multimesh := instance.multimesh
	var previous: Array[Transform3D] = []
	for index in range(multimesh.instance_count):
		previous.append(multimesh.get_instance_transform(index))
	multimesh.instance_count = previous.size() + transforms.size()
	for index in range(previous.size()):
		multimesh.set_instance_transform(index, previous[index])
	for index in range(transforms.size()):
		multimesh.set_instance_transform(previous.size() + index, transforms[index])

func _build_environment_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "GrandPrixWorldEnvironment"
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("5c8fc2")
	sky_material.sky_horizon_color = Color("c8dce5")
	sky_material.ground_bottom_color = Color("33484b")
	sky_material.ground_horizon_color = Color("b5c5b3")
	sky_material.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.82
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("b9cbd4")
	environment.ambient_light_energy = 0.68
	environment.ambient_light_sky_contribution = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.04
	environment.fog_enabled = true
	environment.fog_light_color = Color("b9ced4")
	environment.fog_light_energy = 0.46
	environment.fog_density = 0.0016
	environment.fog_height = -35.0
	environment.fog_height_density = 0.018
	environment.fog_aerial_perspective = 0.22
	# The project uses gl_compatibility; SSAO is intentionally left disabled.
	environment.ssao_enabled = false
	world_environment.environment = environment
	add_child(world_environment)

	var parent_sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if parent_sun != null:
		parent_sun.light_color = Color("fff0d8")
		parent_sun.light_energy = 1.08
		parent_sun.shadow_opacity = 0.72
		parent_sun.directional_shadow_max_distance = 155.0

func _configure_environment_lod_and_visibility() -> void:
	_set_visibility_range("ForestTrunks", 0.0, 235.0)
	_set_visibility_range("ForestCrownClusters", 0.0, 235.0)
	_set_visibility_range("ForestFarCanopies", 175.0, 520.0)
	_set_visibility_range("ForestBushes", 0.0, 115.0)
	_set_visibility_range("ForestFloorRocks", 0.0, 95.0)
	_set_visibility_range("ForestFallenLogs", 0.0, 130.0)
	_set_visibility_range("CanyonOutcropsAndLooseRock", 0.0, 270.0)
	_set_visibility_range("CanyonLayeredCliffs", 0.0, 680.0)
	_set_visibility_range("BridgeCrossBraces", 0.0, 260.0)
	_set_visibility_range("BridgeStructure", 0.0, 520.0)
	_set_visibility_range("TunnelWallSegments", 0.0, 300.0)
	_set_visibility_range("TunnelCeilingPanels", 0.0, 300.0)
	_set_visibility_range("TunnelGuideLights", 0.0, 260.0)
	_set_visibility_range("EnvironmentStructuralProps", 0.0, 310.0)
	_set_visibility_range("EnvironmentWarningDetails", 0.0, 260.0)
	_set_visibility_range("EnvironmentEventDetails", 0.0, 360.0)
	_set_visibility_range("TracksideRoundProps", 0.0, 170.0)
	_set_visibility_range("RoadDirectionArrows", 0.0, 360.0)
	_set_visibility_range("TracksideDirectionGuides", 0.0, 420.0)
	_set_visibility_range("RiverWetRockAccents", 0.0, 260.0)
	_set_visibility_range("BridgeRiver", 0.0, 760.0)
	_set_visibility_range("LongRiver", 0.0, 760.0)

func _set_visibility_range(node_name: String, begin: float, end: float) -> void:
	var geometry := _decoration_root.get_node_or_null(node_name) as GeometryInstance3D
	if geometry == null:
		return
	geometry.visibility_range_begin = begin
	geometry.visibility_range_end = end
	geometry.visibility_range_begin_margin = 25.0 if begin > 0.0 else 0.0
	geometry.visibility_range_end_margin = 35.0
	geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	geometry.extra_cull_margin = 4.0

func _add_visual_box(node_name: String, world_position: Vector3, size: Vector3, material: Material) -> void:
	var visual := CSGBox3D.new()
	visual.name = node_name
	visual.position = world_position
	visual.size = size
	visual.use_collision = false
	visual.material = material
	_decoration_root.add_child(visual)

func _shortcut_saving(entry_index: int, skip_index: int, exit_index: int) -> float:
	var entry := ROUTE_POINTS[entry_index]
	var detour := ROUTE_POINTS[skip_index]
	var exit := ROUTE_POINTS[exit_index]
	var safe_distance := entry.distance_to(detour) + detour.distance_to(exit)
	var shortcut_distance := entry.distance_to(exit)
	return maxf(0.0, safe_distance - shortcut_distance)

func _count_nodes_recursive(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes_recursive(child)
	return total

func _make_material(color: Color, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color * 0.4
	return material
