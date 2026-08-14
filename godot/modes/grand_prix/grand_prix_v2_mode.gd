extends "res://modes/grand_prix/grand_prix_rc5_mode.gd"

## V2 adapter for systems that used legacy 29-point magic indices.
## Stage 1 deliberately sends every AI through the full shared Adventure route;
## terrain-aware branch choice is added in later Terrain Adventure stages.

const V2_ITEM_STATION_PROGRESS: Array[float] = [
	0.07, 0.15, 0.24, 0.33, 0.42, 0.51, 0.60, 0.69, 0.78, 0.87, 0.94,
]
const V2_WIDE_ITEM_STATIONS: Array[int] = [2, 5, 8]
const V2_HUD_REFRESH_INTERVAL: float = 0.10

var _v2_hud_elapsed: float = 0.0

func _process(delta: float) -> void:
	# The inherited HUD path projected every rival onto all ~288 route segments
	# every rendered frame through RaceManager.get_rank()/get_track_progress().
	# V2 only needs human-readable HUD updates, so cap that expensive projection
	# path at 10 Hz while racer physics/gameplay continue at their normal rate.
	if player == null:
		return
	_v2_hud_elapsed += delta
	if _v2_hud_elapsed < V2_HUD_REFRESH_INTERVAL:
		return
	_v2_hud_elapsed = 0.0

	var fps: int = Engine.get_frames_per_second()
	if fps > 0:
		_fps_sum += float(fps)
		_fps_samples += 1
	var rank: int = RaceManager.get_rank(player)
	var checkpoint_progress: int = RaceManager.get_checkpoint_progress(player)
	var checkpoint_total: int = RaceManager.get_checkpoint_count()
	var progress_percent: float = RaceManager.get_progress_percent(player)
	hud.set_metrics("Rank %d / %d   CP %d/%d   Progress %d%%   Speed %.1f   FPS %d" % [
		rank, RaceManager.racers.size(), checkpoint_progress, checkpoint_total,
		roundi(progress_percent), player.current_speed, fps,
	])
	hud.set_item_state(ItemSystem.get_display_name(player.get_held_item()), ItemSystem.get_status_text(player))

func _build_shortcut_route(_skip_route_index: int) -> Array[Vector3]:
	# Legacy personality code still asks for A/B shortcut routes. Until the V2
	# terrain branch scorer exists, return the authoritative full route so every
	# racer reaches River -> Mountain -> Summit -> Descent -> Finish reliably.
	return _build_race_route_with_runout()

func _spawn_item_boxes() -> void:
	var respawn := 5.0
	if RaceManager.racers.size() >= 18:
		respawn = 3.6
	elif RaceManager.racers.size() >= 15:
		respawn = 4.0

	for station_index in range(V2_ITEM_STATION_PROGRESS.size()):
		if _route_points.size() < 3:
			break
		var progress := V2_ITEM_STATION_PROGRESS[station_index]
		var route_index := clampi(roundi(progress * float(_route_points.size() - 2)), 1, _route_points.size() - 2)
		var point := _route_points[route_index]
		var tangent := _route_points[route_index + 1] - _route_points[route_index - 1]
		tangent.y = 0.0
		tangent = Vector3.FORWARD if tangent.length_squared() <= 0.001 else tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)

		var road_width := 16.0
		if _track != null and _track.has_method("get_v2_width_for_segment"):
			road_width = float(_track.call("get_v2_width_for_segment", route_index))
		var wide := V2_WIDE_ITEM_STATIONS.has(station_index) and road_width >= 16.0 and RaceManager.racers.size() >= 15
		var lane_offsets: Array[float] = [-3.0, 0.0, 3.0]
		if wide:
			lane_offsets = [-4.2, -1.4, 1.4, 4.2]
		else:
			var side_offset := minf(3.0, maxf(2.1, road_width * 0.27))
			lane_offsets = [-side_offset, 0.0, side_offset]

		for lane_offset: float in lane_offsets:
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "ItemBox_V2_S%02d_L%s" % [
				station_index + 1,
				str(lane_offset).replace("-", "N").replace(".", "_"),
			]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)

	print("GRAND PRIX V2 ITEM BOXES PASS count=%d stations=%d respawn=%.1fs progress_based=true hud_rank_projection_hz=%.0f" % [
		_item_boxes.size(), V2_ITEM_STATION_PROGRESS.size(), respawn, 1.0 / V2_HUD_REFRESH_INTERVAL,
	])
