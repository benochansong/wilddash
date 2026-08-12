extends Node3D

# Visual-only route containment pass. This intentionally does not create any
# collision or per-frame processing. It strengthens the main-route silhouette
# by extending the existing shared wood/metal MultiMesh batches.

const SEGMENT_WIDTHS: Array[float] = [
	18, 18, 14, 14, 12, 8, 16, 14, 11, 10,
	18, 17, 18, 16, 10, 20, 18, 18, 22, 22,
	20, 15, 14, 13, 13, 12, 11, 12, 18,
]

const WOOD_CONTAINMENT_SEGMENTS: Array[int] = [2, 3, 4]
const METAL_CONTAINMENT_SEGMENTS: Array[int] = [
	0, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
	19, 20, 21, 22, 23, 24, 26, 27, 28,
]

func _ready() -> void:
	call_deferred("_build_route_containment")

func _build_route_containment() -> void:
	var track := get_parent()
	if track == null or not track.has_method("get_route_points"):
		push_warning("RouteContainmentGuidance: Grand Prix track parent is unavailable")
		return
	var decoration := track.get_node_or_null("DecorationGeometry") as Node3D
	if decoration == null:
		push_warning("RouteContainmentGuidance: DecorationGeometry is unavailable")
		return
	var route_points: Array[Vector3] = track.get_route_points()
	if route_points.size() != SEGMENT_WIDTHS.size() + 1:
		push_warning("RouteContainmentGuidance: route/width contract changed; skipping visual containment")
		return

	var wood_transforms: Array[Transform3D] = []
	var metal_transforms: Array[Transform3D] = []
	for segment_index in WOOD_CONTAINMENT_SEGMENTS:
		_append_wood_fence_segment(wood_transforms, route_points, segment_index)
	for segment_index in METAL_CONTAINMENT_SEGMENTS:
		_append_guardrail_segment(metal_transforms, route_points, segment_index)

	var wood_added := _append_to_existing_batch(decoration, "WoodStructuresAndProps", wood_transforms)
	var metal_added := _append_to_existing_batch(decoration, "GuardrailPosts", metal_transforms)
	decoration.set_meta(&"route_containment_guidance", true)
	decoration.set_meta(&"route_containment_wood_instances", wood_added)
	decoration.set_meta(&"route_containment_metal_instances", metal_added)
	decoration.set_meta(&"route_containment_collision", false)
	print("ROUTE CONTAINMENT PASS wood=%d metal=%d collision=false" % [wood_added, metal_added])
	process_mode = Node.PROCESS_MODE_DISABLED

func _append_wood_fence_segment(
	result: Array[Transform3D],
	route_points: Array[Vector3],
	segment_index: int
) -> void:
	var a := route_points[segment_index]
	var b := route_points[segment_index + 1]
	var width := SEGMENT_WIDTHS[segment_index]
	var length := a.distance_to(b)
	for side in [-1.0, 1.0]:
		# Two low rails make the Forest route read as Road -> shoulder -> fence -> vegetation.
		result.append(_track_transform_at(a, b, 0.5, side * (width * 0.5 + 0.72), 0.58, Vector3(0.16, 0.16, length)))
		result.append(_track_transform_at(a, b, 0.5, side * (width * 0.5 + 0.72), 1.03, Vector3(0.14, 0.14, length)))
		var post_count := maxi(4, int(ceil(length / 13.0)))
		for post_index in range(post_count + 1):
			var t := float(post_index) / float(post_count)
			result.append(_track_transform_at(a, b, t, side * (width * 0.5 + 0.72), 0.62, Vector3(0.24, 1.24, 0.24)))

func _append_guardrail_segment(
	result: Array[Transform3D],
	route_points: Array[Vector3],
	segment_index: int
) -> void:
	var a := route_points[segment_index]
	var b := route_points[segment_index + 1]
	var width := SEGMENT_WIDTHS[segment_index]
	var length := a.distance_to(b)
	var lateral_extra := 0.38 if segment_index == 5 or segment_index == 14 else 0.62
	for side in [-1.0, 1.0]:
		# A continuous, low rail carries the player's eye into the next segment without
		# turning the track into a solid-walled corridor.
		result.append(_track_transform_at(a, b, 0.5, side * (width * 0.5 + lateral_extra), 0.74, Vector3(0.22, 0.30, length)))
		var post_count := maxi(4, int(ceil(length / 15.0)))
		for post_index in range(post_count + 1):
			var t := float(post_index) / float(post_count)
			result.append(_track_transform_at(a, b, t, side * (width * 0.5 + lateral_extra), 0.55, Vector3(0.24, 1.10, 0.24)))

func _track_transform_at(
	a: Vector3,
	b: Vector3,
	t: float,
	lateral_offset: float,
	vertical_offset: float,
	size: Vector3
) -> Transform3D:
	var direction := b - a
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() < 0.001:
		return Transform3D.IDENTITY
	var right := Vector3(-planar.z, 0.0, planar.x).normalized()
	var origin := a.lerp(b, t) + right * lateral_offset + Vector3.UP * vertical_offset
	var transform := Transform3D(Basis.IDENTITY, origin)
	transform = transform.looking_at(origin + direction.normalized(), Vector3.UP)
	transform.basis = transform.basis.scaled(size)
	return transform

func _append_to_existing_batch(
	decoration: Node3D,
	node_name: String,
	additions: Array[Transform3D]
) -> int:
	if additions.is_empty():
		return 0
	var instance := decoration.get_node_or_null(node_name) as MultiMeshInstance3D
	if instance == null or instance.multimesh == null or instance.multimesh.mesh == null:
		push_warning("RouteContainmentGuidance: missing reusable batch %s" % node_name)
		return 0
	var current := instance.multimesh
	var merged := MultiMesh.new()
	merged.transform_format = current.transform_format
	merged.use_colors = current.use_colors
	merged.use_custom_data = current.use_custom_data
	merged.mesh = current.mesh
	var old_count := current.instance_count
	merged.instance_count = old_count + additions.size()
	for index in range(old_count):
		merged.set_instance_transform(index, current.get_instance_transform(index))
		if current.use_colors:
			merged.set_instance_color(index, current.get_instance_color(index))
		if current.use_custom_data:
			merged.set_instance_custom_data(index, current.get_instance_custom_data(index))
	for index in range(additions.size()):
		merged.set_instance_transform(old_count + index, additions[index])
	instance.multimesh = merged
	instance.set_meta(&"route_containment_added", additions.size())
	return additions.size()
