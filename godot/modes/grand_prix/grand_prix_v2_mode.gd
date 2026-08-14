extends "res://modes/grand_prix/grand_prix_rc5_mode.gd"

## V2/V3 adapter for systems that used legacy 29-point magic indices.
## V3.0 adds a direct-scene round-context bootstrap so F6 tests use the same
## round index/audio lifecycle as a normal campaign run instead of finishing
## with current_round_index == -1 and accidentally loading Round 1 again.

const V2_ITEM_STATION_PROGRESS: Array[float] = [
	0.07, 0.15, 0.24, 0.33, 0.42, 0.51, 0.60, 0.69, 0.78, 0.87, 0.94,
]
const V2_WIDE_ITEM_STATIONS: Array[int] = [2, 5, 8]
const V2_HUD_REFRESH_INTERVAL: float = 0.10
const V2_RUNTIME_STAMP: String = "V3.0 FLOW+AUDIO STABLE 2026-08-14"
const LEGACY_PURGE_FRAMES: Array[int] = [1, 3, 8, 16]
const GRAND_PRIX_THEME_ID: String = "race_grand_prix"
const GRAND_PRIX_THEME_PATH: String = "res://audio/music/wild_dash_race_theme.ogg"

var _v2_hud_elapsed: float = 0.0
var _runtime_stamp_label: Label
var _v30_direct_bootstrap := false
var _v30_session_id := 0
var _v30_begin_count := 0
var _v30_completion_count := 0

func _ready() -> void:
	_bootstrap_round_context_if_needed()
	_v30_session_id = Time.get_ticks_msec()
	_v30_begin_count += 1
	await super._ready()
	_log_round_flow_start()
	_log_round_audio_state()
	if DisplayServer.get_name() == "headless":
		return
	_install_runtime_stamp()
	print("WILD DASH RUNTIME STAMP %s project=%s scene=%s" % [
		V2_RUNTIME_STAMP,
		ProjectSettings.globalize_path("res://"),
		get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "<none>",
	])
	call_deferred("_purge_legacy_art_over_frames")

func finish_mode(success: bool, score: int, details: Dictionary = {}) -> void:
	if mode_finished:
		print("ROUND FLOW DUPLICATE COMPLETE IGNORED session=%d round_id=grand_prix completion_count=%d" % [
			_v30_session_id,
			_v30_completion_count,
		])
		return
	_v30_completion_count += 1
	var next_index: int = GameManager.current_round_index + 1
	var next_round: StringName = &"result"
	if next_index >= 0 and next_index < GameManager.ROUND_IDS.size():
		next_round = GameManager.ROUND_IDS[next_index]
	print("ROUND FLOW COMPLETE session=%d round_id=grand_prix player_rank=%d next_round=%s completion_count=%d" % [
		_v30_session_id,
		score,
		String(next_round),
		_v30_completion_count,
	])
	super.finish_mode(success, score, details)

func _bootstrap_round_context_if_needed() -> void:
	if GameManager.current_round_index >= 0:
		return
	var resolved_index: int = GameManager.ROUND_IDS.find(&"grand_prix")
	if resolved_index < 0:
		push_error("ROUND FLOW ERROR grand_prix is missing from GameManager.ROUND_IDS")
		return
	ResultManager.reset_campaign()
	GameManager.current_round_index = resolved_index
	GameManager.campaign_running = true
	_v30_direct_bootstrap = true
	print("ROUND FLOW DIRECT BOOTSTRAP round_index=%d round_id=grand_prix reason=F6_or_direct_scene" % [resolved_index + 1])

func _log_round_flow_start() -> void:
	var scene_path := "<none>"
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	print("ROUND FLOW START session=%d round_index=%d round_id=grand_prix scene=%s begin_count=%d direct_bootstrap=%s" % [
		_v30_session_id,
		GameManager.current_round_index + 1,
		scene_path,
		_v30_begin_count,
		str(_v30_direct_bootstrap),
	])
	if _v30_begin_count != 1:
		push_error("ROUND FLOW ERROR duplicate_begin session=%d begin_count=%d" % [_v30_session_id, _v30_begin_count])

func _log_round_audio_state() -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	var music_player: AudioStreamPlayer = null
	if audio != null:
		music_player = audio.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	var loaded: bool = ResourceLoader.exists(GRAND_PRIX_THEME_PATH)
	var ready: bool = audio != null and music_player != null
	var current_theme := "<none>"
	if audio != null:
		current_theme = String(audio.get("_current_theme"))
	var playing: bool = music_player != null and music_player.playing
	print("ROUND AUDIO REQUEST session=%d round=grand_prix track=%s loaded=%s audio_manager_ready=%s" % [
		_v30_session_id,
		GRAND_PRIX_THEME_PATH,
		str(loaded),
		str(ready),
	])
	print("ROUND AUDIO PLAY round=grand_prix theme=%s first_scene_load=%s playing=%s" % [
		current_theme,
		str(_v30_direct_bootstrap),
		str(playing),
	])
	if ready and (current_theme != GRAND_PRIX_THEME_ID or not playing):
		push_warning("ROUND AUDIO VERIFY expected=%s actual=%s playing=%s" % [GRAND_PRIX_THEME_ID, current_theme, str(playing)])

func _process(delta: float) -> void:
	# HUD is intentionally capped at 10 Hz. RaceManager progress/rank reads are
	# cached, while racer physics and checkpoint/finish safety remain 60 Hz.
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

func _install_runtime_stamp() -> void:
	_runtime_stamp_label = Label.new()
	_runtime_stamp_label.name = "V30RuntimeStamp"
	_runtime_stamp_label.position = Vector2(24.0, 286.0)
	_runtime_stamp_label.z_index = 1000
	_runtime_stamp_label.add_theme_font_size_override("font_size", 22)
	_runtime_stamp_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12, 1.0))
	_runtime_stamp_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 1.0))
	_runtime_stamp_label.add_theme_constant_override("shadow_offset_x", 2)
	_runtime_stamp_label.add_theme_constant_override("shadow_offset_y", 2)
	_runtime_stamp_label.text = "LATEST V3.0 ACTIVE | FLOW+BGM | RAILS OFF"
	add_child(_runtime_stamp_label)

func _purge_legacy_art_over_frames() -> void:
	var frame_index: int = 0
	for target_frame: int in LEGACY_PURGE_FRAMES:
		while frame_index < target_frame:
			await get_tree().process_frame
			frame_index += 1
		var removed: int = _purge_legacy_production_art(self)
		if removed > 0:
			print("V3.0 LEGACY ART PURGE frame=%d removed_roots=%d" % [target_frame, removed])
	var survivors: Array[String] = []
	_collect_legacy_visual_survivors(self, survivors)
	print("V3.0 LEGACY ART VERIFY survivors=%d names=%s" % [survivors.size(), ",".join(survivors)])
	if not survivors.is_empty():
		push_error("V3.0 legacy Grand Prix rail/pylon visuals survived purge")

func _purge_legacy_production_art(root: Node) -> int:
	if root == null:
		return 0
	var removed: int = 0
	for child: Node in root.get_children():
		var child_name: String = String(child.name)
		if child_name == "ProductionArtDressing" or child_name.begins_with("ProductionArt_grand_prix"):
			child.queue_free()
			removed += 1
			continue
		removed += _purge_legacy_production_art(child)
	return removed

func _collect_legacy_visual_survivors(root: Node, output: Array[String]) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		var child_name: String = String(child.name)
		if (
			child_name.begins_with("GuardrailUpper_")
			or child_name.begins_with("GuardrailLower_")
			or child_name.begins_with("GuardrailPost_")
			or child_name.begins_with("RouteBeacon_")
			or child_name.begins_with("HeroLandmark_")
		):
			if output.size() < 24:
				output.append(String(child.get_path()))
		_collect_legacy_visual_survivors(child, output)

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
