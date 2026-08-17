extends "res://modes/logspire_leap/logspire_ladder_system_v4_safe_exit.gd"

## Traversable recovery-route audit after real player testing.
## Root stairs are rebuilt as shallow visual steps over one continuous collision
## slope, so they remain readable but cannot trap a racer on individual risers.
## High ladder decks are moved farther away from large overhead geometry and
## exit at the deck centre before reconnecting to the race route.

const ROOT_PATH_POINT_COUNT: int = 5
const STAIR_MAX_RISE: float = 0.48
const STAIR_WIDTH: float = 5.6
const STAIR_MIN_STEP_LENGTH: float = 2.0
const STAIR_SLOPE_THICKNESS: float = 0.36
const MID_DECK_OUTWARD_SHIFT: float = 1.4
const HIGH_DECK_OUTWARD_SHIFT: float = 3.8
const MID_CLEAR_DECK_SIZE := Vector3(9.0, 0.45, 9.0)
const HIGH_CLEAR_DECK_SIZE := Vector3(12.0, 0.45, 12.0)
const EXIT_FORWARD_CLEARANCE_METERS: float = 5.0
const EXIT_HEAD_CLEARANCE_METERS: float = 3.2

var _rebuilt_stair_count: int = 0
var _repositioned_exit_count: int = 0

func configure(world: Node, graph: Node, water_heights: Dictionary) -> void:
	super(world, graph, water_heights)
	_reposition_recovery_decks_for_clearance()
	_rebuild_root_stairs_as_traversable_routes()
	print("LOGSPIRE RECOVERY PATH AUDIT READY stairs=%d exits_repositioned=%d max_step_rise=%.2fm stair_width=%.1fm forward_clearance=%.1fm head_clearance=%.1fm" % [
		_rebuilt_stair_count,
		_repositioned_exit_count,
		STAIR_MAX_RISE,
		STAIR_WIDTH,
		EXIT_FORWARD_CLEARANCE_METERS,
		EXIT_HEAD_CLEARANCE_METERS,
	])

func _reposition_recovery_decks_for_clearance() -> void:
	for i: int in range(_ladders.size()):
		var ladder: Dictionary = _ladders[i]
		var zone: int = int(ladder.get("zone", 0))
		if zone < 2:
			continue
		var platform_id := StringName(ladder.get("platform_id", &""))
		var platform_value: Variant = _graph.call("get_platform_position", platform_id)
		var deck_value: Variant = ladder.get("deck_center", Vector3.ZERO)
		var bottom_value: Variant = ladder.get("bottom", Vector3.ZERO)
		if not (platform_value is Vector3) or not (deck_value is Vector3) or not (bottom_value is Vector3):
			continue
		var platform_position: Vector3 = platform_value
		var deck_center: Vector3 = deck_value
		var bottom: Vector3 = bottom_value
		var outward := deck_center - platform_position
		outward.y = 0.0
		if outward.length_squared() <= 0.001:
			var forward_value: Variant = _graph.call("get_platform_forward", platform_id, &"safe")
			var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
			forward.y = 0.0
			if forward.length_squared() <= 0.001:
				forward = Vector3.FORWARD
			else:
				forward = forward.normalized()
			outward = Vector3(-forward.z, 0.0, forward.x)
		else:
			outward = outward.normalized()
		var shift: float = HIGH_DECK_OUTWARD_SHIFT if zone >= 4 else MID_DECK_OUTWARD_SHIFT
		var deck_size: Vector3 = HIGH_CLEAR_DECK_SIZE if zone >= 4 else MID_CLEAR_DECK_SIZE
		var new_deck_center := deck_center + outward * shift
		var new_bottom := bottom + outward * shift
		var safe_exit := Vector3(new_deck_center.x, platform_position.y + 1.15, new_deck_center.z)
		_reposition_ladder_nodes(ladder, new_bottom, safe_exit, new_deck_center, platform_position, deck_size)
		ladder["bottom"] = new_bottom
		ladder["exit"] = safe_exit
		ladder["safe_exit"] = safe_exit
		ladder["deck_center"] = Vector3(new_deck_center.x, platform_position.y, new_deck_center.z)
		ladder["forward_clearance_m"] = EXIT_FORWARD_CLEARANCE_METERS
		ladder["head_clearance_m"] = EXIT_HEAD_CLEARANCE_METERS
		_ladders[i] = ladder
		_repositioned_exit_count += 1
		print("LOGSPIRE RECOVERY EXIT AUDIT ladder=%s zone=%d platform=%s deck=%.1fm outward_shift=%.1fm safe_exit=center forward_clear=%.1fm head_clear=%.1fm" % [
			String(ladder.get("id", &"")),
			zone + 1,
			String(platform_id),
			deck_size.x,
			shift,
			EXIT_FORWARD_CLEARANCE_METERS,
			EXIT_HEAD_CLEARANCE_METERS,
		])

func _rebuild_root_stairs_as_traversable_routes() -> void:
	for i: int in range(_root_ramps.size()):
		var ramp: Dictionary = _root_ramps[i]
		var entry_value: Variant = ramp.get("entry", Vector3.ZERO)
		var exit_value: Variant = ramp.get("exit", Vector3.ZERO)
		if not (entry_value is Vector3) or not (exit_value is Vector3):
			continue
		var entry: Vector3 = entry_value
		var exit_position: Vector3 = exit_value
		var platform_id := StringName(ramp.get("platform_id", &""))
		_hide_old_root_steps(platform_id)
		_build_shallow_stair_visual(platform_id, entry, exit_position)
		_build_continuous_stair_slope(platform_id, entry, exit_position)
		var points: Array[Vector3] = []
		for point_index: int in range(ROOT_PATH_POINT_COUNT):
			var t: float = float(point_index) / float(ROOT_PATH_POINT_COUNT - 1)
			var point := entry.lerp(exit_position, t)
			if point_index > 0 and point_index < ROOT_PATH_POINT_COUNT - 1:
				point.y += 0.18
			points.append(point)
		ramp["path_points"] = points
		ramp["path_point_count"] = ROOT_PATH_POINT_COUNT
		ramp["recovery_type"] = &"stair"
		ramp["stair"] = true
		ramp["max_step_rise"] = STAIR_MAX_RISE
		ramp["stair_width"] = STAIR_WIDTH
		_root_ramps[i] = ramp
		_rebuilt_stair_count += 1
		print("LOGSPIRE STAIR GEOMETRY platform=%s max_rise=%.2f width=%.1f continuous_collision=true path_points=%d" % [
			String(platform_id), STAIR_MAX_RISE, STAIR_WIDTH, ROOT_PATH_POINT_COUNT,
		])

func _hide_old_root_steps(platform_id: StringName) -> void:
	var prefix: String = "RootRamp_%s_" % String(platform_id)
	for child: Node in get_children():
		if not String(child.name).begins_with(prefix):
			continue
		if child is Node3D:
			(child as Node3D).visible = false
		_disable_collision_recursive(child)

func _disable_collision_recursive(node: Node) -> void:
	if node is StaticBody3D:
		var body := node as StaticBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child: Node in node.get_children():
		_disable_collision_recursive(child)

func _build_shallow_stair_visual(platform_id: StringName, entry: Vector3, exit_position: Vector3) -> void:
	var start_top := entry - Vector3.UP * 0.65
	var end_top := exit_position - Vector3.UP * 0.82
	var delta := end_top - start_top
	var horizontal := Vector3(delta.x, 0.0, delta.z)
	var horizontal_length: float = maxf(1.0, horizontal.length())
	var vertical_height: float = maxf(0.0, end_top.y - start_top.y)
	var step_count: int = clampi(maxi(4, int(ceil(vertical_height / STAIR_MAX_RISE))), 4, 28)
	var direction := horizontal.normalized() if horizontal.length_squared() > 0.001 else Vector3.FORWARD
	for step_index: int in range(step_count):
		var t: float = (float(step_index) + 0.5) / float(step_count)
		var top := start_top.lerp(end_top, t)
		var step_length: float = maxf(STAIR_MIN_STEP_LENGTH, horizontal_length / float(step_count) + 0.95)
		var step_root := _create_static_box(
			"RecoveryStair_%s_%02d" % [String(platform_id), step_index + 1],
			top,
			Vector3(STAIR_WIDTH, 0.28, step_length),
			_wood_material
		)
		step_root.rotation.y = atan2(-direction.x, -direction.z)
		_disable_collision_recursive(step_root)

func _build_continuous_stair_slope(platform_id: StringName, entry: Vector3, exit_position: Vector3) -> void:
	var start_surface := entry - Vector3.UP * 0.65
	var end_surface := exit_position - Vector3.UP * 0.82
	var route := end_surface - start_surface
	var route_length: float = route.length()
	if route_length <= 0.5:
		return
	var slope_root := Node3D.new()
	slope_root.name = "RecoveryStairSlope_%s" % String(platform_id)
	add_child(slope_root)
	slope_root.global_position = start_surface.lerp(end_surface, 0.5) - Vector3.UP * 0.14
	slope_root.look_at(end_surface, Vector3.UP)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(STAIR_WIDTH, STAIR_SLOPE_THICKNESS, route_length + 1.2)
	box_mesh.material = _wood_material
	mesh.mesh = box_mesh
	slope_root.add_child(mesh)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("logspire_recovery_stair")
	slope_root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(STAIR_WIDTH, STAIR_SLOPE_THICKNESS, route_length + 1.2)
	collision.shape = shape
	body.add_child(collision)
