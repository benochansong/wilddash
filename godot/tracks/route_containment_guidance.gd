extends Node3D

# Visual-only route containment pass. This intentionally does not create any
# collision or per-frame processing. It strengthens the main-route silhouette
# by extending existing shared wood/metal/warning MultiMesh batches.

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

# Sections that are visually broad/open or contain a major direction decision.
# These use a stronger two-rail profile and denser rhythm so distant road pieces
# do not compete with the actual route in the player's view.
const STRONG_CONTAINMENT_SEGMENTS: Array[int] = [
	0, 1, 5, 6, 7, 8, 9, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 26, 27, 28,
]

const OPEN_AREA_SEGMENTS: Array[int] = [0, 1, 6, 10, 11, 15, 18, 19, 20, 26, 27, 28]

# Leave intentional visual openings at shortcut entries and the tunnel portal.
const SKIP_CORNER_CONNECTOR_ROUTES: Array[int] = [16, 23, 25]

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
	var accent_transforms: Array[Transform3D] = []
	var corner_connector_count := 0

	for segment_index in WOOD_CONTAINMENT_SEGMENTS:
		_append_wood_fence_segment(wood_transforms, route_points, segment_index)
	for segment_index in METAL_CONTAINMENT_SEGMENTS:
		_append_guardrail_segment(
			metal_transforms,
			accent_transforms,
			route_points,
			segment_index,
			STRONG_CONTAINMENT_SEGMENTS.has(segment_index),
			OPEN_AREA_SEGMENTS.has(segment_index)
		)

	# Straight segment rails used to stop abruptly at every route point. Connect
	# neighboring boundaries through bends so the eye reads one continuous racing
	# corridor instead of unrelated strips of road scattered across the scene.
	for route_index in range(1, route_points.size() - 1):
		if SKIP_CORNER_CONNECTOR_ROUTES.has(route_index):
			continue
		var incoming := route_index - 1
		var outgoing := route_index
		if WOOD_CONTAINMENT_SEGMENTS.has(incoming) and WOOD_CONTAINMENT_SEGMENTS.has(outgoing):
			corner_connector_count += _append_corner_connectors(
				wood_transforms, route_points, incoming, outgoing, true,
				STRONG_CONTAINMENT_SEGMENTS.has(incoming) or STRONG_CONTAINMENT_SEGMENTS.has(outgoing)
			)
		elif METAL_CONTAINMENT_SEGMENTS.has(incoming) and METAL_CONTAINMENT_SEGMENTS.has(outgoing):
			corner_connector_count += _append_corner_connectors(
				metal_transforms, route_points, incoming, outgoing, false,
				STRONG_CONTAINMENT_SEGMENTS.has(incoming) or STRONG_CONTAINMENT_SEGMENTS.has(outgoing)
			)

	var wood_added := _append_to_existing_batch(decoration, "WoodStructuresAndProps", wood_transforms)
	var metal_added := _append_to_existing_batch(decoration, "GuardrailPosts", metal_transforms)
	var accents_added := _append_to_existing_batch(decoration, "EnvironmentWarningDetails", accent_transforms)
	decoration.set_meta(&"route_containment_guidance", true)
	decoration.set_meta(&"route_containment_wood_instances", wood_added)
	decoration.set_meta(&"route_containment_metal_instances", metal_added)
	decoration.set_meta(&"route_containment_accent_instances", accents_added)
	decoration.set_meta(&"route_containment_corner_connectors", corner_connector_count)
	decoration.set_meta(&"route_containment_open_segments", PackedInt32Array(OPEN_AREA_SEGMENTS))
	decoration.set_meta(&"route_containment_collision", false)
	print("ROUTE CONTAINMENT PASS wood=%d metal=%d accents=%d corner_connectors=%d collision=false" % [
		wood_added, metal_added, accents_added, corner_connector_count,
	])
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
		# Two rails make the Forest read as Road -> shoulder -> fence -> vegetation.
		result.append(_track_transform_at(
			a, b, 0.5, side * (width * 0.5 + 0.72), 0.58,
			Vector3(0.18, 0.18, length)
		))
		result.append(_track_transform_at(
			a, b, 0.5, side * (width * 0.5 + 0.72), 1.03,
			Vector3(0.16, 0.16, length)
		))
		var post_count := maxi(5, int(ceil(length / 11.0)))
		for post_index in range(post_count + 1):
			var t := float(post_index) / float(post_count)
			result.append(_track_transform_at(
				a, b, t, side * (width * 0.5 + 0.72), 0.64,
				Vector3(0.27, 1.30, 0.27)
			))

func _append_guardrail_segment(
	result: Array[Transform3D],
	accents: Array[Transform3D],
	route_points: Array[Vector3],
	segment_index: int,
	strong: bool,
	open_area: bool
) -> void:
	var a := route_points[segment_index]
	var b := route_points[segment_index + 1]
	var width := SEGMENT_WIDTHS[segment_index]
	var length := a.distance_to(b)
	var lateral_extra := _guardrail_extra(segment_index)
	for side in [-1.0, 1.0]:
		# The lower beam is intentionally thicker than the first pass. It needs to
		# remain readable from a third-person camera while other road segments are
		# visible in the distance.
		result.append(_track_transform_at(
			a, b, 0.5, side * (width * 0.5 + lateral_extra), 0.73,
			Vector3(0.30 if strong else 0.25, 0.38 if strong else 0.32, length)
		))
		if strong:
			result.append(_track_transform_at(
				a, b, 0.5, side * (width * 0.5 + lateral_extra), 1.14,
				Vector3(0.20, 0.16, length)
			))

		var spacing := 9.5 if open_area else (11.5 if strong else 14.0)
		var post_count := maxi(5, int(ceil(length / spacing)))
		for post_index in range(post_count + 1):
			var t := float(post_index) / float(post_count)
			result.append(_track_transform_at(
				a, b, t, side * (width * 0.5 + lateral_extra), 0.60,
				Vector3(0.28 if strong else 0.24, 1.20 if strong else 1.10, 0.28 if strong else 0.24)
			))
			# Sparse warm reflectors create a directional rhythm without becoming arrows.
			if strong and post_index % 2 == 0:
				accents.append(_track_transform_at(
					a, b, t, side * (width * 0.5 + lateral_extra - 0.03), 1.16,
					Vector3(0.30, 0.18, 0.18)
				))

func _append_corner_connectors(
	result: Array[Transform3D],
	route_points: Array[Vector3],
	incoming_segment: int,
	outgoing_segment: int,
	wood: bool,
	strong: bool
) -> int:
	var added := 0
	for side in [-1.0, 1.0]:
		var from := _segment_edge_at_end(route_points, incoming_segment, side)
		var to := _segment_edge_at_start(route_points, outgoing_segment, side)
		if from.distance_to(to) < 0.12:
			continue
		if wood:
			result.append(_beam_transform_between(
				from + Vector3.UP * 0.58, to + Vector3.UP * 0.58, 0.18, 0.18
			))
			result.append(_beam_transform_between(
				from + Vector3.UP * 1.03, to + Vector3.UP * 1.03, 0.16, 0.16
			))
			added += 2
		else:
			result.append(_beam_transform_between(
				from + Vector3.UP * 0.73, to + Vector3.UP * 0.73,
				0.30 if strong else 0.25, 0.38 if strong else 0.32
			))
			added += 1
			if strong:
				result.append(_beam_transform_between(
					from + Vector3.UP * 1.14, to + Vector3.UP * 1.14, 0.20, 0.16
				))
				added += 1
	return added

func _segment_edge_at_end(route_points: Array[Vector3], segment_index: int, side: float) -> Vector3:
	var point := route_points[segment_index + 1]
	return point + _segment_right(route_points, segment_index) * side * (
		SEGMENT_WIDTHS[segment_index] * 0.5 + _guardrail_extra(segment_index)
	)

func _segment_edge_at_start(route_points: Array[Vector3], segment_index: int, side: float) -> Vector3:
	var point := route_points[segment_index]
	return point + _segment_right(route_points, segment_index) * side * (
		SEGMENT_WIDTHS[segment_index] * 0.5 + _guardrail_extra(segment_index)
	)

func _segment_right(route_points: Array[Vector3], segment_index: int) -> Vector3:
	var direction := route_points[segment_index + 1] - route_points[segment_index]
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return Vector3.RIGHT
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)

func _guardrail_extra(segment_index: int) -> float:
	if WOOD_CONTAINMENT_SEGMENTS.has(segment_index):
		return 0.72
	if segment_index == 5 or segment_index == 14:
		return 0.38
	return 0.62

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

func _beam_transform_between(from: Vector3, to: Vector3, width: float, height: float) -> Transform3D:
	var distance := from.distance_to(to)
	if distance < 0.001:
		return Transform3D.IDENTITY
	var transform := Transform3D(Basis.IDENTITY, (from + to) * 0.5)
	transform = transform.looking_at(to, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(width, height, distance))
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
