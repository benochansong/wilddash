class_name WildDashGrandPrixV5RoadCorridorClearance
extends Node

## Route-wide clearance guard for visual-only Grand Prix scenery.
##
## Environment dressing places mountain/spire MultiMesh transforms relative to a
## local route segment. On switchbacks a different route segment can loop back
## into the same footprint, making a collisionless mountain appear to sit on the
## road. This pass filters those large visual-only transforms against the entire
## authoritative route, using each prop's footprint radius plus road width.
##
## IMPORTANT: the authoritative track class is WildDashGrandPrixTrack. An earlier
## revision accidentally referenced a nonexistent WildDashGrandPrixV2Track type,
## which prevents Grand Prix from parsing/loading and makes Character Select START
## appear dead for every racer. Keep this file dependent only on the real track API.

const SAFETY_BUFFER: float = 7.0
const MIN_SCENERY_RADIUS: float = 2.0
const MAX_WAIT_FRAMES: int = 36

var _track: WildDashGrandPrixTrack
var _route: Array[Vector3] = []
var _checked: int = 0
var _removed: int = 0
var _mountains_checked: int = 0
var _spires_checked: int = 0
var _minimum_margin: float = INF

func _ready() -> void:
	process_priority = 140
	call_deferred("_filter_when_ready")

func _filter_when_ready() -> void:
	for _frame: int in range(MAX_WAIT_FRAMES):
		_track = _find_track(get_parent())
		if _track != null:
			_route = _track.get_route_points()
		var mountain_node: MultiMeshInstance3D = _find_multimesh_recursive(get_parent(), "MountainPeaks")
		var spire_node: MultiMeshInstance3D = _find_multimesh_recursive(get_parent(), "CanyonRockSpires")
		if _route.size() >= 2 and (mountain_node != null or spire_node != null):
			if mountain_node != null:
				_filter_multimesh(mountain_node, &"EnvironmentDressing/MountainPeaks")
			if spire_node != null:
				_filter_multimesh(spire_node, &"EnvironmentDressing/CanyonRockSpires")
			var margin_text: String = "n/a" if _minimum_margin == INF else "%.2f" % _minimum_margin
			print("GRAND PRIX ROAD CORRIDOR CLEAR ghost_scenery_removed=%d checked=%d mountains_checked=%d spires_checked=%d minimum_clearance_margin=%s buffer=%.1f whole_route=true" % [
				_removed, _checked, _mountains_checked, _spires_checked, margin_text, SAFETY_BUFFER,
			])
			return
		await get_tree().process_frame
	push_warning("GRAND PRIX ROAD CORRIDOR CLEARANCE could not find route/environment dressing in time")

func is_scenery_safe_for_route(position: Vector3, footprint_radius: float, local_segment_index: int = -1) -> bool:
	if _track == null or _route.size() < 2:
		return true
	var radius: float = maxf(MIN_SCENERY_RADIUS, footprint_radius)
	var nearest_distance: float = INF
	var nearest_required: float = 0.0
	for segment_index: int in range(_route.size() - 1):
		var distance: float = _planar_distance_to_segment(position, _route[segment_index], _route[segment_index + 1])
		var road_width: float = 16.0
		if segment_index >= 0 and segment_index < WildDashGrandPrixTrack.SEGMENT_WIDTHS.size():
			road_width = float(WildDashGrandPrixTrack.SEGMENT_WIDTHS[segment_index])
		var required: float = road_width * 0.5 + radius + SAFETY_BUFFER
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_required = required
		if distance < required:
			print("GHOST SCENERY CULLED source=EnvironmentDressing segment=%d local_segment=%d distance=%.2f required=%.2f radius=%.2f" % [
				segment_index, local_segment_index, distance, required, radius,
			])
			return false
	if nearest_distance < INF:
		_minimum_margin = minf(_minimum_margin, nearest_distance - nearest_required)
	return true

func _filter_multimesh(instance: MultiMeshInstance3D, source_name: StringName) -> void:
	if instance == null or instance.multimesh == null:
		return
	var source: MultiMesh = instance.multimesh
	var safe_transforms: Array[Transform3D] = []
	for i: int in range(source.instance_count):
		var transform: Transform3D = source.get_instance_transform(i)
		var world_position: Vector3 = instance.to_global(transform.origin)
		var scale: Vector3 = transform.basis.get_scale()
		var footprint_radius: float = maxf(MIN_SCENERY_RADIUS, maxf(absf(scale.x), absf(scale.z)))
		_checked += 1
		if String(source_name).contains("MountainPeaks"):
			_mountains_checked += 1
		else:
			_spires_checked += 1
		if is_scenery_safe_for_route(world_position, footprint_radius):
			safe_transforms.append(transform)
		else:
			_removed += 1

	if safe_transforms.size() == source.instance_count:
		instance.set_meta(&"wilddash_visual_only_scenery", true)
		instance.set_meta(&"wilddash_source_generator", source_name)
		return

	var filtered: MultiMesh = MultiMesh.new()
	filtered.transform_format = source.transform_format
	filtered.mesh = source.mesh
	filtered.instance_count = safe_transforms.size()
	for i: int in range(safe_transforms.size()):
		filtered.set_instance_transform(i, safe_transforms[i])
	instance.multimesh = filtered
	instance.set_meta(&"wilddash_visual_only_scenery", true)
	instance.set_meta(&"wilddash_source_generator", source_name)
	instance.set_meta(&"wilddash_scenery_filtered", true)
	print("ROAD CORRIDOR FILTER source=%s before=%d after=%d removed=%d" % [
		String(source_name), source.instance_count, safe_transforms.size(), source.instance_count - safe_transforms.size(),
	])

func _planar_distance_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var point_2d: Vector2 = Vector2(point.x, point.z)
	var a_2d: Vector2 = Vector2(a.x, a.z)
	var b_2d: Vector2 = Vector2(b.x, b.z)
	var ab: Vector2 = b_2d - a_2d
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.001:
		return point_2d.distance_to(a_2d)
	var t: float = clampf((point_2d - a_2d).dot(ab) / length_sq, 0.0, 1.0)
	return point_2d.distance_to(a_2d + ab * t)

func _find_track(root: Node) -> WildDashGrandPrixTrack:
	if root == null:
		return null
	if root is WildDashGrandPrixTrack:
		return root as WildDashGrandPrixTrack
	for child: Node in root.get_children():
		var found: WildDashGrandPrixTrack = _find_track(child)
		if found != null:
			return found
	return null

func _find_multimesh_recursive(root: Node, target_name: String) -> MultiMeshInstance3D:
	if root == null:
		return null
	if String(root.name) == target_name and root is MultiMeshInstance3D:
		return root as MultiMeshInstance3D
	for child: Node in root.get_children():
		var found: MultiMeshInstance3D = _find_multimesh_recursive(child, target_name)
		if found != null:
			return found
	return null
