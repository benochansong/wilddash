extends "res://modes/logspire_leap/logspire_platform_gameplay.gd"

## Round 3 Sky Log Finale geometry adapter.
##
## Phase2 keeps the same scripted lateral swing timing for Z6_03/Z6_05/Z6_07,
## but the playable bodies are flat box boards instead of cylindrical logs.
## Earlier round/zone moving-log gameplay remains owned by the base script.

const FINALE_SWING_BOARD_SIZE := Vector3(9.2, 0.60, 10.8)
const FINALE_SWING_BOARD_CONTACT_SIZE := Vector3(9.4, 2.8, 11.0)
const FINALE_SWING_IDS: Array[StringName] = [&"Z6_03", &"Z6_05", &"Z6_07"]

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_replace_finale_swing_log_with_flat_board(&"Z6_03", 2.8, 4.6)
	_replace_finale_swing_log_with_flat_board(&"Z6_05", -3.2, 4.2)
	_replace_finale_swing_log_with_flat_board(&"Z6_07", 3.6, 3.9)
	print("r3_finale_phase2_cylinders_removed platforms=Z6_03,Z6_05,Z6_07 replacement=flat_box swing_timing_preserved=true")

func _replace_finale_swing_log_with_flat_board(platform_id: StringName, amplitude: float, period: float) -> void:
	if not FINALE_SWING_IDS.has(platform_id):
		return

	var previous: Dictionary = _runtime.get(platform_id, {})
	var old_body := previous.get("body") as AnimatableBody3D
	var old_area := previous.get("area") as Area3D
	if old_area != null and is_instance_valid(old_area):
		old_area.monitoring = false
		old_area.collision_mask = 0
	if old_body != null and is_instance_valid(old_body):
		old_body.name = "RetiredCylinder_%s" % String(platform_id)
		old_body.collision_layer = 0
		old_body.collision_mask = 0
		old_body.visible = false
		old_body.process_mode = Node.PROCESS_MODE_DISABLED
		old_body.queue_free()

	var forward: Vector3 = _platform_forward(platform_id, ROUTE_SAFE)
	var body := _make_box_body(
		platform_id,
		FINALE_SWING_BOARD_SIZE,
		forward,
		Color(0.50, 0.31, 0.105)
	)
	if body == null:
		return
	body.name = "FinaleFlatSwingBoard_%s" % String(platform_id)
	var area := _make_box_contact_area(body, FINALE_SWING_BOARD_CONTACT_SIZE)
	var base_position: Vector3 = body.global_position
	_runtime[platform_id] = {
		"kind": &"swing",
		"body": body,
		"area": area,
		"top_offset": FINALE_SWING_BOARD_SIZE.y * 0.5,
		"right": _right_from_forward(forward),
		"base_position": base_position,
		"previous_position": base_position,
		"velocity": Vector3.ZERO,
		"amplitude": amplitude,
		"period": maxf(2.5, period),
		"phase": float(platform_id.hash() % 100) * 0.021,
		"previous_riders": {},
	}
	print("r3_finale_phase2_board_replaced platform=%s cylinder=false shape=box amplitude=%.1f period=%.1f" % [
		String(platform_id), amplitude, period,
	])
