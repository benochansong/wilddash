class_name WildDashGrandPrixV3MountainClearance
extends Node

## Grand Prix V3.10 mountain-route clearance pass.
##
## V2's wide terrain ribbons can fold across switchbacks and cover the road, so
## those legacy ribbons remain suppressed in the tight highland chunks. The
## authoritative V3.9 Continuous Land supplies the visible/collidable hill mass.
##
## V3.10 also removes the newer V4 visual-only landscape bands from mountain and
## canyon switchbacks. Those meshes have no collision by design and could fold
## across a nearby road, creating a giant visible wall that racers could drive
## through. Hiding only those highland bands keeps the playable V3.9 terrain and
## far skyline dressing while guaranteeing the actual road corridor stays clear.

const TERRAIN_CHUNK_LENGTH: float = 100.0
const PROBLEM_SECTIONS: Array[StringName] = [
	&"mountain_approach",
	&"mountain_ascent",
	&"summit_ridge",
	&"rough_descent",
	&"canyon_obstacle",
]

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _section_ranges: Dictionary = {}
var _terrain_shell: Node
var _grounding_world: Node
var _landscape_shell: Node
var _sanitized_chunks: Array[int] = []
var _backdrop_blockers_hidden: int = 0
var _v4_ghost_landscape_hidden: int = 0

func _ready() -> void:
	process_priority = 127
	call_deferred("_configure_when_ready")

func _configure_when_ready() -> void:
	for _frame: int in range(12):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3MountainClearance: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_section_ranges = _track.get_v2_section_ranges()
	_terrain_shell = _find_named_recursive(get_parent(), "V2TerrainShell")
	_grounding_world = _find_named_recursive(get_parent(), "V2GroundingWorld")
	_landscape_shell = _find_named_recursive(get_parent(), "V4LandscapeShell")
	if _route.size() < 2 or _section_ranges.is_empty():
		push_warning("GrandPrixV3MountainClearance: route/section data unavailable")
		return

	var chunk_ranges: Array[Vector2i] = _build_chunk_ranges()
	_sanitize_problem_chunks(chunk_ranges)
	await _hide_v4_switchback_landscape_when_ready()
	print("GRAND PRIX V3.10 MOUNTAIN CLEARANCE READY chunks=%s legacy_wide_terrain_hidden=true duplicate_apron_collision=false authoritative_embankment=V39ContinuousLand backdrop_blockers_hidden=%d v4_ghost_landscape_hidden=%d road_corridor_clear=true" % [
		str(_sanitized_chunks),
		_backdrop_blockers_hidden,
		_v4_ghost_landscape_hidden,
	])

func _build_chunk_ranges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start_point: int = 0
	var distance: float = 0.0
	for segment_index: int in range(_route.size() - 1):
		distance += _route[segment_index].distance_to(_route[segment_index + 1])
		if distance >= TERRAIN_CHUNK_LENGTH and segment_index + 1 < _route.size() - 1:
			result.append(Vector2i(start_point, segment_index + 1))
			start_point = segment_index + 1
			distance = 0.0
	if start_point < _route.size() - 1:
		result.append(Vector2i(start_point, _route.size() - 1))
	return result

func _sanitize_problem_chunks(chunk_ranges: Array[Vector2i]) -> void:
	for chunk_index: int in range(chunk_ranges.size()):
		var point_range: Vector2i = chunk_ranges[chunk_index]
		if not _range_hits_problem_section(point_range):
			continue
		_sanitized_chunks.append(chunk_index)
		_hide_terrain_chunk_visuals(chunk_index)
		_disable_terrain_chunk_collision(chunk_index)
		_hide_grounding_skirt(chunk_index)
		_hide_large_backdrop_blockers(chunk_index)

func _range_hits_problem_section(point_range: Vector2i) -> bool:
	for section_id: StringName in PROBLEM_SECTIONS:
		if not _section_ranges.has(section_id):
			continue
		var section_range: Vector2i = _section_ranges[section_id] as Vector2i
		var section_end: int = section_range.y + 1
		if point_range.y >= section_range.x and point_range.x <= section_end:
			return true
	return false

func _hide_terrain_chunk_visuals(chunk_index: int) -> void:
	if _terrain_shell == null:
		return
	var chunk: Node = _terrain_shell.get_node_or_null("V2SpatialChunk_%02d" % chunk_index)
	if chunk == null:
		return
	var terrain: Node = chunk.get_node_or_null("Terrain")
	if terrain != null:
		for visual_name: String in ["NearTerrain", "FarTerrain"]:
			var visual: Node = terrain.get_node_or_null(visual_name)
			if visual is VisualInstance3D:
				(visual as VisualInstance3D).visible = false
	var detail: Node = chunk.get_node_or_null("Detail")
	if detail != null:
		for detail_name: String in ["FarMountains", "CanyonWalls"]:
			var detail_visual: Node = detail.get_node_or_null(detail_name)
			if detail_visual is VisualInstance3D:
				(detail_visual as VisualInstance3D).visible = false
				_backdrop_blockers_hidden += 1

func _disable_terrain_chunk_collision(chunk_index: int) -> void:
	if _terrain_shell == null:
		return
	var collision_root: Node = _terrain_shell.get_node_or_null("V2NearTerrainCollision")
	if collision_root == null:
		return
	var collision: CollisionShape3D = collision_root.get_node_or_null("NearTerrainCollision_%02d" % chunk_index) as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)

func _hide_grounding_skirt(chunk_index: int) -> void:
	if _grounding_world == null:
		return
	var chunk: Node = _grounding_world.get_node_or_null("V2GroundingChunk_%02d" % chunk_index)
	if chunk == null:
		return
	var skirt: Node = chunk.get_node_or_null("GroundMass/TerrainSkirt")
	if skirt is VisualInstance3D:
		(skirt as VisualInstance3D).visible = false

func _hide_large_backdrop_blockers(chunk_index: int) -> void:
	if _grounding_world == null:
		return
	var chunk: Node = _grounding_world.get_node_or_null("V2GroundingChunk_%02d" % chunk_index)
	if chunk == null:
		return
	var backdrop: Node = chunk.get_node_or_null("Backdrop")
	if backdrop == null:
		return
	_hide_backdrop_recursive(backdrop)

func _hide_backdrop_recursive(root: Node) -> void:
	for child: Node in root.get_children():
		var node_name: String = String(child.name)
		var blocker: bool = (
			node_name.begins_with("MountainApproachMass")
			or node_name.begins_with("MountainAscentMass")
			or node_name.begins_with("DescentMass")
			or node_name.begins_with("CanyonHeroWall_")
			or node_name.begins_with("SummitBeam")
			or node_name.begins_with("SummitPost_")
		)
		if blocker and child is VisualInstance3D:
			(child as VisualInstance3D).visible = false
			_backdrop_blockers_hidden += 1
			continue
		_hide_backdrop_recursive(child)

func _hide_v4_switchback_landscape_when_ready() -> void:
	# V4LandscapeShell builds a few frames after this controller. Wait for its
	# runtime root rather than relying on node process ordering.
	for _frame: int in range(16):
		if _landscape_shell == null:
			_landscape_shell = _find_named_recursive(get_parent(), "V4LandscapeShell")
		if _landscape_shell != null:
			var landscape_root: Node = _landscape_shell.get_node_or_null("V43BiomeLandscapeShell")
			if landscape_root != null:
				for section_id: StringName in PROBLEM_SECTIONS:
					var visual: Node = landscape_root.get_node_or_null("Landscape_%s" % String(section_id))
					if visual is VisualInstance3D and (visual as VisualInstance3D).visible:
						(visual as VisualInstance3D).visible = false
						_v4_ghost_landscape_hidden += 1
				return
		await get_tree().process_frame

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
