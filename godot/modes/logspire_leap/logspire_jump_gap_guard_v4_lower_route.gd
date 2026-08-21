extends "res://modes/logspire_leap/logspire_jump_gap_guard.gd"

## Round 3 Titan Tree lower-route finalizer.
##
## The old V2/V3 upper-flow bridge stack is intentionally not inherited here.
## Base Phase-A safety remains active for Zones 1-4 and the Finale, then this
## layer re-authors only CP4 -> CP5 using a low, open, readable route. The two
## authored jumps retain real gaps; every other transition is broad and forgiving.

const LOWER_SAFE_IDS: Array[StringName] = [
	&"Z5_ROOT_RUN_01",
	&"Z5_ROOT_RUN_02",
	&"Z5_BROKEN_TRUNK_TAKEOFF",
	&"Z5_BROKEN_TRUNK_LANDING",
	&"Z5_FORK_SAFE_01",
	&"Z5_FORK_SAFE_02",
	&"Z5_CANOPY_01",
	&"Z5_CANOPY_02",
	&"Z5_CANOPY_03",
	&"Z5_CANOPY_04",
	&"Z5_FINAL_TAKEOFF",
	&"Z5_FINAL_LANDING",
]

const LOWER_FAST_IDS: Array[StringName] = [
	&"Z5_FORK_FAST_01",
	&"Z5_FORK_FAST_02",
	&"Z5_FORK_FAST_03",
]

const FINALE_IDS: Array[StringName] = [
	&"Z6_START",
	&"Z6_01", &"Z6_02", &"Z6_03", &"Z6_04", &"Z6_05", &"Z6_06", &"Z6_07",
	&"CROWN_NEST",
]

const ROOT_RUN_WIDTH: float = 14.0
const BROKEN_TRUNK_GAP: float = 4.6
const BROKEN_TRUNK_LANDING_WIDTH: float = 13.0
const CANOPY_MIN_WIDTH: float = 12.5
const FINAL_ROOT_GAP: float = 5.0
const FINAL_LANDING_WIDTH: float = 16.0
const MIN_VERTICAL_CLEARANCE_TARGET: float = 8.0

func _apply_phase_a_safe_route() -> void:
	super()
	_author_final_lower_route()
	_retire_legacy_upper_helpers()

func _author_final_lower_route() -> void:
	if _world == null:
		return
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	if not (positions_value is Array) or not (sizes_value is Array):
		push_error("LOGSPIRE LOWER ROUTE FINALIZER missing world arrays")
		return
	var positions: Array = positions_value
	var sizes: Array = sizes_value
	var merge_index: int = int(_index_by_id.get(&"Z4_MERGE", -1))
	if merge_index < 0 or merge_index >= positions.size():
		push_error("LOGSPIRE LOWER ROUTE FINALIZER missing CP4 merge")
		return
	var merge: Vector3 = positions[merge_index]

	var layout: Array[Dictionary] = [
		{"id": &"Z5_ROOT_RUN_01", "offset": Vector3(0.0, 0.8, -18.0), "size": Vector3(14.0, 0.8, 18.0)},
		{"id": &"Z5_ROOT_RUN_02", "offset": Vector3(2.0, 1.6, -34.0), "size": Vector3(14.0, 0.8, 18.0)},
		{"id": &"Z5_BROKEN_TRUNK_TAKEOFF", "offset": Vector3(4.0, 2.4, -48.0), "size": Vector3(13.0, 0.8, 14.0)},
		{"id": &"Z5_BROKEN_TRUNK_LANDING", "offset": Vector3(4.0, 3.2, -66.6), "size": Vector3(13.0, 0.8, 14.0)},
		{"id": &"Z5_FORK_SAFE_01", "offset": Vector3(-7.0, 4.0, -78.0), "size": Vector3(14.0, 0.8, 16.0)},
		{"id": &"Z5_FORK_SAFE_02", "offset": Vector3(-16.0, 4.8, -89.0), "size": Vector3(14.0, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_01", "offset": Vector3(-26.0, 5.6, -98.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_02", "offset": Vector3(-34.0, 6.4, -106.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_03", "offset": Vector3(-28.0, 7.2, -118.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_04", "offset": Vector3(-18.0, 8.0, -128.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_FINAL_TAKEOFF", "offset": Vector3(-9.0, 8.8, -138.0), "size": Vector3(14.0, 0.8, 14.0)},
		{"id": &"Z5_FINAL_LANDING", "offset": Vector3(-3.0, 9.6, -157.0), "size": Vector3(16.0, 0.8, 14.0)},
	]
	for entry: Dictionary in layout:
		_set_final_layout(positions, sizes, StringName(entry["id"]), merge + Vector3(entry["offset"]), Vector3(entry["size"]))

	_fit_fast_fork(positions, sizes)
	_shift_finale_and_recovery_after_cp5(positions, sizes)
	_world.set("_platform_positions", positions)
	_world.set("_platform_sizes", sizes)
	_sync_final_geometry(positions, sizes)
	_update_course_length()
	_world.set_meta(&"titan_lower_route_finalized", true)
	_world.set_meta(&"legacy_upper_collision", false)
	_world.set_meta(&"cp4_cp5_water_reset_authority", false)
	print("LOGSPIRE TITAN LOWER ROUTE READY cp4_to_cp5=true root_run_width=%.1f broken_gap=%.1f canopy_min_width=%.1f final_gap=%.1f final_landing_width=%.1f vertical_clearance_target=%.1f upper_spiral_playable=false legacy_upper_bridges=false jump_power_unchanged=true teleport=false checkpoint_skip=false" % [
		ROOT_RUN_WIDTH,
		BROKEN_TRUNK_GAP,
		CANOPY_MIN_WIDTH,
		FINAL_ROOT_GAP,
		FINAL_LANDING_WIDTH,
		MIN_VERTICAL_CLEARANCE_TARGET,
	])

func _set_final_layout(positions: Array, sizes: Array, platform_id: StringName, top: Vector3, size: Vector3) -> void:
	var index: int = int(_index_by_id.get(platform_id, -1))
	if index < 0 or index >= positions.size() or index >= sizes.size():
		push_warning("LOGSPIRE LOWER ROUTE missing platform=%s" % String(platform_id))
		return
	positions[index] = top
	sizes[index] = size

func _fit_fast_fork(positions: Array, sizes: Array) -> void:
	var start_index: int = int(_index_by_id.get(&"Z5_BROKEN_TRUNK_LANDING", -1))
	var merge_index: int = int(_index_by_id.get(&"Z5_CANOPY_03", -1))
	if start_index < 0 or merge_index < 0 or start_index >= positions.size() or merge_index >= positions.size():
		return
	var start: Vector3 = positions[start_index]
	var target: Vector3 = positions[merge_index]
	var fast_positions: Array[Vector3] = [
		start.lerp(target, 0.28) + Vector3(8.0, 0.10, 0.0),
		start.lerp(target, 0.56) + Vector3(10.0, 0.15, 0.0),
		start.lerp(target, 0.82) + Vector3(6.0, 0.08, 0.0),
	]
	for i: int in range(LOWER_FAST_IDS.size()):
		_set_final_layout(positions, sizes, LOWER_FAST_IDS[i], fast_positions[i], Vector3(10.5, 0.8, 13.5))

func _shift_finale_and_recovery_after_cp5(positions: Array, sizes: Array) -> void:
	var landing_index: int = int(_index_by_id.get(&"Z5_FINAL_LANDING", -1))
	var z6_index: int = int(_index_by_id.get(&"Z6_START", -1))
	if landing_index < 0 or z6_index < 0 or landing_index >= positions.size() or z6_index >= positions.size():
		return
	var landing: Vector3 = positions[landing_index]
	var desired_z6 := landing + Vector3(1.0, 0.8, -18.0)
	var shift: Vector3 = desired_z6 - Vector3(positions[z6_index])
	if shift.length_squared() <= 0.000001:
		return
	for platform_id: StringName in FINALE_IDS:
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index >= 0 and index < positions.size():
			positions[index] = Vector3(positions[index]) + shift
	_shift_node_if_present("Recovery_Z6_Deck", shift)
	_shift_node_if_present("Recovery_Z6", shift)
	print("LOGSPIRE TITAN LOWER WATER SEPARATION z6_shift=(%.1f,%.1f,%.1f) cp5_route_pre_z6=true future_water_moved_with_finale=true" % [
		shift.x, shift.y, shift.z,
	])

func _shift_node_if_present(node_name: String, shift: Vector3) -> void:
	var node := _world.get_node_or_null(node_name) as Node3D
	if node != null:
		node.position += shift

func _sync_final_geometry(positions: Array, sizes: Array) -> void:
	for platform_id: StringName in LOWER_SAFE_IDS:
		_update_single_platform_geometry(platform_id, positions, sizes, ROUTE_SAFE)
	for platform_id: StringName in LOWER_FAST_IDS:
		_update_single_platform_geometry(platform_id, positions, sizes, ROUTE_WILD)
	for platform_id: StringName in FINALE_IDS:
		_update_single_platform_geometry(platform_id, positions, sizes, ROUTE_SAFE)

func _retire_legacy_upper_helpers() -> void:
	if _world == null:
		return
	var retired: int = 0
	for child: Node in _world.get_children():
		var node_name: String = String(child.name)
		if node_name == "CP5UpperLandingShelf" or node_name.begins_with("SafeFlowBridge_Z5_SPIRAL"):
			child.queue_free()
			retired += 1
	print("LOGSPIRE TITAN LEGACY UPPER RETIRED helpers=%d upper_spiral_collision=false upper_landing_shelf=false temporary_bridge_stack=false" % retired)
