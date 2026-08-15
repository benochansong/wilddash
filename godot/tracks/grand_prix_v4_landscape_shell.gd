class_name WildDashGrandPrixV4LandscapeShell
extends Node3D

## Round 1 V4.0 mid/far landscape shell.
##
## V3.9 owns the playable/collidable terrain immediately outside the road.
## This node starts near the outer edge of that land and fills the camera-facing
## mid/far field with biome-specific low-poly terrain. Geometry is generated as
## disconnected per-segment wedges, then batched by biome into a small number of
## MeshInstances. This prevents switchbacks from creating giant triangles across
## the road while avoiding hundreds of draw calls.
##
## IMPORTANT: this shell is visual only. It never adds guardrails, invisible
## walls, or new gameplay collision. Off-road return and water re-entry remain
## owned by the existing V3 systems.

const SECTION_IDS: Array[StringName] = [
	&"meadow_start",
	&"forest_obstacle",
	&"long_river",
	&"mountain_approach",
	&"mountain_ascent",
	&"summit_ridge",
	&"rough_descent",
	&"canyon_obstacle",
	&"final_sprint",
]

# Distance from the shoulder edge to the outer landscape horizon.
const FAR_WIDTHS: Dictionary = {
	&"meadow_start": 58.0,
	&"forest_obstacle": 52.0,
	&"long_river": 50.0,
	&"mountain_approach": 58.0,
	&"mountain_ascent": 64.0,
	&"summit_ridge": 56.0,
	&"rough_descent": 58.0,
	&"canyon_obstacle": 46.0,
	&"final_sprint": 60.0,
}

# Start the far shell slightly inside the playable land outer edge to hide seams.
# River is the exception: leave a wider visual gap for the water/bank corridor.
const INNER_OFFSETS_FROM_PLAYABLE_EDGE: Dictionary = {
	&"meadow_start": -1.2,
	&"forest_obstacle": -1.0,
	&"long_river": 3.0,
	&"mountain_approach": -1.2,
	&"mountain_ascent": -1.2,
	&"summit_ridge": -1.0,
	&"rough_descent": -1.2,
	&"canyon_obstacle": -0.8,
	&"final_sprint": -1.2,
}

# Height profile relative to the route height: inner / middle / far horizon.
# Mountain/canyon values produce broad slopes, not vertical walls.
const HEIGHT_PROFILES: Dictionary = {
	&"meadow_start": Vector3(-0.10, 1.4, 3.4),
	&"forest_obstacle": Vector3(-0.10, 2.8, 6.0),
	&"long_river": Vector3(-0.75, 0.8, 4.4),
	&"mountain_approach": Vector3(5.8, 8.6, 12.0),
	&"mountain_ascent": Vector3(7.8, 11.8, 16.0),
	&"summit_ridge": Vector3(4.3, 7.8, 11.5),
	&"rough_descent": Vector3(5.8, 9.2, 13.0),
	&"canyon_obstacle": Vector3(7.8, 12.5, 17.0),
	&"final_sprint": Vector3(-0.10, 1.2, 3.2),
}

const HEIGHT_VARIATION: Dictionary = {
	&"meadow_start": 1.0,
	&"forest_obstacle": 1.8,
	&"long_river": 1.2,
	&"mountain_approach": 2.2,
	&"mountain_ascent": 2.8,
	&"summit_ridge": 2.2,
	&"rough_descent": 2.4,
	&"canyon_obstacle": 3.0,
	&"final_sprint": 0.8,
}

const SEGMENT_OVERLAP: float = 0.85
const MID_DISTANCE_RATIO: float = 0.52

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _playable_land: Node
var _landscape_root: Node3D
var _section_mesh_count: int = 0
var _triangle_count: int = 0

func _ready() -> void:
	process_priority = 129
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(14):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV4LandscapeShell: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		push_warning("GrandPrixV4LandscapeShell: route unavailable")
		return
	_playable_land = _find_named_recursive(get_parent(), "V36ContinuousLand")

	_landscape_root = Node3D.new()
	_landscape_root.name = "V40BiomeLandscapeShell"
	add_child(_landscape_root)

	for section_id: StringName in SECTION_IDS:
		var mesh: ArrayMesh = _build_section_mesh(section_id)
		if mesh.get_surface_count() == 0:
			continue
		_add_section_visual(section_id, mesh)
		_section_mesh_count += 1

	print("GRAND PRIX V4.0 LANDSCAPE SHELL READY section_meshes=%d triangles=%d collision=false guardrail=false near_field_owner=V39ContinuousLand water_reentry_preserved=true biome_shells=meadow,forest,river,mountain,summit,descent,canyon,final" % [
		_section_mesh_count,
		_triangle_count,
	])

func _build_section_mesh(section_id: StringName) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for segment_index: int in range(_route.size() - 1):
		if _track.get_v2_section_id_for_segment(segment_index) != section_id:
			continue
		_append_segment_landscape(
			section_id,
			segment_index,
			-1.0,
			vertices,
			normals,
			uvs,
			indices
		)
		_append_segment_landscape(
			section_id,
			segment_index,
			1.0,
			vertices,
			normals,
			uvs,
			indices
		)

	var mesh: ArrayMesh = ArrayMesh.new()
	if vertices.is_empty() or indices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_triangle_count += indices.size() / 3
	return mesh

func _append_segment_landscape(
	section_id: StringName,
	segment_index: int,
	side: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var route0: Vector3 = _route[segment_index]
	var route1: Vector3 = _route[segment_index + 1]
	var tangent: Vector3 = route1 - route0
	var tangent_planar: Vector3 = Vector3(tangent.x, 0.0, tangent.z)
	if tangent_planar.length_squared() <= 0.001:
		return
	tangent_planar = tangent_planar.normalized()
	var right: Vector3 = Vector3(-tangent_planar.z, 0.0, tangent_planar.x)
	var outward: Vector3 = right * side

	var playable_width: float = _playable_width(section_id)
	var start_offset: float = playable_width + float(INNER_OFFSETS_FROM_PLAYABLE_EDGE.get(section_id, -1.0))
	start_offset = maxf(4.0, start_offset)
	var far_offset: float = maxf(start_offset + 8.0, float(FAR_WIDTHS.get(section_id, 48.0)))
	var mid_offset: float = lerpf(start_offset, far_offset, MID_DISTANCE_RATIO)

	var profile: Vector3 = HEIGHT_PROFILES.get(section_id, Vector3(0.0, 2.0, 4.0)) as Vector3
	var variation: float = float(HEIGHT_VARIATION.get(section_id, 1.0))
	var phase0: float = float(segment_index) * 0.53 + (0.9 if side > 0.0 else 2.1)
	var phase1: float = float(segment_index + 1) * 0.53 + (0.9 if side > 0.0 else 2.1)
	var wave0: float = sin(phase0) * variation
	var wave1: float = sin(phase1) * variation

	var edge0: Vector3 = _track.get_v2_shoulder_edge_point(segment_index, side)
	var edge1: Vector3 = _track.get_v2_shoulder_edge_point(segment_index + 1, side)
	# Slight longitudinal overlap hides seams between disconnected segment wedges.
	edge0 -= tangent_planar * SEGMENT_OVERLAP
	edge1 += tangent_planar * SEGMENT_OVERLAP

	var inner0: Vector3 = edge0 + outward * start_offset + Vector3.UP * profile.x
	var mid0: Vector3 = edge0 + outward * mid_offset + Vector3.UP * (profile.y + wave0 * 0.45)
	var outer0: Vector3 = edge0 + outward * far_offset + Vector3.UP * (profile.z + wave0)
	var inner1: Vector3 = edge1 + outward * start_offset + Vector3.UP * profile.x
	var mid1: Vector3 = edge1 + outward * mid_offset + Vector3.UP * (profile.y + wave1 * 0.45)
	var outer1: Vector3 = edge1 + outward * far_offset + Vector3.UP * (profile.z + wave1)

	var base: int = vertices.size()
	vertices.append(inner0)
	vertices.append(mid0)
	vertices.append(outer0)
	vertices.append(inner1)
	vertices.append(mid1)
	vertices.append(outer1)
	for _normal_index: int in range(6):
		normals.append(Vector3.UP)
	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(0.5, 0.0))
	uvs.append(Vector2(1.0, 0.0))
	uvs.append(Vector2(0.0, 1.0))
	uvs.append(Vector2(0.5, 1.0))
	uvs.append(Vector2(1.0, 1.0))
	indices.append_array(PackedInt32Array([
		base, base + 1, base + 3,
		base + 1, base + 4, base + 3,
		base + 1, base + 2, base + 4,
		base + 2, base + 5, base + 4,
	]))

func _playable_width(section_id: StringName) -> float:
	if _playable_land != null and _playable_land.has_method("get_land_width_for_section"):
		return float(_playable_land.call("get_land_width_for_section", section_id))
	match section_id:
		&"meadow_start": return 18.0
		&"forest_obstacle": return 15.0
		&"long_river": return 14.0
		&"mountain_approach": return 18.0
		&"mountain_ascent": return 20.0
		&"summit_ridge": return 16.0
		&"rough_descent": return 18.0
		&"canyon_obstacle": return 14.0
		&"final_sprint": return 18.0
		_: return 12.0

func _add_section_visual(section_id: StringName, mesh: ArrayMesh) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Landscape_%s" % String(section_id)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = _material_for_section(section_id)
	_landscape_root.add_child(instance)

func _material_for_section(section_id: StringName) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	match section_id:
		&"meadow_start", &"final_sprint":
			material.albedo_color = Color(0.24, 0.43, 0.20, 1.0)
		&"forest_obstacle":
			material.albedo_color = Color(0.16, 0.32, 0.17, 1.0)
		&"long_river":
			material.albedo_color = Color(0.28, 0.39, 0.22, 1.0)
		&"mountain_approach":
			material.albedo_color = Color(0.40, 0.34, 0.24, 1.0)
		&"mountain_ascent", &"summit_ridge":
			material.albedo_color = Color(0.43, 0.38, 0.30, 1.0)
		&"rough_descent":
			material.albedo_color = Color(0.34, 0.30, 0.23, 1.0)
		&"canyon_obstacle":
			material.albedo_color = Color(0.39, 0.25, 0.17, 1.0)
		_:
			material.albedo_color = Color(0.25, 0.34, 0.21, 1.0)
	return material

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

func _find_named_recursive(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if String(root.name) == target_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named_recursive(child, target_name)
		if found != null:
			return found
	return null
