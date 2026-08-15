class_name WildDashGrandPrixV4EnvironmentDressing
extends Node3D

## Round 1 V4.2 environment dressing.
## Adds batched low-poly biome landmarks outside playable terrain so the course
## reads as a real countryside / forest / river / mountain world instead of a
## road surrounded by empty sky. Gameplay collision remains owned by V3.x land.

const TREE_SECTIONS: Array[StringName] = [
	&"meadow_start",
	&"forest_obstacle",
	&"long_river",
	&"mountain_approach",
	&"rough_descent",
	&"final_sprint",
]
const HOUSE_SECTIONS: Array[StringName] = [
	&"meadow_start",
	&"long_river",
	&"final_sprint",
]
const MOUNTAIN_SECTIONS: Array[StringName] = [
	&"mountain_approach",
	&"mountain_ascent",
	&"summit_ridge",
	&"rough_descent",
]

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _root: Node3D
var _tree_count: int = 0
var _house_count: int = 0
var _mountain_count: int = 0
var _rock_spire_count: int = 0

func _ready() -> void:
	process_priority = 132
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(16):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV4EnvironmentDressing: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return

	_root = Node3D.new()
	_root.name = "V42EnvironmentDressing"
	add_child(_root)

	_build_tree_batches()
	_build_house_batches()
	_build_mountain_batches()
	_build_canyon_spires()

	print("GRAND PRIX V4.2 ENVIRONMENT DRESSING READY trees=%d houses=%d mountain_peaks=%d canyon_spires=%d collision=false multimesh=true roadside_clear=true" % [
		_tree_count,
		_house_count,
		_mountain_count,
		_rock_spire_count,
	])

func _build_tree_batches() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	for section_id: StringName in TREE_SECTIONS:
		var count: int = _tree_target_count(section_id)
		for i: int in range(count):
			var t: float = (float(i) + 0.5) / float(maxi(1, count))
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var lateral: float = _tree_lateral(section_id, i)
			var pose: Dictionary = _sample_section_pose(section_id, t, side * lateral)
			if pose.is_empty():
				continue
			var base_pos: Vector3 = pose["position"] as Vector3
			var height: float = 3.8 + float((i * 7) % 9) * 0.24
			var width: float = 1.8 + float((i * 5) % 7) * 0.16
			if section_id == &"forest_obstacle":
				height *= 1.18
				width *= 1.12
			elif section_id == &"mountain_approach" or section_id == &"rough_descent":
				height *= 0.90
				width *= 0.92
			var yaw: float = float((i * 37) % 360) * PI / 180.0
			var basis := Basis(Vector3.UP, yaw)
			trunk_transforms.append(Transform3D(basis.scaled(Vector3(0.48, height * 0.48, 0.48)), base_pos + Vector3.UP * (height * 0.24)))
			crown_transforms.append(Transform3D(basis.scaled(Vector3(width, height * 0.58, width)), base_pos + Vector3.UP * (height * 0.72)))
			_tree_count += 1

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.30
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 6
	_add_multimesh("TreeTrunks", trunk_mesh, trunk_transforms, Color(0.22, 0.12, 0.055, 1.0))

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.9
	crown_mesh.height = 1.8
	crown_mesh.radial_segments = 7
	crown_mesh.rings = 4
	_add_multimesh("TreeCrowns", crown_mesh, crown_transforms, Color(0.18, 0.42, 0.15, 1.0))

func _build_house_batches() -> void:
	var body_transforms: Array[Transform3D] = []
	var roof_transforms: Array[Transform3D] = []
	for section_id: StringName in HOUSE_SECTIONS:
		var count: int = 8 if section_id == &"long_river" else 10
		for i: int in range(count):
			var t: float = (float(i) + 0.8) / float(count + 1)
			var side: float = -1.0 if (i + (1 if section_id == &"final_sprint" else 0)) % 2 == 0 else 1.0
			var lateral: float = 24.0 + float((i * 11) % 5) * 3.4
			if section_id == &"long_river":
				lateral += 7.0
			var pose: Dictionary = _sample_section_pose(section_id, t, side * lateral)
			if pose.is_empty():
				continue
			var pos: Vector3 = pose["position"] as Vector3
			var forward: Vector3 = pose["forward"] as Vector3
			var yaw: float = atan2(forward.x, forward.z) + (PI * 0.5 if i % 3 == 0 else 0.0)
			var basis := Basis(Vector3.UP, yaw)
			var sx: float = 2.6 + float(i % 3) * 0.7
			var sy: float = 2.2 + float((i + 1) % 2) * 0.7
			var sz: float = 2.4 + float((i + 2) % 3) * 0.45
			body_transforms.append(Transform3D(basis.scaled(Vector3(sx, sy, sz)), pos + Vector3.UP * sy))
			var roof_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, PI * 0.25)
			roof_transforms.append(Transform3D(roof_basis.scaled(Vector3(sx * 0.86, 0.38, sz * 0.86)), pos + Vector3.UP * (sy * 2.0 + 0.55)))
			_house_count += 1

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.0, 2.0, 2.0)
	_add_multimesh("FarmHouseBodies", body_mesh, body_transforms, Color(0.63, 0.52, 0.36, 1.0))
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(2.0, 0.42, 2.0)
	_add_multimesh("FarmHouseRoofs", roof_mesh, roof_transforms, Color(0.36, 0.14, 0.09, 1.0))

func _build_mountain_batches() -> void:
	var transforms: Array[Transform3D] = []
	for section_id: StringName in MOUNTAIN_SECTIONS:
		var count: int = 7 if section_id == &"mountain_ascent" else 5
		for i: int in range(count):
			var t: float = (float(i) + 0.45) / float(count)
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var lateral: float = 43.0 + float((i * 13) % 5) * 6.0
			var pose: Dictionary = _sample_section_pose(section_id, t, side * lateral)
			if pose.is_empty():
				continue
			var pos: Vector3 = pose["position"] as Vector3
			var peak_height: float = 18.0 + float((i * 7) % 6) * 4.2
			var radius: float = 13.0 + float((i * 5) % 5) * 3.5
			var yaw: float = float((i * 41) % 360) * PI / 180.0
			transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(radius, peak_height, radius)), pos + Vector3.UP * (peak_height * 0.47 - 1.5)))
			_mountain_count += 1

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 7
	_add_multimesh("MountainPeaks", mesh, transforms, Color(0.39, 0.32, 0.24, 1.0))

func _build_canyon_spires() -> void:
	var transforms: Array[Transform3D] = []
	var count := 12
	for i: int in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var lateral: float = 30.0 + float((i * 9) % 6) * 3.5
		var pose: Dictionary = _sample_section_pose(&"canyon_obstacle", t, side * lateral)
		if pose.is_empty():
			continue
		var pos: Vector3 = pose["position"] as Vector3
		var h: float = 8.0 + float((i * 5) % 5) * 2.2
		var r: float = 2.8 + float((i * 7) % 4) * 0.9
		transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r, h, r)), pos + Vector3.UP * (h * 0.46)))
		_rock_spire_count += 1
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.30
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 6
	_add_multimesh("CanyonRockSpires", mesh, transforms, Color(0.46, 0.26, 0.16, 1.0))

func _tree_target_count(section_id: StringName) -> int:
	match section_id:
		&"forest_obstacle": return 64
		&"meadow_start": return 28
		&"long_river": return 24
		&"mountain_approach": return 18
		&"rough_descent": return 20
		&"final_sprint": return 24
		_: return 12

func _tree_lateral(section_id: StringName, index: int) -> float:
	var base: float = 17.0
	match section_id:
		&"forest_obstacle": base = 14.5
		&"long_river": base = 25.0
		&"mountain_approach", &"rough_descent": base = 20.0
		&"final_sprint": base = 18.0
		_: base = 17.0
	return base + float((index * 11) % 8) * 2.2

func _sample_section_pose(section_id: StringName, progress: float, lateral: float) -> Dictionary:
	if not _ranges.has(section_id):
		return {}
	var section_range: Vector2i = _ranges[section_id] as Vector2i
	var start_segment: int = clampi(section_range.x, 0, _route.size() - 2)
	var end_segment: int = clampi(section_range.y, start_segment, _route.size() - 2)
	var segment_index: int = clampi(roundi(lerpf(float(start_segment), float(end_segment), clampf(progress, 0.0, 1.0))), start_segment, end_segment)
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var forward: Vector3 = b - a
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var center: Vector3 = a.lerp(b, 0.5)
	return {
		"position": center + right * lateral,
		"forward": forward,
		"segment_index": segment_index,
	}

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], color: Color) -> void:
	if transforms.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = transforms.size()
	multi.mesh = mesh
	for i: int in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(instance)

func _find_v2_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
