extends Node

## Production guard for the late Titan Tree Safe Route.
##
## Phase A deliberately enlarges/compacts broad platforms, but the Titan spiral
## turns 42 degrees at every step. A 12x15m minimum there can make a third spiral
## platform overlap the jump arc between its neighbours. The original finale
## start also bends back toward the estimated Titan centre, so the last spiral
## exit can cross the trunk collision.
##
## This guard runs after JumpGapGuard and before PlatformGraph/Phase3 setup. It
## keeps the generous landing feel without allowing neighbouring spiral slabs to
## overlap, then sends the finale outward along the spiral tangent instead of
## through the Titan trunk.

const SPIRAL_IDS: Array[StringName] = [
	&"Z5_SPIRAL_01", &"Z5_SPIRAL_02", &"Z5_SPIRAL_03", &"Z5_SPIRAL_04", &"Z5_SPIRAL_05",
	&"Z5_SPIRAL_06", &"Z5_SPIRAL_07", &"Z5_SPIRAL_08", &"Z5_SPIRAL_09", &"Z5_SPIRAL_10",
]
const FINALE_IDS: Array[StringName] = [
	&"Z6_START", &"Z6_01", &"Z6_02", &"Z6_03", &"Z6_04", &"Z6_05", &"Z6_06", &"Z6_07", &"CROWN_NEST",
]
const SPIRAL_PLATFORM_WIDTH: float = 10.0
const SPIRAL_PLATFORM_LENGTH: float = 12.0
const CHECKPOINT_PLATFORM_WIDTH: float = 11.0
const CHECKPOINT_PLATFORM_LENGTH: float = 12.0
const EXIT_TANGENT_DISTANCE: float = 18.0
const EXIT_OUTWARD_DISTANCE: float = 6.0

var _world: Node3D

func _ready() -> void:
	_world = get_parent().get_node_or_null("LogspireWorld") as Node3D
	if _world == null:
		push_error("LOGSPIRE TITAN CP5 CORRIDOR missing LogspireWorld")
		return
	_repair_spiral_platform_footprints()
	_reflow_finale_exit_around_trunk()
	_refresh_affected_geometry()
	_update_course_length()
	print("LOGSPIRE TITAN CP5 CORRIDOR READY spiral_size=%.1fx%.1f checkpoint_size=%.1fx%.1f finale_tangent=%.1fm outward=%.1fm trunk_crossing=false" % [
		SPIRAL_PLATFORM_WIDTH,
		SPIRAL_PLATFORM_LENGTH,
		CHECKPOINT_PLATFORM_WIDTH,
		CHECKPOINT_PLATFORM_LENGTH,
		EXIT_TANGENT_DISTANCE,
		EXIT_OUTWARD_DISTANCE,
	])

func _repair_spiral_platform_footprints() -> void:
	var sizes_value: Variant = _world.get("_platform_sizes")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if not (sizes_value is Array) or not (index_value is Dictionary):
		push_error("LOGSPIRE TITAN CP5 CORRIDOR platform size data unavailable")
		return
	var sizes: Array = sizes_value
	var index_by_id: Dictionary = index_value
	for platform_id: StringName in SPIRAL_IDS:
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= sizes.size():
			continue
		var old_value: Variant = sizes[index]
		if not (old_value is Vector3):
			continue
		var old_size: Vector3 = old_value
		var width: float = CHECKPOINT_PLATFORM_WIDTH if platform_id == &"Z5_SPIRAL_06" else SPIRAL_PLATFORM_WIDTH
		var length: float = CHECKPOINT_PLATFORM_LENGTH if platform_id == &"Z5_SPIRAL_06" else SPIRAL_PLATFORM_LENGTH
		sizes[index] = Vector3(width, old_size.y, length)

func _reflow_finale_exit_around_trunk() -> void:
	var positions_value: Variant = _world.get("_platform_positions")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if not (positions_value is Array) or not (index_value is Dictionary):
		push_error("LOGSPIRE TITAN CP5 CORRIDOR platform position data unavailable")
		return
	var positions: Array = positions_value
	var index_by_id: Dictionary = index_value
	var center := Vector3.ZERO
	var count: int = 0
	for platform_id: StringName in SPIRAL_IDS:
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or not (positions[index] is Vector3):
			continue
		var p: Vector3 = positions[index]
		center += Vector3(p.x, 0.0, p.z)
		count += 1
	if count <= 0:
		return
	center /= float(count)

	var p9: Vector3 = _platform_position_from_arrays(&"Z5_SPIRAL_09", positions, index_by_id)
	var p10: Vector3 = _platform_position_from_arrays(&"Z5_SPIRAL_10", positions, index_by_id)
	var old_start: Vector3 = _platform_position_from_arrays(&"Z6_START", positions, index_by_id)
	if p9 == Vector3.ZERO or p10 == Vector3.ZERO or old_start == Vector3.ZERO:
		return

	var tangent := Vector3(p10.x - p9.x, 0.0, p10.z - p9.z)
	if tangent.length_squared() <= 0.001:
		tangent = Vector3.FORWARD
	else:
		tangent = tangent.normalized()
	var radial := Vector3(p10.x - center.x, 0.0, p10.z - center.z)
	if radial.length_squared() <= 0.001:
		radial = Vector3(-tangent.z, 0.0, tangent.x)
	else:
		radial = radial.normalized()

	var desired_start := p10 + tangent * EXIT_TANGENT_DISTANCE + radial * EXIT_OUTWARD_DISTANCE
	desired_start.y = old_start.y
	var shift := Vector3(desired_start.x - old_start.x, 0.0, desired_start.z - old_start.z)
	for platform_id: StringName in FINALE_IDS:
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or not (positions[index] is Vector3):
			continue
		positions[index] = (positions[index] as Vector3) + shift

	print("LOGSPIRE TITAN EXIT REFLOW shift=(%.2f,%.2f) old_trunkward_start=(%.2f,%.2f) new_start=(%.2f,%.2f)" % [
		shift.x, shift.z, old_start.x, old_start.z, desired_start.x, desired_start.z,
	])

func _refresh_affected_geometry() -> void:
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if not (positions_value is Array) or not (sizes_value is Array) or not (index_value is Dictionary):
		return
	var positions: Array = positions_value
	var sizes: Array = sizes_value
	var index_by_id: Dictionary = index_value
	var affected: Array[StringName] = []
	affected.append_array(SPIRAL_IDS)
	affected.append_array(FINALE_IDS)

	for platform_id: StringName in affected:
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or index >= sizes.size():
			continue
		if not (positions[index] is Vector3) or not (sizes[index] is Vector3):
			continue
		var top: Vector3 = positions[index]
		var size: Vector3 = sizes[index]
		var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
		if root == null:
			continue
		root.global_position = top - Vector3.UP * (size.y * 0.5)

		if platform_id != &"CROWN_NEST":
			var mesh_node := root.get_node_or_null("Mesh") as MeshInstance3D
			var mesh := mesh_node.mesh as BoxMesh if mesh_node != null else null
			if mesh != null:
				mesh.size = size
			var body := root.get_node_or_null("Collision") as StaticBody3D
			if body != null and body.get_child_count() > 0:
				var collision := body.get_child(0) as CollisionShape3D
				var shape := collision.shape as BoxShape3D if collision != null else null
				if shape != null:
					shape.size = size

	_refresh_route_rotations(positions, index_by_id)

func _refresh_route_rotations(positions: Array, index_by_id: Dictionary) -> void:
	var route_value: Variant = _world.call("get_route_ids", &"safe")
	if not (route_value is Array):
		return
	var route: Array = route_value
	for i: int in range(route.size() - 1):
		var platform_id := StringName(route[i])
		if not SPIRAL_IDS.has(platform_id) and not FINALE_IDS.has(platform_id):
			continue
		var next_id := StringName(route[i + 1])
		var a: Vector3 = _platform_position_from_arrays(platform_id, positions, index_by_id)
		var b: Vector3 = _platform_position_from_arrays(next_id, positions, index_by_id)
		var forward := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if forward.length_squared() <= 0.001:
			continue
		forward = forward.normalized()
		var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
		if root != null:
			root.rotation.y = atan2(-forward.x, -forward.z)

func _update_course_length() -> void:
	var route_value: Variant = _world.call("get_route_ids", &"safe")
	if not (route_value is Array):
		return
	var route: Array = route_value
	var total: float = 0.0
	for i: int in range(1, route.size()):
		var a: Vector3 = _world.call("get_platform_position", StringName(route[i - 1]))
		var b: Vector3 = _world.call("get_platform_position", StringName(route[i]))
		total += a.distance_to(b)
	_world.set("_course_length", total)

func _platform_position_from_arrays(platform_id: StringName, positions: Array, index_by_id: Dictionary) -> Vector3:
	var index: int = int(index_by_id.get(platform_id, -1))
	if index < 0 or index >= positions.size() or not (positions[index] is Vector3):
		return Vector3.ZERO
	return positions[index] as Vector3
