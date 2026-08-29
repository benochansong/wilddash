class_name WildDashTrackProductionDressing
extends Node3D

## Visual-only RC7 production dressing for race tracks.
## Builds readable hero arches, route beacons and landmark pylons from the
## existing route points. No CollisionObject3D is created and gameplay route,
## checkpoints, shortcuts, obstacles and AI remain untouched.

@export var track_id: StringName = &"grand_prix"
@export var beacon_stride := 4
@export var beacon_offset := 8.6
@export var enable_finish_arch := true

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
	_build_landmark_pylons(route, palette)
	print("RC7 PRODUCTION ART track=%s beacons=%d route_points=%d collision=false" % [
		track_id, int(ceil(float(route.size()) / maxf(1.0, float(beacon_stride)))) * 2, route.size(),
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
			}
		&"snowpeak_winter_rally":
			return {
				"primary": Color(1.0, 0.36, 0.12, 1.0),
				"secondary": Color(0.12, 0.62, 0.92, 1.0),
				"structure": Color(0.20, 0.28, 0.38, 1.0),
				"emission": false,
			}
		_:
			return {
				"primary": Color(0.06, 0.76, 0.80, 1.0),
				"secondary": Color(1.0, 0.45, 0.12, 1.0),
				"structure": Color(0.22, 0.16, 0.10, 1.0),
				"emission": false,
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
	for side in [-1.0, 1.0]:
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
		for side in [-1.0, 1.0]:
			var root := Node3D.new()
			root.name = "RouteBeacon_%02d_%s" % [index, "L" if side < 0.0 else "R"]
			root.position = route[index] + right * beacon_offset * side
			_art_root.add_child(root)
			_add_cylinder(root, "Pole", Vector3.UP * 1.15, 0.075, 2.3, structure)
			_add_box(root, "Flag", Vector3(side * 0.34, 1.78, 0), Vector3(0.64, 0.72, 0.08), primary if side < 0.0 else secondary)
			_add_box(root, "Reflector", Vector3(0, 0.56, 0), Vector3(0.20, 0.26, 0.14), secondary if side < 0.0 else primary)

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
