extends "res://modes/logspire_leap/logspire_world_v2_deep_water.gd"

## Round 3 Titan Tree lower / mid route source data.
##
## The former Z5 upper spiral is retired before production geometry is built.
## Its authored slots are renamed and re-authored as a low, open route, so no
## Z5_SPIRAL_* platform node exists in the production world at runtime.
## Phase 2 flattens the CP4 -> CP5 climb so the five QA bodies can clear every
## authored jump with their default jump_velocity / gravity values.

const LEGACY_TO_LOWER_ID: Dictionary = {
	&"Z5_APPROACH_01": &"Z5_ROOT_RUN_01",
	&"Z5_APPROACH_02": &"Z5_ROOT_RUN_02",
	&"Z5_SPIRAL_01": &"Z5_BROKEN_TRUNK_TAKEOFF",
	&"Z5_SPIRAL_02": &"Z5_BROKEN_TRUNK_LANDING",
	&"Z5_SPIRAL_03": &"Z5_FORK_SAFE_01",
	&"Z5_SPIRAL_04": &"Z5_FORK_SAFE_02",
	&"Z5_SPIRAL_05": &"Z5_CANOPY_01",
	&"Z5_SPIRAL_06": &"Z5_CANOPY_02",
	&"Z5_SPIRAL_07": &"Z5_CANOPY_03",
	&"Z5_SPIRAL_08": &"Z5_CANOPY_04",
	&"Z5_SPIRAL_09": &"Z5_FINAL_TAKEOFF",
	&"Z5_SPIRAL_10": &"Z5_FINAL_LANDING",
}

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

var _seed_z6_shift: Vector3 = Vector3.ZERO

func _build_course_data() -> void:
	super()
	_rename_legacy_upper_route()
	_apply_lower_route_seed_layout()
	_register_lower_fast_fork()
	_rebuild_wild_suffix_for_fast_fork()
	_retarget_cp5_to_final_landing()
	_seed_finale_after_lower_route()
	_mark_lower_route_contract()

func _rename_legacy_upper_route() -> void:
	for old_value: Variant in LEGACY_TO_LOWER_ID.keys():
		var old_id := StringName(old_value)
		var new_id := StringName(LEGACY_TO_LOWER_ID[old_value])
		_rename_platform_id(old_id, new_id)

func _rename_platform_id(old_id: StringName, new_id: StringName) -> void:
	var index: int = int(_platform_index_by_id.get(old_id, -1))
	if index < 0 or index >= _platform_ids.size():
		push_warning("LOGSPIRE LOWER ROUTE missing legacy platform=%s" % String(old_id))
		return
	_platform_ids[index] = new_id
	_platform_index_by_id.erase(old_id)
	_platform_index_by_id[new_id] = index
	_replace_route_name(_main_route_ids, old_id, new_id)
	_replace_route_name(_wild_route_ids, old_id, new_id)
	_replace_route_name(_checkpoint_ids, old_id, new_id)
	for i: int in range(_platform_recovery_targets.size()):
		if _platform_recovery_targets[i] == old_id:
			_platform_recovery_targets[i] = new_id

func _replace_route_name(route: Array[StringName], old_id: StringName, new_id: StringName) -> void:
	for i: int in range(route.size()):
		if route[i] == old_id:
			route[i] = new_id

func _apply_lower_route_seed_layout() -> void:
	var merge: Vector3 = get_platform_position(_merge_platform_id)
	var layout: Array[Dictionary] = [
		{"id": &"Z5_ROOT_RUN_01", "offset": Vector3(0.0, 0.30, -18.0), "size": Vector3(14.0, 0.8, 18.0)},
		{"id": &"Z5_ROOT_RUN_02", "offset": Vector3(2.0, 0.50, -34.0), "size": Vector3(14.0, 0.8, 18.0)},
		{"id": &"Z5_BROKEN_TRUNK_TAKEOFF", "offset": Vector3(4.0, 0.70, -48.0), "size": Vector3(13.0, 0.8, 14.0)},
		{"id": &"Z5_BROKEN_TRUNK_LANDING", "offset": Vector3(4.0, 0.90, -65.8), "size": Vector3(13.0, 0.8, 14.0)},
		{"id": &"Z5_FORK_SAFE_01", "offset": Vector3(-10.0, 1.10, -78.0), "size": Vector3(14.0, 0.8, 16.0)},
		{"id": &"Z5_FORK_SAFE_02", "offset": Vector3(-18.0, 1.30, -90.0), "size": Vector3(14.0, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_01", "offset": Vector3(-16.0, 1.50, -102.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_02", "offset": Vector3(-20.0, 1.70, -114.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_03", "offset": Vector3(-18.0, 1.90, -126.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_CANOPY_04", "offset": Vector3(-12.0, 2.10, -138.0), "size": Vector3(12.5, 0.8, 16.0)},
		{"id": &"Z5_FINAL_TAKEOFF", "offset": Vector3(-5.0, 2.30, -148.0), "size": Vector3(14.0, 0.8, 14.0)},
		{"id": &"Z5_FINAL_LANDING", "offset": Vector3(0.0, 2.50, -165.0), "size": Vector3(16.0, 0.8, 14.0)},
	]
	for entry: Dictionary in layout:
		_set_platform_layout(StringName(entry["id"]), merge + Vector3(entry["offset"]), Vector3(entry["size"]))

func _set_platform_layout(platform_id: StringName, top: Vector3, size: Vector3) -> void:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	if index < 0 or index >= _platform_positions.size() or index >= _platform_sizes.size():
		return
	_platform_positions[index] = top
	_platform_sizes[index] = size

func _register_lower_fast_fork() -> void:
	var start: Vector3 = get_platform_position(&"Z5_BROKEN_TRUNK_LANDING")
	var canopy: Vector3 = get_platform_position(&"Z5_CANOPY_01")
	var cp4: StringName = _checkpoint_ids[3] if _checkpoint_ids.size() > 3 else _merge_platform_id
	var fast_positions: Array[Vector3] = [
		Vector3(1.0, start.y + 0.20, start.z - 9.2),
		Vector3(-3.0, start.y + 0.40, start.z - 18.2),
		Vector3(-10.0, start.y + 0.60, start.z - 27.2),
	]
	for i: int in range(LOWER_FAST_IDS.size()):
		_register_platform(
			LOWER_FAST_IDS[i],
			fast_positions[i],
			Vector3(10.5, 0.8, 10.0),
			4,
			ROUTE_WILD,
			0.48 + float(i) * 0.06,
			true,
			cp4
		)
	set_meta(&"titan_fast_fork_merge", canopy)

func _rebuild_wild_suffix_for_fast_fork() -> void:
	var merge_index: int = _wild_route_ids.find(_merge_platform_id)
	if merge_index < 0:
		return
	var rebuilt: Array[StringName] = []
	for i: int in range(merge_index + 1):
		rebuilt.append(_wild_route_ids[i])
	for platform_id: StringName in [
		&"Z5_ROOT_RUN_01",
		&"Z5_ROOT_RUN_02",
		&"Z5_BROKEN_TRUNK_TAKEOFF",
		&"Z5_BROKEN_TRUNK_LANDING",
	]:
		rebuilt.append(platform_id)
	for platform_id: StringName in LOWER_FAST_IDS:
		rebuilt.append(platform_id)
	for platform_id: StringName in [
		&"Z5_CANOPY_01",
		&"Z5_CANOPY_02",
		&"Z5_CANOPY_03",
		&"Z5_CANOPY_04",
		&"Z5_FINAL_TAKEOFF",
		&"Z5_FINAL_LANDING",
		&"Z6_START",
		&"Z6_01", &"Z6_02", &"Z6_03", &"Z6_04", &"Z6_05", &"Z6_06", &"Z6_07",
		&"CROWN_NEST",
	]:
		rebuilt.append(platform_id)
	_wild_route_ids = rebuilt

func _retarget_cp5_to_final_landing() -> void:
	if _checkpoint_ids.size() > 4:
		_checkpoint_ids[4] = &"Z5_FINAL_LANDING"
	var z6_index: int = int(_platform_index_by_id.get(&"Z6_START", -1))
	if z6_index >= 0 and z6_index < _platform_recovery_targets.size():
		_platform_recovery_targets[z6_index] = &"Z5_FINAL_LANDING"

func _seed_finale_after_lower_route() -> void:
	var current_z6: Vector3 = get_platform_position(&"Z6_START")
	var final_landing: Vector3 = get_platform_position(&"Z5_FINAL_LANDING")
	var desired_z6 := final_landing + Vector3(1.0, 0.8, -18.0)
	_seed_z6_shift = desired_z6 - current_z6
	for platform_id: StringName in FINALE_IDS:
		var index: int = int(_platform_index_by_id.get(platform_id, -1))
		if index >= 0 and index < _platform_positions.size():
			_platform_positions[index] += _seed_z6_shift

func _build_recovery_decks() -> void:
	super()
	_shift_runtime_recovery_pair("Recovery_Z6", _seed_z6_shift)

func _shift_runtime_recovery_pair(area_name: String, delta: Vector3) -> void:
	if delta.length_squared() <= 0.000001:
		return
	var deck := get_node_or_null(area_name + "_Deck") as Node3D
	var area := get_node_or_null(area_name) as Node3D
	if deck != null:
		deck.position += delta
	if area != null:
		area.position += delta

func _mark_lower_route_contract() -> void:
	set_meta(&"titan_upper_spiral_playable", false)
	set_meta(&"titan_lower_route_phase1", true)
	set_meta(&"titan_lower_route_phase2_geometry", true)
	set_meta(&"titan_cp5_platform", &"Z5_FINAL_LANDING")
	print("LOGSPIRE TITAN LOWER ROUTE DATA READY legacy_upper_spiral=false safe_nodes=%d fast_nodes=%d cp5=Z5_FINAL_LANDING future_z6_shifted=true baseline_jump_geometry=true" % [
		LOWER_SAFE_IDS.size(), LOWER_FAST_IDS.size(),
	])
