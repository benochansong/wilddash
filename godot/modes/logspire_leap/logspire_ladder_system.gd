extends Node3D

## Builds the visible recovery ladder network and small safe decks beside the
## existing Logspire platforms. Rungs use MultiMesh so the 19 ladders do not
## become hundreds of independent scene/physics objects.

const DECK_SIZE := Vector3(6.0, 0.45, 6.0)
const LADDER_ATTACH_RADIUS: float = 2.15

var _world: Node
var _graph: Node
var _ladders: Array[Dictionary] = []
var _configured: bool = false
var _wood_material: StandardMaterial3D
var _rung_material: StandardMaterial3D
var _marker_material: StandardMaterial3D

func configure(world: Node, graph: Node, water_heights: Dictionary) -> void:
	if _configured:
		return
	_world = world
	_graph = graph
	_build_materials()
	var safe_ids: Array = _graph.call("get_route_ids", &"safe")
	var layout: Array = _ladder_layout()
	for i: int in range(layout.size()):
		var entry: Dictionary = layout[i]
		var zone: int = int(entry.get("zone", 0))
		var platform_id := StringName(entry.get("platform", &""))
		var water_y: float = float(water_heights.get(zone, -1.0))
		var platform_value: Variant = _graph.call("get_platform_position", platform_id)
		if not (platform_value is Vector3):
			continue
		var platform_position: Vector3 = platform_value
		var forward_value: Variant = _graph.call("get_platform_forward", platform_id, &"safe")
		var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		var right := Vector3(-forward.z, 0.0, forward.x)
		# PlatformGraph exposes get_landing_radius(); calling the world's method name
		# here caused Round 3 to stop on entry after Round 2.
		var radius_value: Variant = _graph.call("get_landing_radius", platform_id)
		var landing_radius: float = float(radius_value) if radius_value is float or radius_value is int else 4.0
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var deck_offset: float = clampf(landing_radius + 1.8, 4.2, 6.8)
		var deck_center := platform_position + right * side * deck_offset
		var bottom := Vector3(deck_center.x, water_y + 0.38, deck_center.z)
		var exit_position := Vector3(deck_center.x, platform_position.y + 1.15, deck_center.z)
		var route_index: int = safe_ids.find(platform_id)
		var ladder_id := StringName("WATER_LADDER_Z%d_%02d" % [zone + 1, i + 1])
		_build_recovery_deck(ladder_id, deck_center, platform_position)
		_build_ladder_visual(ladder_id, bottom, platform_position.y)
		_ladders.append({
			"id": ladder_id,
			"zone": zone,
			"platform_id": platform_id,
			"bottom": bottom,
			"exit": exit_position,
			"route_index": maxi(0, route_index),
			"attach_radius": LADDER_ATTACH_RADIUS,
		})
	_configured = true
	print("LOGSPIRE LADDER READY ladders=%d zones=6 deck_width=%.1fm auto_attach=true multimesh_rungs=true" % [
		_ladders.size(), DECK_SIZE.x,
	])

func get_all_ladders() -> Array:
	var result: Array = []
	for ladder: Dictionary in _ladders:
		result.append(ladder.duplicate(true))
	return result

func get_ladders_for_zone(zone: int) -> Array:
	var result: Array = []
	for ladder: Dictionary in _ladders:
		if int(ladder.get("zone", -1)) == zone:
			result.append(ladder.duplicate(true))
	return result

func get_ladder_count() -> int:
	return _ladders.size()

func _ladder_layout() -> Array:
	return [
		{"zone": 0, "platform": &"Z1_04"},
		{"zone": 0, "platform": &"Z1_07"},
		{"zone": 1, "platform": &"Z2_03"},
		{"zone": 1, "platform": &"Z2_06"},
		{"zone": 1, "platform": &"Z2_08"},
		{"zone": 2, "platform": &"Z3_02"},
		{"zone": 2, "platform": &"Z3_05"},
		{"zone": 2, "platform": &"Z3_08"},
		{"zone": 3, "platform": &"Z4_SAFE_03"},
		{"zone": 3, "platform": &"Z4_SAFE_06"},
		{"zone": 3, "platform": &"Z4_WILD_05"},
		{"zone": 3, "platform": &"Z4_MERGE"},
		{"zone": 4, "platform": &"Z5_APPROACH_01"},
		{"zone": 4, "platform": &"Z5_SPIRAL_03"},
		{"zone": 4, "platform": &"Z5_SPIRAL_06"},
		{"zone": 4, "platform": &"Z5_SPIRAL_09"},
		{"zone": 5, "platform": &"Z6_START"},
		{"zone": 5, "platform": &"Z6_04"},
		{"zone": 5, "platform": &"Z6_07"},
	]

func _build_materials() -> void:
	_wood_material = _material(Color(0.42, 0.24, 0.09), false)
	_rung_material = _material(Color(0.86, 0.61, 0.17), false)
	_marker_material = _material(Color(1.0, 0.48, 0.08), true)

func _material(color: Color, emission: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	if emission:
		material.emission_enabled = true
		material.emission = color * 0.85
	return material

func _build_recovery_deck(ladder_id: StringName, deck_center: Vector3, platform_position: Vector3) -> void:
	var deck_top := Vector3(deck_center.x, platform_position.y, deck_center.z)
	_create_static_box("%s_RecoveryDeck" % String(ladder_id), deck_top, DECK_SIZE, _wood_material)
	var bridge_center := (deck_top + platform_position) * 0.5
	var delta := platform_position - deck_top
	delta.y = 0.0
	var bridge_length: float = maxf(1.0, delta.length())
	var bridge_size := Vector3(2.6, 0.32, bridge_length + 1.2)
	var bridge := _create_static_box("%s_Bridge" % String(ladder_id), bridge_center, bridge_size, _wood_material)
	if delta.length_squared() > 0.001:
		bridge.rotation.y = atan2(-delta.x, -delta.z)

func _create_static_box(node_name: String, top_position: Vector3, size: Vector3, material: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = top_position - Vector3.UP * (size.y * 0.5)
	add_child(root)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_node.mesh = mesh
	root.add_child(mesh_node)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return root

func _build_ladder_visual(ladder_id: StringName, bottom: Vector3, top_y: float) -> void:
	var height: float = maxf(2.0, top_y - bottom.y)
	var root := Node3D.new()
	root.name = String(ladder_id)
	root.position = bottom
	add_child(root)

	for side: float in [-0.62, 0.62]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.13, height, 0.13)
		rail_mesh.material = _rung_material
		rail.mesh = rail_mesh
		rail.position = Vector3(side, height * 0.5, 0.0)
		root.add_child(rail)

	var rung_mesh := BoxMesh.new()
	rung_mesh.size = Vector3(1.38, 0.10, 0.15)
	rung_mesh.material = _rung_material
	var rung_count: int = maxi(3, int(floor(height / 0.65)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rung_mesh
	multimesh.instance_count = rung_count
	for i: int in range(rung_count):
		var y: float = minf(height - 0.25, 0.30 + float(i) * 0.65)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)))
	var rungs := MultiMeshInstance3D.new()
	rungs.multimesh = multimesh
	root.add_child(rungs)

	var beacon := MeshInstance3D.new()
	beacon.name = "OrangeBeacon"
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.34
	beacon_mesh.height = 0.68
	beacon_mesh.material = _marker_material
	beacon.mesh = beacon_mesh
	beacon.position = Vector3(0.0, 1.25, 0.0)
	root.add_child(beacon)

	var label := Label3D.new()
	label.name = "ClimbLabel"
	label.text = "CLIMB ↑"
	label.font_size = 42
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.74, 0.20)
	label.position = Vector3(0.0, 2.25, 0.0)
	root.add_child(label)
