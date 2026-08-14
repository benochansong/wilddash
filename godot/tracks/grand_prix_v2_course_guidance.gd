class_name WildDashGrandPrixV2CourseGuidance
extends Node3D

## Lightweight V2 route readability. Rail placement reads each sampled segment's
## actual width instead of the legacy fixed 6.75m offset. Left/right colors are
## intentionally identical. Collision remains owned by GrandPrixV2Track.

const UPPER_HEIGHT := 1.18
const LOWER_HEIGHT := 0.58
const RAIL_EXTRA := 0.24
const BEAM_OVERLAP := 0.85

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var track: WildDashGrandPrixV2Track = _find_v2_track(get_parent())
	if track == null:
		push_warning("GrandPrixV2CourseGuidance: V2 track unavailable")
		return
	var route: Array[Vector3] = track.get_route_points()
	if route.size() < 2:
		return

	var upper_transforms: Array[Transform3D] = []
	var lower_transforms: Array[Transform3D] = []
	var support_transforms: Array[Transform3D] = []
	for segment_index: int in range(route.size() - 1):
		var a: Vector3 = route[segment_index]
		var b: Vector3 = route[segment_index + 1]
		var width: float = track.get_v2_width_for_segment(segment_index)
		var direction: Vector3 = b - a
		var planar: Vector3 = Vector3(direction.x, 0.0, direction.z)
		if planar.length_squared() <= 0.001:
			continue
		planar = planar.normalized()
		var right: Vector3 = Vector3(-planar.z, 0.0, planar.x)
		for side: float in [-1.0, 1.0]:
			var lateral: Vector3 = right * side * (width * 0.5 + RAIL_EXTRA)
			upper_transforms.append(_beam_transform(
				a + lateral + Vector3.UP * UPPER_HEIGHT,
				b + lateral + Vector3.UP * UPPER_HEIGHT,
				0.34, 0.28
			))
			lower_transforms.append(_beam_transform(
				a + lateral + Vector3.UP * LOWER_HEIGHT,
				b + lateral + Vector3.UP * LOWER_HEIGHT,
				0.24, 0.20
			))

		if segment_index % 2 == 0:
			var point: Vector3 = route[segment_index]
			var support_width: float = track.get_v2_width_for_segment(segment_index)
			for side: float in [-1.0, 1.0]:
				var support_position: Vector3 = point + right * side * (support_width * 0.5 + RAIL_EXTRA) + Vector3.UP * 0.64
				support_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.28, 1.28, 0.28)), support_position))

	var upper_material: StandardMaterial3D = _make_material(Color(0.08, 0.82, 0.72), 0.38, 0.18)
	var structure_material: StandardMaterial3D = _make_material(Color(0.22, 0.19, 0.14), 0.62, 0.12)
	_add_multimesh("V2GuardrailUpper", upper_transforms, upper_material)
	_add_multimesh("V2GuardrailLower", lower_transforms, structure_material)
	_add_multimesh("V2GuardrailSupports", support_transforms, structure_material)
	print("GRAND PRIX V2 GUARDRAIL READY segments=%d upper=%d lower=%d supports=%d variable_width=true symmetric_color=true" % [
		route.size() - 1, upper_transforms.size(), lower_transforms.size(), support_transforms.size(),
	])

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null

func _beam_transform(from: Vector3, to: Vector3, width: float, height: float) -> Transform3D:
	var distance: float = from.distance_to(to)
	var midpoint: Vector3 = (from + to) * 0.5
	var transform := Transform3D(Basis.IDENTITY, midpoint)
	transform = transform.looking_at(to, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(width, height, distance + BEAM_OVERLAP))
	return transform

func _add_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	multimesh.custom_aabb = AABB(Vector3(-260.0, -30.0, -1900.0), Vector3(520.0, 120.0, 2050.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
