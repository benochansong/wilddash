extends "res://modes/grand_prix/grand_prix_v2_mode.gd"

## Round 1 Item Distribution V3.
##
## The previous V5 pass used raw route-point indices. Grand Prix route points are
## not evenly spaced in world distance, so that accidentally packed several yellow
## boxes into the opening while leaving long mid-race droughts. V3 samples the
## authoritative route by cumulative distance instead. Long Bomb / Item Chaos live
## in the item controller and are intentionally untouched by this station pass.

const ITEM_STATION_PROGRESS: Array[float] = [
	0.10, 0.19, 0.29, 0.39, 0.49, 0.59, 0.69, 0.79, 0.87, 0.94, 0.985,
]
const WIDE_STATION_PROGRESS: Array[float] = [0.49, 0.79, 0.94]
const ITEM_BOX_LANE_OFFSETS: Array[float] = [-3.2, 0.0, 3.2]
const ITEM_BOX_WIDE_LANE_OFFSETS: Array[float] = [-4.2, -1.4, 1.4, 4.2]
const MIN_EXPECTED_PROGRESS_GAP: float = 0.075
const MAX_ALLOWED_PROGRESS_GAP: float = 0.14

func _spawn_item_boxes() -> void:
	var respawn: float = 4.6
	if RaceManager.racers.size() >= 18:
		respawn = 3.7
	elif RaceManager.racers.size() >= 15:
		respawn = 4.1

	if _route_points.size() < 3:
		push_warning("ITEM DISTRIBUTION V3 route unavailable")
		return

	var cumulative: PackedFloat32Array = _build_route_cumulative_distance()
	if cumulative.is_empty():
		return
	var total_distance: float = float(cumulative[cumulative.size() - 1])
	if total_distance <= 0.01:
		return

	for station_progress: float in ITEM_STATION_PROGRESS:
		var pose: Dictionary = _sample_route_by_distance_progress(station_progress, cumulative, total_distance)
		if pose.is_empty():
			continue
		var point_value: Variant = pose.get("position", Vector3.ZERO)
		var tangent_value: Variant = pose.get("tangent", Vector3.FORWARD)
		var point: Vector3 = point_value as Vector3
		var tangent: Vector3 = tangent_value as Vector3
		var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var lane_offsets: Array[float]
		if _is_wide_station(station_progress):
			lane_offsets = ITEM_BOX_WIDE_LANE_OFFSETS
		else:
			lane_offsets = ITEM_BOX_LANE_OFFSETS
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
	print("ITEM DISTRIBUTION V3 stations=%d boxes=%d progresses=%s max_gap=%.3f first_20_percent=%d middle_stations=%d wide=%d respawn=%.1fs distance_sampled=true long_bomb_preserved=true" % [
		ITEM_STATION_PROGRESS.size(), _item_boxes.size(), str(ITEM_STATION_PROGRESS), max_gap,
		first_twenty, middle_stations, WIDE_STATION_PROGRESS.size(), respawn,
	])
	if max_gap > MAX_ALLOWED_PROGRESS_GAP:
		push_warning("ITEM DISTRIBUTION V3 gap too large: %.3f" % max_gap)
	for i: int in range(1, ITEM_STATION_PROGRESS.size()):
		var gap: float = ITEM_STATION_PROGRESS[i] - ITEM_STATION_PROGRESS[i - 1]
		if gap < MIN_EXPECTED_PROGRESS_GAP:
			push_warning("ITEM DISTRIBUTION V3 stations too close at %d gap=%.3f" % [i, gap])

func get_item_station_progresses() -> Array[float]:
	return ITEM_STATION_PROGRESS.duplicate()

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

func _sample_route_by_distance_progress(
	progress: float,
	cumulative: PackedFloat32Array,
	total_distance: float
) -> Dictionary:
	if _route_points.size() < 2 or cumulative.size() != _route_points.size():
		return {}
	var target_distance: float = clampf(progress, 0.0, 1.0) * total_distance
	var segment_index: int = _route_points.size() - 2
	var found_segment: bool = false
	for i: int in range(1, cumulative.size()):
		if float(cumulative[i]) >= target_distance:
			segment_index = i - 1
			found_segment = true
			break
	if not found_segment:
		segment_index = _route_points.size() - 2
	var start_distance: float = float(cumulative[segment_index])
	var end_distance: float = float(cumulative[segment_index + 1])
	var segment_distance: float = maxf(0.001, end_distance - start_distance)
	var t: float = clampf((target_distance - start_distance) / segment_distance, 0.0, 1.0)
	var a: Vector3 = _route_points[segment_index]
	var b: Vector3 = _route_points[segment_index + 1]
	var tangent: Vector3 = b - a
	tangent.y = 0.0
	if tangent.length_squared() <= 0.001:
		tangent = Vector3.FORWARD
	else:
		tangent = tangent.normalized()
	return {
		"position": a.lerp(b, t),
		"tangent": tangent,
		"segment_index": segment_index,
	}

func _is_wide_station(progress: float) -> bool:
	for wide_progress: float in WIDE_STATION_PROGRESS:
		if absf(wide_progress - progress) <= 0.001:
			return true
	return false
