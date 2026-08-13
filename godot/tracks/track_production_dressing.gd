class_name WildDashTrackProductionDressing
extends Node3D

## Visual-only RC7/RC9 production dressing for race tracks.
## Builds readable hero arches, route beacons, continuous edge rails and
## landmark pylons from existing route points. No CollisionObject3D is created.

const GUARDRAIL_SEGMENTS_PER_BATCH := 6
const RAIL_SIDES: Array[float] = [-1.0, 1.0]

@export var track_id: StringName = &"grand_prix"
@export var beacon_stride := 4
@export var beacon_offset := 8.6
@export var enable_finish_arch := true
@export var enable_continuous_guardrail := true

var _art_root: Node3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_build_when_track_ready")

func _build_when_track_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var track := _find_track(get_parent())
	if track == null:
		push_warning("TrackProductionDressing could not find route provider for %s" % track_id)
		return
	var route := _extract_route(track)
	if route.size() < 3:
		push_warning("TrackProductionDressing route too small for %s" % track_id)
		return
	_art_root = Node3D.new()
	_art_root.name = "ProductionArt_%s" % String(track_id)
	add_child(_art_root)
	var palette := _palette()
	_build_arch(route[0], route[1] - route[0], "StartHeroArch", palette, false)
	if enable_finish_arch:
		_build_arch(route[-1], route[-1] - route[-2], "FinishHeroArch", palette, true)
	_build_route_beacons(route, palette)
	if enable_continuous_guardrail:
		_build_continuous_guardrails(route, palette)
	_build_landmark_pylons(route, palette)
	print("RC9 PRODUCTION ART track=%s beacons=%d route_points=%d continuous_guardrail=%s collision=false" % [
		track_id, int(ceil(float(route.size()) / maxf(1.0, float(beacon_stride)))) * 2,
		route.size(), str(enable_continuous_guardrail),
	])

func _find_track(node: Node) -> Node:
	if node != self and node.has_method("get_route_points"):
		return node
	for child in node.get_children():
		var found := _find_track(child)
		if found != null:
			return found
	return null

func _extract_route(track: Node) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var raw: Variant = track.call("get_route_points")
	if raw is Array:
		for value in raw:
			if value is Vector3:
				result.append(value)
	return result

func _palette() -> Dictionary:
	match track_id:
		&"neon_harbor_race":
			return {
				"primary": Color(0.07, 0.82, 1.0, 1.0),
				"secondary": Color(1.0, 0.16, 0.72, 1.0),
				"structure": Color(0.10, 0.16, 0.28, 1.0),
				"emission": true,
				"rail_offset": 6.85,
				"rail_upper_height": 1.42,
				"rail_lower_height": 0.68,
			}
		&"snowpeak_winter_rally":
			return {
				"primary": Color(1.0, 0.36, 0.12, 1.0),
				"secondary": Color(0.95, 0.92, 0.80, 1.0),
				"structure": Color(0.20, 0.28, 0.38, 1.0),
				"emission": false,
				"rail_offset": 6.65,
				"rail_upper_height": 1.38,
				"rail_lower_height": 0.62,
			}
		_:
			return {
				"primary": Color(0.08, 0.82, 0.72, 1.0),
				"secondary": Color(1.0, 0.48, 0.10, 1.0),
				"structure": Color(0.25, 0.17, 0.09, 1.0),
				"emission": false,
				"rail_offset": 6.75,
				"rail_upper_height": 1.34,
				"rail_lower_height": 0.60,
			}

func _build_arch(point: Vector3, tangent: Vector3, node_name: String, palette: Dictionary, finish: bool) -> void:
	tangent.y = 0.0
	if tangent.length_squared() <= 0.001:
		tangent = Vector3.FORWARD
	tangent = tangent.normalized()
	var right := Vector3(-tangent.z, 0.0, tangent.x)
	var root := Node3D.new()
	root.name = node_name
	root.position = point
	_art_root.add_child(root)
	var structure := _material(palette["structure"], 0.52, 0.35)
	var primary := _material(palette["primary"], 0.50, 0.05, bool(palette["emission"]))
	var secondary := _material(palette["secondary"], 0.48, 0.02, bool(palette["emission"]))
	for side in RAIL_SIDES:
		_add_box(root, "ArchPost", right * side * 6.4 + Vector3.UP * 2.6, Vector3(0.42, 5.2, 0.52), structure)
		_add_box(root, "AccentPost", right * side * 6.4 + Vector3.UP * 3.2 - tangent * 0.30, Vector3(0.52, 2.3, 0.22), primary if side < 0.0 else secondary)
	_add_box(root, "TopBeam", Vector3.UP * 5.05, Vector3(13.2, 0.55, 0.65), structure)
	_add_box(root, "TopAccent", Vector3.UP * 5.10 - tangent * 0.38, Vector3(8.4, 0.26, 0.16), secondary if finish else primary)
	for x in [-4.6, -2.3, 0.0, 2.3, 4.6]:
		var color: Material = primary if int(absf(x) * 10.0) % 2 == 0 else secondary
		_add_box(root, "RacePanel", right * x + Vector3.UP * 4.45 - tangent * 0.42, Vector3(1.4, 0.52, 0.12), color)

func _build_route_beacons(route: Array[Vector3], palette: Dictionary) -> void:
	var primary := _material(palette["primary"], 0.52, 0.0, bool(palette["emission"]))
	var secondary := _material(palette["secondary"], 0.52, 0.0, bool(palette["emission"]))
	var structure := _material(palette["structure"], 0.72, 0.18)
	for index in range(1, route.size() - 1, maxi(1, beacon_stride)):
		var tangent := route[index + 1] - route[index - 1]
		tangent.y = 0.0
		if tangent.length_squared() <= 0.001:
			continue
		tangent = tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		for side in RAIL_SIDES:
			var root := Node3D.new()
			root.name = "RouteBeacon_%02d_%s" % [index, "L" if side < 0.0 else "R"]
			root.position = route[index] + right * beacon_offset * side
			_art_root.add_child(root)
			_add_cylinder(root, "Pole", Vector3.UP * 1.15, 0.075, 2.3, structure)
			_add_box(root, "Flag", Vector3(side * 0.34, 1.78, 0), Vector3(0.64, 0.72, 0.08), primary if side < 0.0 else secondary)
			_add_box(root, "Reflector", Vector3(0, 0.56, 0), Vector3(0.20, 0.26, 0.14), secondary if side < 0.0 else primary)

func _build_continuous_guardrails(route: Array[Vector3], palette: Dictionary) -> void:
	var rail_offset: float = float(palette.get("rail_offset", maxf(6.4, beacon_offset - 1.8)))
	var upper_height: float = float(palette.get("rail_upper_height", 1.34))
	var lower_height: float = float(palette.get("rail_lower_height", 0.62))
	var primary: StandardMaterial3D = _material(palette["primary"], 0.42, 0.18, bool(palette["emission"]))
	var secondary: StandardMaterial3D = _material(palette["secondary"], 0.48, 0.12, bool(palette["emission"]))
	var upper_batch: Array[Transform3D] = []
	var lower_batch: Array[Transform3D] = []
	var batch_index: int = 0
	var segment_in_batch: int = 0
	var total_segments: int = 0
	var total_upper: int = 0
	var total_lower: int = 0

	for index in range(route.size() - 1):
		var a: Vector3 = route[index]
		var b: Vector3 = route[index + 1]
		var planar: Vector3 = b - a
		planar.y = 0.0
		if planar.length_squared() <= 0.001:
			continue
		var direction: Vector3 = planar.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		for side in RAIL_SIDES:
			var lateral: Vector3 = right * rail_offset * side
			upper_batch.append(_beam_transform(
				a + lateral + Vector3.UP * upper_height,
				b + lateral + Vector3.UP * upper_height,
				0.16
			))
			lower_batch.append(_beam_transform(
				a + lateral + Vector3.UP * lower_height,
				b + lateral + Vector3.UP * lower_height,
				0.11
			))
		total_segments += 1
		segment_in_batch += 1
		var flush_batch: bool = segment_in_batch >= GUARDRAIL_SEGMENTS_PER_BATCH or index == route.size() - 2
		if flush_batch:
			_add_box_multimesh("ContinuousGuardrailUpper_%02d" % batch_index, upper_batch, primary, true)
			_add_box_multimesh("ContinuousGuardrailLower_%02d" % batch_index, lower_batch, secondary, true)
			total_upper += upper_batch.size()
			total_lower += lower_batch.size()
			upper_batch.clear()
			lower_batch.clear()
			segment_in_batch = 0
			batch_index += 1

	print("RC9 GUARDRAIL FULL ROUTE track=%s route_segments=%d batches=%d upper=%d lower=%d collision=false" % [
		track_id, total_segments, batch_index, total_upper, total_lower,
	])

func _beam_transform(from: Vector3, to: Vector3, thickness: float) -> Transform3D:
	var distance := from.distance_to(to)
	if distance <= 0.001:
		return Transform3D.IDENTITY
	var midpoint := (from + to) * 0.5
	var transform := Transform3D(Basis.IDENTITY, midpoint)
	transform = transform.looking_at(to, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(thickness, thickness, distance))
	return transform

func _add_box_multimesh(node_name: String, transforms: Array[Transform3D], material: Material, guardrail_batch := false) -> void:
	if transforms.is_empty():
		return
	var primitive := BoxMesh.new()
	primitive.size = Vector3.ONE
	primitive.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = primitive
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	# A very long single MultiMesh can be culled as one object while the player
	# travels through a multi-kilometre course. Guardrail batches get an explicit
	# local-space AABB matching every transformed cube so each route chunk is
	# independently visible/cullable for the entire race.
	if guardrail_batch:
		multimesh.custom_aabb = _calculate_transforms_aabb(transforms)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	if guardrail_batch:
		instance.extra_cull_margin = 35.0
	_art_root.add_child(instance)

func _calculate_transforms_aabb(transforms: Array[Transform3D]) -> AABB:
	if transforms.is_empty():
		return AABB(Vector3.ZERO, Vector3.ONE)
	var corners: Array[Vector3] = [
		Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5),
		Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5),
		Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5),
	]
	var first_point := transforms[0] * corners[0]
	var bounds := AABB(first_point, Vector3.ZERO)
	for transform in transforms:
		for corner in corners:
			bounds = bounds.expand(transform * corner)
	return bounds.grow(1.5)

func _build_landmark_pylons(route: Array[Vector3], palette: Dictionary) -> void:
	var primary := _material(palette["primary"], 0.48, 0.08, bool(palette["emission"]))
	var secondary := _material(palette["secondary"], 0.48, 0.08, bool(palette["emission"]))
	var structure := _material(palette["structure"], 0.66, 0.24)
	for ratio in [0.25, 0.50, 0.75]:
		var index := clampi(int(round((route.size() - 1) * ratio)), 1, route.size() - 2)
		var tangent := route[index + 1] - route[index - 1]
		tangent.y = 0.0
		if tangent.length_squared() <= 0.001:
			continue
		tangent = tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		var root := Node3D.new()
		root.name = "HeroLandmark_%02d" % index
		root.position = route[index] + right * (beacon_offset + 4.5) * (-1.0 if ratio == 0.50 else 1.0)
		_art_root.add_child(root)
		_add_box(root, "Base", Vector3.UP * 0.35, Vector3(2.4, 0.7, 2.4), structure)
		_add_box(root, "Pylon", Vector3.UP * 2.7, Vector3(0.75, 4.7, 0.75), structure)
		_add_box(root, "HeroPanelA", Vector3(0, 3.4, -0.42), Vector3(1.5, 1.6, 0.14), primary)
		_add_box(root, "HeroPanelB", Vector3(0, 1.9, -0.43), Vector3(1.1, 0.65, 0.15), secondary)

func _material(color: Color, roughness: float, metallic: float, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	return material

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)

func _add_cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
