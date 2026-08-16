extends "res://modes/grand_prix/grand_prix_v2_mode.gd"

## Round 1 Item Distribution V3.2.
##
## P0 PICKUP SAFETY:
## - ItemBox owns the normal body/swept/proximity pickup path.
## - Round 1 also owns an independent player watchdog so a visible yellow box
##   can never become non-interactive because of Area3D, roster, or signal state.
## - On contact the watchdog first asks the box to force pickup. If that fails,
##   Round 1 grants the item directly, then consumes the box.
##
## IMPORTANT PARSER SAFETY:
## - Do not redeclare ITEM_BOX_LANE_OFFSETS / ITEM_BOX_WIDE_LANE_OFFSETS because
##   those constants already exist in grand_prix_mode.gd, an ancestor class.
## - Avoid Dictionary -> Variant -> Vector3 casts in the station sampler.

const ITEM_STATION_PROGRESS: Array[float] = [
	0.10, 0.19, 0.29, 0.39, 0.49, 0.59, 0.69, 0.79, 0.87, 0.94, 0.985,
]
const WIDE_STATION_PROGRESS: Array[float] = [0.49, 0.79, 0.94]
const DISTANCE_ITEM_BOX_LANE_OFFSETS: Array[float] = [-3.2, 0.0, 3.2]
const DISTANCE_ITEM_BOX_WIDE_LANE_OFFSETS: Array[float] = [-4.2, -1.4, 1.4, 4.2]
const MIN_EXPECTED_PROGRESS_GAP: float = 0.075
const MAX_ALLOWED_PROGRESS_GAP: float = 0.14
const PLAYER_ITEM_WATCHDOG_RADIUS: float = 3.60
const PLAYER_ITEM_WATCHDOG_VERTICAL: float = 4.20

var _pickup_watchdog_previous := Vector3.ZERO
var _pickup_watchdog_has_previous := false
var _pickup_watchdog_logged_ready := false

func _process(delta: float) -> void:
	super._process(delta)
	_round1_player_item_watchdog()

func _round1_player_item_watchdog() -> void:
	if player == null or not is_instance_valid(player) or player.finished:
		_pickup_watchdog_has_previous = false
		return
	if _item_boxes.is_empty():
		return

	if not _pickup_watchdog_logged_ready:
		_pickup_watchdog_logged_ready = true
		print("ROUND1 YELLOW PICKUP WATCHDOG READY radius=%.2f vertical=%.2f boxes=%d independent_of_area=true" % [
			PLAYER_ITEM_WATCHDOG_RADIUS,
			PLAYER_ITEM_WATCHDOG_VERTICAL,
			_item_boxes.size(),
		])

	var probe: Vector3 = player.global_position + Vector3.UP * 0.8
	var previous: Vector3 = _pickup_watchdog_previous if _pickup_watchdog_has_previous else probe
	_pickup_watchdog_previous = probe
	_pickup_watchdog_has_previous = true

	for box: WildDashItemBox in _item_boxes:
		if box == null or not is_instance_valid(box) or not box.is_active():
			continue
		var current_hit := _watchdog_proximity_hit(box.global_position, probe)
		var swept_hit := _watchdog_swept_hit(box.global_position, previous, probe)
		if not current_hit and not swept_hit:
			continue
		if _force_round1_item_pickup(box, current_hit, swept_hit):
			break

func _force_round1_item_pickup(box: WildDashItemBox, proximity_hit: bool, swept_hit: bool) -> bool:
	if box == null or player == null or not box.is_active():
		return false

	# First use the shared ItemBox path. It contains the normal weighted grant,
	# replacement policy, telemetry, audio and respawn behavior.
	if box.force_pickup(player):
		print("ROUND1 ITEM WATCHDOG SUCCESS box=%s item=%s path=box_force proximity=%s swept=%s" % [
			box.name,
			ItemSystem.get_display_name(player.get_held_item()),
			str(proximity_hit),
			str(swept_hit),
		])
		return true

	# Absolute P0 fallback. This deliberately bypasses ItemBox cooldown/roster
	# gates because a player visibly crossing a yellow box must receive something.
	var previous_item: StringName = player.get_held_item()
	var replaced := previous_item != &""
	if replaced:
		player.set_held_item(&"")

	var granted := ItemSystem.grant_weighted_item(player)
	var grant_path := "weighted_direct"
	if not granted:
		granted = ItemSystem.grant_item(player, ItemSystem.DASH_BERRY)
		grant_path = "dash_fallback"
	if not granted:
		# Last-resort inventory assignment. DASH_BERRY is a canonical base item;
		# this path exists only so a broken grant callback cannot make the box dead.
		player.set_held_item(ItemSystem.DASH_BERRY)
		granted = player.get_held_item() == ItemSystem.DASH_BERRY
		grant_path = "direct_inventory_fallback"

	if not granted:
		if replaced:
			player.set_held_item(previous_item)
		push_error("ROUND1 ITEM WATCHDOG FAILED box=%s all_grant_paths_failed=true" % box.name)
		return false

	if box.has_method("_success"):
		box.call("_success", player, replaced, "round1_mode_watchdog")
	if box.has_method("_deactivate"):
		box.call("_deactivate")
	else:
		box.visible = false
		box.set_process(false)
		box.set_physics_process(false)

	print("ROUND1 ITEM WATCHDOG SUCCESS box=%s item=%s path=%s proximity=%s swept=%s disappear=true" % [
		box.name,
		ItemSystem.get_display_name(player.get_held_item()),
		grant_path,
		str(proximity_hit),
		str(swept_hit),
	])
	return true

func _watchdog_proximity_hit(point: Vector3, probe: Vector3) -> bool:
	if absf(point.y - probe.y) > PLAYER_ITEM_WATCHDOG_VERTICAL:
		return false
	return Vector2(point.x, point.z).distance_to(Vector2(probe.x, probe.z)) <= PLAYER_ITEM_WATCHDOG_RADIUS

func _watchdog_swept_hit(point: Vector3, a: Vector3, b: Vector3) -> bool:
	var p := Vector2(point.x, point.z)
	var av := Vector2(a.x, a.z)
	var bv := Vector2(b.x, b.z)
	var segment := bv - av
	var length_sq := segment.length_squared()
	var t := clampf((p - av).dot(segment) / length_sq, 0.0, 1.0) if length_sq > 0.0001 else 1.0
	var closest := av.lerp(bv, t)
	var sampled_y := lerpf(a.y, b.y, t)
	return p.distance_to(closest) <= PLAYER_ITEM_WATCHDOG_RADIUS and absf(point.y - sampled_y) <= PLAYER_ITEM_WATCHDOG_VERTICAL

func _spawn_item_boxes() -> void:
	var respawn: float = 4.6
	if RaceManager.racers.size() >= 18:
		respawn = 3.7
	elif RaceManager.racers.size() >= 15:
		respawn = 4.1

	if _route_points.size() < 3:
		push_warning("ITEM DISTRIBUTION V3.2 route unavailable")
		return

	var cumulative: PackedFloat32Array = _build_route_cumulative_distance()
	if cumulative.is_empty():
		return
	var total_distance: float = float(cumulative[cumulative.size() - 1])
	if total_distance <= 0.01:
		return

	for station_progress: float in ITEM_STATION_PROGRESS:
		var target_distance: float = clampf(station_progress, 0.0, 1.0) * total_distance
		var segment_index: int = _segment_index_for_distance(target_distance, cumulative)
		if segment_index < 0 or segment_index + 1 >= _route_points.size():
			continue

		var start_distance: float = float(cumulative[segment_index])
		var end_distance: float = float(cumulative[segment_index + 1])
		var segment_distance: float = maxf(0.001, end_distance - start_distance)
		var local_t: float = clampf((target_distance - start_distance) / segment_distance, 0.0, 1.0)
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var point: Vector3 = a.lerp(b, local_t)
		var tangent: Vector3 = b - a
		tangent.y = 0.0
		if tangent.length_squared() <= 0.001:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)

		var lane_offsets: Array[float] = DISTANCE_ITEM_BOX_LANE_OFFSETS
		if _is_wide_station(station_progress):
			lane_offsets = DISTANCE_ITEM_BOX_WIDE_LANE_OFFSETS

		for lane_offset: float in lane_offsets:
			var box: WildDashItemBox = ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "DistanceItemBox_P%03d_L%s" % [
				roundi(station_progress * 1000.0),
				str(lane_offset).replace("-", "N").replace(".", "_"),
			]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)

	var max_gap: float = get_max_item_station_gap()
	var first_twenty: int = 0
	var middle_stations: int = 0
	for progress: float in ITEM_STATION_PROGRESS:
		if progress <= 0.20:
			first_twenty += 1
		if progress >= 0.20 and progress <= 0.90:
			middle_stations += 1
	print("ITEM DISTRIBUTION V3.2 stations=%d boxes=%d progresses=%s max_gap=%.3f first_20_percent=%d middle_stations=%d wide=%d respawn=%.1fs distance_sampled=true pickup_watchdog=true" % [
		ITEM_STATION_PROGRESS.size(), _item_boxes.size(), str(ITEM_STATION_PROGRESS), max_gap,
		first_twenty, middle_stations, WIDE_STATION_PROGRESS.size(), respawn,
	])
	if max_gap > MAX_ALLOWED_PROGRESS_GAP:
		push_warning("ITEM DISTRIBUTION V3.2 gap too large: %.3f" % max_gap)
	for i: int in range(1, ITEM_STATION_PROGRESS.size()):
		var gap: float = ITEM_STATION_PROGRESS[i] - ITEM_STATION_PROGRESS[i - 1]
		if gap < MIN_EXPECTED_PROGRESS_GAP:
			push_warning("ITEM DISTRIBUTION V3.2 stations too close at %d gap=%.3f" % [i, gap])

func get_item_station_progresses() -> Array[float]:
	var result: Array[float] = []
	for progress: float in ITEM_STATION_PROGRESS:
		result.append(progress)
	return result

func get_max_item_station_gap() -> float:
	var max_gap: float = 0.0
	for i: int in range(1, ITEM_STATION_PROGRESS.size()):
		max_gap = maxf(max_gap, ITEM_STATION_PROGRESS[i] - ITEM_STATION_PROGRESS[i - 1])
	return max_gap

func _build_route_cumulative_distance() -> PackedFloat32Array:
	var cumulative: PackedFloat32Array = PackedFloat32Array()
	if _route_points.is_empty():
		return cumulative
	cumulative.append(0.0)
	var running: float = 0.0
	for i: int in range(1, _route_points.size()):
		running += _route_points[i - 1].distance_to(_route_points[i])
		cumulative.append(running)
	return cumulative

func _segment_index_for_distance(target_distance: float, cumulative: PackedFloat32Array) -> int:
	if _route_points.size() < 2 or cumulative.size() != _route_points.size():
		return -1
	for i: int in range(1, cumulative.size()):
		if float(cumulative[i]) >= target_distance:
			return i - 1
	return _route_points.size() - 2

func _is_wide_station(progress: float) -> bool:
	for wide_progress: float in WIDE_STATION_PROGRESS:
		if absf(wide_progress - progress) <= 0.001:
			return true
	return false
