extends "res://modes/logspire_leap/logspire_ladder_system_v3_easy_attach.gd"

## Full recovery-route audit after player testing.
## Early falls prefer jump-out/root routes. Ladders are reserved for meaningful
## height changes and every remaining ladder exits into the interior of a wide
## recovery deck instead of at a platform edge.

const SAFE_EXIT_EDGE_MARGIN: float = 2.75
const EARLY_DECK_SIZE := Vector3(7.0, 0.45, 7.0)
const MID_DECK_SIZE := Vector3(8.0, 0.45, 8.0)
const HIGH_DECK_SIZE := Vector3(10.0, 0.45, 10.0)
const RECOVERY_WALKWAY_WIDTH: float = 4.5
const JUMP_OUT_HEIGHT: float = 1.35
const JUMP_OUT_RADIUS: float = 5.5
const ROOT_STEP_WIDTH: float = 5.0
const ROOT_STEP_LENGTH: float = 3.2

var _jump_outs: Array[Dictionary] = []
var _root_ramps: Array[Dictionary] = []
var _water_heights_cache: Dictionary = {}

func _ladder_layout() -> Array:
	# 20 old exits -> 17 audited exits. The three early ladders removed here are
	# replaced by jump-out/root recovery so Zone 1/2 do not force ladders.
	return [
		{"zone": 0, "platform": &"Z1_07"},
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

func configure(world: Node, graph: Node, water_heights: Dictionary) -> void:
	_water_heights_cache = water_heights.duplicate(true)
	super(world, graph, water_heights)
	_audit_all_ladder_exits()
	_build_jump_out_network()
	print("LOGSPIRE RECOVERY ROUTE V4 READY old_ladders=20 ladders=%d removed=3 jump_outs=%d root_ramps=%d min_edge_margin=%.2fm" % [
		_ladders.size(), _jump_outs.size(), _root_ramps.size(), SAFE_EXIT_EDGE_MARGIN,
	])

func get_jump_outs_for_zone(zone: int) -> Array:
	var result: Array = []
	for entry: Dictionary in _jump_outs:
		if int(entry.get("zone", -1)) == zone:
			result.append(entry.duplicate(true))
	return result

func get_root_ramps_for_zone(zone: int) -> Array:
	var result: Array = []
	for entry: Dictionary in _root_ramps:
		if int(entry.get("zone", -1)) == zone:
			result.append(entry.duplicate(true))
	return result

func get_jump_out_count() -> int:
	return _jump_outs.size()

func get_root_ramp_count() -> int:
	return _root_ramps.size()

func _audit_all_ladder_exits() -> void:
	var merge_value: Variant = _graph.call("get_platform_position", &"Z4_MERGE")
	var merge_position: Vector3 = merge_value if merge_value is Vector3 else Vector3(0.0, 0.0, -500.0)
	var titan_center := Vector3(0.0, 0.0, merge_position.z - 90.0)
	for i: int in range(_ladders.size()):
		var ladder: Dictionary = _ladders[i]
		var zone: int = int(ladder.get("zone", 0))
		var platform_id := StringName(ladder.get("platform_id", &""))
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
		var outward := right * (-1.0 if i % 2 == 0 else 1.0)
		if zone == 4:
			outward = platform_position - titan_center
			outward.y = 0.0
			if outward.length_squared() <= 0.01:
				outward = right
			else:
				outward = outward.normalized()
		var radius_value: Variant = _graph.call("get_landing_radius", platform_id)
		var landing_radius: float = float(radius_value) if radius_value is float or radius_value is int else 4.0
		var deck_size: Vector3 = _deck_size_for_zone(zone)
		var deck_center := platform_position + outward * (landing_radius + deck_size.x * 0.5 + 1.4)
		var toward_platform := platform_position - deck_center
		toward_platform.y = 0.0
		if toward_platform.length_squared() <= 0.001:
			toward_platform = -outward
		else:
			toward_platform = toward_platform.normalized()
		var ladder_top_xz := deck_center - toward_platform * (deck_size.x * 0.5 - 0.85)
		var water_y: float = float(_water_heights_cache.get(zone, platform_position.y - 6.0))
		var bottom := Vector3(ladder_top_xz.x, water_y + 0.38, ladder_top_xz.z)
		var safe_exit := deck_center + toward_platform * minf(1.55, deck_size.x * 0.18)
		safe_exit.y = platform_position.y + 1.15
		_reposition_ladder_nodes(ladder, bottom, safe_exit, deck_center, platform_position, deck_size)
		ladder["bottom"] = bottom
		ladder["exit"] = safe_exit
		ladder["safe_exit"] = safe_exit
		ladder["deck_center"] = Vector3(deck_center.x, platform_position.y, deck_center.z)
		ladder["edge_margin"] = SAFE_EXIT_EDGE_MARGIN
		_ladders[i] = ladder
		print("LOGSPIRE LADDER VALID id=%s zone=%d platform=%s edge_margin=%.2f deck=%.1fm safe_exit=true" % [
			String(ladder.get("id", &"")), zone + 1, String(platform_id), SAFE_EXIT_EDGE_MARGIN, deck_size.x,
		])

func _deck_size_for_zone(zone: int) -> Vector3:
	if zone >= 4:
		return HIGH_DECK_SIZE
	if zone >= 2:
		return MID_DECK_SIZE
	return EARLY_DECK_SIZE

func _reposition_ladder_nodes(
	ladder: Dictionary,
	bottom: Vector3,
	safe_exit: Vector3,
	deck_center: Vector3,
	platform_position: Vector3,
	deck_size: Vector3
) -> void:
	var ladder_id: String = String(ladder.get("id", &""))
	var ladder_root := get_node_or_null(ladder_id) as Node3D
	if ladder_root != null:
		ladder_root.position = bottom
	var deck_root := get_node_or_null(ladder_id + "_RecoveryDeck") as Node3D
	if deck_root != null:
		deck_root.position = Vector3(deck_center.x, platform_position.y - deck_size.y * 0.5, deck_center.z)
		_resize_box_root(deck_root, deck_size)
	var bridge_root := get_node_or_null(ladder_id + "_Bridge") as Node3D
	if bridge_root != null:
		var deck_top := Vector3(deck_center.x, platform_position.y, deck_center.z)
		var delta := platform_position - deck_top
		delta.y = 0.0
		var length: float = maxf(1.0, delta.length())
		var bridge_size := Vector3(RECOVERY_WALKWAY_WIDTH, 0.32, length + 1.8)
		var bridge_center := (deck_top + platform_position) * 0.5
		bridge_root.position = bridge_center - Vector3.UP * (bridge_size.y * 0.5)
		if delta.length_squared() > 0.001:
			bridge_root.rotation.y = atan2(-delta.x, -delta.z)
		_resize_box_root(bridge_root, bridge_size)
	var marker := MeshInstance3D.new()
	marker.name = ladder_id + "_SafeExitMarker"
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.55
	marker_mesh.bottom_radius = 0.55
	marker_mesh.height = 0.08
	marker_mesh.material = _marker_material
	marker.mesh = marker_mesh
	marker.position = safe_exit - Vector3.UP * 1.08
	add_child(marker)

func _resize_box_root(root: Node3D, size: Vector3) -> void:
	for child_value: Variant in root.get_children():
		var mesh_node := child_value as MeshInstance3D
		if mesh_node != null and mesh_node.mesh is BoxMesh:
			(mesh_node.mesh as BoxMesh).size = size
		var body := child_value as StaticBody3D
		if body == null:
			continue
		for shape_value: Variant in body.get_children():
			var collision := shape_value as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				(collision.shape as BoxShape3D).size = size

func _build_jump_out_network() -> void:
	_jump_outs.clear()
	_root_ramps.clear()
	# Zone 1: direct start-bank jump plus two low ledges with broad root stairs.
	_add_direct_platform_jump_out(0, &"START")
	_add_jump_out_with_root_ramp(0, &"Z1_02", -1.0)
	_add_jump_out_with_root_ramp(0, &"Z1_04", 1.0)
	# Zone 2: water recovery begins with a low ledge/root route before ladders.
	_add_jump_out_with_root_ramp(1, &"Z2_01", -1.0)
	_add_jump_out_with_root_ramp(1, &"Z2_03", 1.0)
	# Titan Tree receives a broad root staircase as a non-ladder alternative.
	_add_root_ramp_only(4, &"Z5_APPROACH_01", -1.0)

func _add_direct_platform_jump_out(zone: int, platform_id: StringName) -> void:
	var platform_value: Variant = _graph.call("get_platform_position", platform_id)
	if not (platform_value is Vector3):
		return
	var platform_position: Vector3 = platform_value
	var water_y: float = float(_water_heights_cache.get(zone, platform_position.y - 1.0))
	var height: float = platform_position.y - water_y
	_jump_outs.append({
		"id": StringName("JUMP_OUT_%s" % String(platform_id)),
		"zone": zone,
		"platform_id": platform_id,
		"entry": Vector3(platform_position.x, water_y + 0.52, platform_position.z),
		"landing": platform_position + Vector3.UP * 0.82,
		"height": height,
		"radius": JUMP_OUT_RADIUS,
	})

func _add_jump_out_with_root_ramp(zone: int, platform_id: StringName, side: float) -> void:
	var platform_value: Variant = _graph.call("get_platform_position", platform_id)
	if not (platform_value is Vector3):
		return
	var platform_position: Vector3 = platform_value
	var forward_value: Variant = _graph.call("get_platform_forward", platform_id, &"safe")
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var radius_value: Variant = _graph.call("get_landing_radius", platform_id)
	var landing_radius: float = float(radius_value) if radius_value is float or radius_value is int else 4.0
	var water_y: float = float(_water_heights_cache.get(zone, platform_position.y - 3.0))
	var ledge_top := platform_position + right * side * (landing_radius + 7.0)
	ledge_top.y = water_y + JUMP_OUT_HEIGHT
	_create_static_box("JumpOut_%s" % String(platform_id), ledge_top, Vector3(7.0, 0.45, 5.5), _wood_material)
	var entry := Vector3(ledge_top.x, water_y + 0.52, ledge_top.z)
	var landing := ledge_top + Vector3.UP * 0.78
	_jump_outs.append({
		"id": StringName("JUMP_OUT_%s" % String(platform_id)),
		"zone": zone,
		"platform_id": platform_id,
		"entry": entry,
		"landing": landing,
		"height": JUMP_OUT_HEIGHT,
		"radius": JUMP_OUT_RADIUS,
	})
	_build_root_steps(zone, platform_id, ledge_top, platform_position)

func _add_root_ramp_only(zone: int, platform_id: StringName, side: float) -> void:
	var platform_value: Variant = _graph.call("get_platform_position", platform_id)
	if not (platform_value is Vector3):
		return
	var platform_position: Vector3 = platform_value
	var water_y: float = float(_water_heights_cache.get(zone, platform_position.y - 8.0))
	var entry_top := platform_position + Vector3(side * 13.0, 0.0, 9.0)
	entry_top.y = water_y + 0.55
	_build_root_steps(zone, platform_id, entry_top, platform_position)

func _build_root_steps(zone: int, platform_id: StringName, start_top: Vector3, end_top: Vector3) -> void:
	var delta := end_top - start_top
	var horizontal := Vector3(delta.x, 0.0, delta.z)
	var horizontal_length: float = maxf(1.0, horizontal.length())
	var vertical_height: float = maxf(0.0, end_top.y - start_top.y)
	var step_count: int = clampi(maxi(4, int(ceil(vertical_height / 0.8))), 4, 14)
	var direction := horizontal.normalized() if horizontal.length_squared() > 0.001 else Vector3.FORWARD
	for step_index: int in range(step_count):
		var t: float = (float(step_index) + 0.5) / float(step_count)
		var top := start_top.lerp(end_top, t)
		var step_length: float = maxf(ROOT_STEP_LENGTH, horizontal_length / float(step_count) + 0.8)
		var root := _create_static_box(
			"RootRamp_%s_%02d" % [String(platform_id), step_index + 1],
			top,
			Vector3(ROOT_STEP_WIDTH, 0.38, step_length),
			_wood_material
		)
		root.rotation.y = atan2(-direction.x, -direction.z)
	_root_ramps.append({
		"id": StringName("ROOT_RAMP_%s" % String(platform_id)),
		"zone": zone,
		"platform_id": platform_id,
		"entry": start_top + Vector3.UP * 0.65,
		"exit": end_top + Vector3.UP * 0.82,
		"radius": 4.0,
	})
